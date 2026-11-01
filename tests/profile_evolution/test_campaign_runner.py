"""Current-run fake CLI producers exercise approved campaign execution/recovery."""
from __future__ import annotations

import contextlib
from concurrent.futures import ThreadPoolExecutor
import copy
import io
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from tests.profile_evolution.test_campaign_confirmation import _frozen_campaign
from tests.profile_evolution.test_confirmation import _provenance, _result
from tools.profile_evolution.artifacts import canonical_json_bytes
from tools.profile_evolution.campaign_runner import _execute_validated_manifest, run_manifest
from tools.profile_evolution.campaign_schedule import build_round_manifest
from tools.profile_evolution.campaign_confirmation import build_confirmation_manifests
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.fitness import _planned_tournaments, _roster_provenance, _simulation_manifest_checksum, _validate_manifest


FAKE_ENGINE = r'''
import fcntl,hashlib,json,os,sys,time
from pathlib import Path
spec_path=Path(__file__).with_suffix('.json')
spec=json.loads(spec_path.read_text())
a=sys.argv[1:]
def value(flag): return a[a.index(flag)+1]
index,workers=map(int,value('--shard').split('/'))
root=spec_path.parent
with (root/'calls.jsonl').open('a') as out:
 fcntl.flock(out,fcntl.LOCK_EX);out.write(json.dumps({'index':index,'argv':a})+'\n')
with (root/'events.jsonl').open('a') as out:
 fcntl.flock(out,fcntl.LOCK_EX);out.write(json.dumps({'event':'start','index':index,'time':time.monotonic()})+'\n')
manifest=json.loads(Path(value('--config')).read_text())
report=json.loads((root/'template.json').read_text())
checkpoint=Path(value('--checkpoint'));checkpoint.mkdir(exist_ok=True)
identity={'manifest_checksum':report['manifest_checksum'],'execution_provenance':report['execution_provenance'],
          'shard':{'index':index,'count':workers},'trace':{'mode':0,'max_entries_per_tournament':0}}
if spec['mode']=='wrong_header_pause':identity['execution_provenance']['engine_version']='wrong-header-engine'
header={'checkpoint_schema_version':1,'identity':identity,
        'identity_checksum':hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest(),
        'started_at':'2026-11-01T12:00:00'}
header_path=checkpoint/'header.json'
if '--resume' not in a: header_path.write_text(json.dumps(header))
if '--resume' in a and not header_path.is_file(): raise SystemExit(9)
mode=spec['mode']
assigned=len([t for t in report['tournaments'] if t['tournament_index']%workers==index])
print(f'Completed 1/{assigned} | elapsed 1.00s | throughput 1.00 tournaments/s',file=sys.stderr,flush=True)
if mode=='progress_pause': time.sleep(.2)
if mode in ('pause','wrong_header_pause'): time.sleep(3)
if mode=='fail_once' and index==1 and not (root/'failed_once').exists():
 (root/'failed_once').write_text('yes');time.sleep(.3);raise SystemExit(7)
time.sleep(.01 if index==0 else .05)
if mode=='no_report': raise SystemExit(0)
report['shard']={'index':index,'count':workers}
report['tournaments']=[t for t in report['tournaments'] if t['tournament_index']%workers==index]
if mode=='wrong_shard':report['shard']['index']=index+1
if mode=='missing_index':report['tournaments'].pop()
if mode=='wrong_manifest':report['manifest']['batch_id']='unapproved'
if mode=='wrong_provenance' and index==1:report['execution_provenance']['engine_version']='different-engine'
Path(value('--output')).write_text(json.dumps(report))
Path(value('--log-file')).write_text('fake engine log\n')
with (root/'events.jsonl').open('a') as out:
 fcntl.flock(out,fcntl.LOCK_EX);out.write(json.dumps({'event':'finish','index':index,'time':time.monotonic()})+'\n')
if mode=='fail_after_report':raise SystemExit(7)
'''


def _report(manifest: dict) -> dict:
    provenance = _provenance()
    provenance['algorithm_versions']['rng_streams'] = 'named_stream_sha256_v2'
    tournaments=[]
    for planned in _planned_tournaments(manifest,_validate_manifest(manifest)).values():
        results=[]
        for row in planned['seat_map']:
            result=_result(row['profile_id'],row['seat'],row['seat']+1,9)
            result['starting_stack']=1000
            result['final_stack']=9000 if row['seat']==0 else 0
            result['chip_differential']=result['final_stack']-1000
            results.append(result)
        tournaments.append({**planned,'termination_reason':'winner','winner_profile_id':planned['seat_map'][0]['profile_id'],
                            'tournament_hand_count':1,'profile_results':results,'diagnostics':[]})
    return {'report_schema_version':4,'manifest':copy.deepcopy(manifest),'manifest_checksum':_simulation_manifest_checksum(manifest),
            'roster':_roster_provenance(manifest),'code_revision':provenance['code_revision'],'command_version':'simulation_cli_v6',
            'execution_provenance':provenance,'shard':{'index':0,'count':1},'started_at':'2026-11-01T12:00:00',
            'finished_at':'2026-11-01T12:01:00','tournaments':tournaments,'aggregates':{},'traces':[]}


class CampaignRunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=build_round_manifest(_frozen_campaign())
        # Preserve the actual user-approved 35-table design, with one complete
        # rotation per table for this fake-producer fixture only.
        cls.manifest['evaluation_plans'][0]['tournament_count']=315
        cls.manifest['evaluation_plans'][0]['minimum_profile_samples']=1
        cls.template=_report(cls.manifest)

    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name)
        self.input=self.root/'input.json';self.input.write_bytes(canonical_json_bytes(self.manifest))
        self.engine=self.root/'fake_godot'
        self.engine.write_text('#!'+sys.executable+'\n'+FAKE_ENGINE)
        self.engine.chmod(0o700)
        (self.root/'template.json').write_text(json.dumps(self.template))
        self.spec=self.engine.with_suffix('.json')
        self.mode('success')
        self.output=self.root/'run'
        self.approval={'approved':True,'manifest_checksum':_simulation_manifest_checksum(self.manifest),'source':'user'}
        self.provenance=copy.deepcopy(self.template['execution_provenance'])

    def mode(self,value):self.spec.write_text(json.dumps({'mode':value}))
    def calls(self):
        path=self.root/'calls.jsonl'
        return [json.loads(s) for s in path.read_text().splitlines()] if path.exists() else []
    def execute(self,**kwargs):
        values=dict(manifest_path=self.input,godot=str(self.engine),output_dir=self.output,approval=self.approval,workers=4,expected_provenance=self.provenance)
        values.update(kwargs)
        with contextlib.redirect_stdout(io.StringIO()):return run_manifest(**values)

    def test_approval_and_worker_validation_happen_before_any_launch(self):
        approvals=[None,{},dict(approved=False,manifest_checksum=self.approval['manifest_checksum']),
                   dict(approved=1,manifest_checksum=self.approval['manifest_checksum']),
                   dict(approved=True,manifest_checksum='0'*64),{**self.approval,'source':'automatic'},
                   {**self.approval,'unsupported':True}]
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch:
            for approval in approvals:
                with self.subTest(approval=approval),self.assertRaises(ToolError):self.execute(approval=approval)
            for workers in (0,5,True,1.5):
                with self.subTest(workers=workers),self.assertRaises(ToolError):self.execute(workers=workers)
            launch.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_four_workers_use_existing_cli_flags_and_publish_validated_readiness(self):
        ready=self.execute()
        self.assertEqual(ready['type'],'campaign_run_readiness_v1')
        self.assertEqual(ready['payload']['tournament_count'],315)
        self.assertEqual(len(ready['payload']['reports']),4)
        self.assertTrue((self.output/'readiness.json').is_file())
        run=json.loads((self.output/'run.json').read_text())
        self.assertEqual(run['type'],'campaign_run_v1')
        self.assertEqual(set(run['payload']),{'manifest','manifest_checksum','workers','godot','expected_provenance','approval'})
        self.assertEqual(run['payload']['approval'],self.approval)
        self.assertEqual({c['index'] for c in self.calls()},{0,1,2,3})
        for call in self.calls():
            args=call['argv'];self.assertIn('--checkpoint',args);self.assertNotIn('--resume',args)
            self.assertEqual(args[args.index('--script')+1],'res://scripts/simulation/simulation_cli_app.gd')
            self.assertEqual(args[args.index('--config')+1],str(self.output/'manifest.json'))
            self.assertIn('/localtmp/campaign_runner/',args[args.index('--log-file')+1])
        events=sorted((json.loads(s) for s in (self.root/'events.jsonl').read_text().splitlines()),key=lambda e:e['time'])
        active=peak=0
        for event in events:
            active+=1 if event['event']=='start' else -1;peak=max(peak,active)
        self.assertLessEqual(peak,4)
        self.assertEqual(active,0)
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch:
            self.assertEqual(self.execute(),ready);launch.assert_not_called()

    def test_success_without_report_and_bad_report_identity_fail_closed(self):
        for mode in ('no_report','wrong_shard','wrong_manifest','missing_index'):
            with self.subTest(mode=mode):
                self.mode(mode)
                with self.assertRaises(ToolError):self.execute(output_dir=self.root/mode,workers=1)
                self.assertFalse((self.root/mode/'readiness.json').exists())

    def test_workers_and_expected_pilot_provenance_must_match(self):
        self.mode('wrong_provenance')
        with self.assertRaises(ToolError):self.execute()
        self.assertFalse((self.output/'readiness.json').exists())
        self.mode('success')
        wrong=copy.deepcopy(self.provenance);wrong['engine_version']='unmatched-pilot-engine'
        with self.assertRaises(ToolError):self.execute(output_dir=self.root/'pilot_mismatch',workers=1,expected_provenance=wrong)

    def test_failed_producer_preserves_checkpoints_then_resumes_only_missing_shards(self):
        self.mode('fail_once')
        with self.assertRaises(ToolError):self.execute()
        self.assertFalse((self.output/'readiness.json').exists())
        self.assertTrue((self.output/'shard_0001.checkpoint/header.json').is_file())
        before=len(self.calls())
        ready=self.execute()
        resumed=self.calls()[before:]
        self.assertTrue(resumed)
        self.assertTrue(all('--resume' in c['argv'] for c in resumed))
        self.assertEqual(ready['payload']['tournament_count'],315)
        self.assertTrue((self.output/'readiness.json').is_file())

    def test_new_worker_header_provenance_fails_before_long_tournament_work(self):
        self.mode('wrong_header_pause')
        original=subprocess.Popen;children=[]
        def launch(*args,**kwargs):
            child=original(*args,**kwargs);children.append(child);return child
        started=time.monotonic()
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen',side_effect=launch),self.assertRaises(ToolError) as caught:
            self.execute(workers=1)
        self.assertEqual(caught.exception.code,'campaign_provenance_mismatch')
        self.assertLess(time.monotonic()-started,2.5)
        self.assertTrue(all(child.poll() is not None for child in children))
        self.assertFalse((self.output/'shard_0000.json').exists())
        self.assertFalse((self.output/'readiness.json').exists())

    def test_existing_unowned_directory_and_changed_report_are_not_overwritten(self):
        self.output.mkdir()
        with self.assertRaises(ToolError):self.execute()
        other=self.root/'owned'
        self.execute(output_dir=other,workers=1)
        report=other/'shard_0000.json';original=report.read_text()
        report.write_text(original+'\n')
        with self.assertRaises(ToolError):self.execute(output_dir=other,workers=1)
        self.assertEqual(report.read_text(),original+'\n')

    def test_resume_rejects_changed_manifest_workers_or_provenance_before_launch(self):
        self.execute(workers=1)
        changed=copy.deepcopy(self.manifest);changed['batch_id']='another_approved_manifest'
        changed_path=self.root/'changed.json';changed_path.write_bytes(canonical_json_bytes(changed))
        changed_approval={**self.approval,'manifest_checksum':_simulation_manifest_checksum(changed)}
        different=copy.deepcopy(self.provenance);different['engine_version']='another-engine'
        cases=({'manifest_path':changed_path,'approval':changed_approval,'workers':1},
               {'workers':2},{'workers':1,'expected_provenance':different})
        for values in cases:
            with self.subTest(values=values),patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch,self.assertRaises(ToolError):
                self.execute(**values)
            launch.assert_not_called()

    def test_corrupt_checkpoint_is_rejected_before_resume_launch(self):
        self.mode('fail_once')
        with self.assertRaises(ToolError):self.execute()
        path=self.output/'shard_0001.checkpoint/header.json'
        header=json.loads(path.read_text());header['identity_checksum']='0'*64;path.write_text(json.dumps(header))
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch,self.assertRaises(ToolError):self.execute()
        launch.assert_not_called()

    def test_nonzero_exit_report_cannot_be_reused_as_successful_evidence(self):
        self.mode('fail_after_report')
        with self.assertRaises(ToolError):self.execute(workers=1)
        self.assertTrue((self.output/'shard_0000.json').is_file())
        self.assertFalse((self.output/'shard_0000.completed.json').exists())
        with self.assertRaises(ToolError):self.execute(workers=1)
        self.assertFalse((self.output/'readiness.json').exists())

    def test_interruption_stops_all_workers_and_preserves_owned_checkpoints(self):
        self.mode('pause')
        original=subprocess.Popen;children=[]
        def launch(*args,**kwargs):
            child=original(*args,**kwargs);children.append(child);return child
        # Capture the real sleep before patching the module's shared time object.
        sleep=time.sleep
        interrupted=[]
        def stop_after_headers(delay):
            if not interrupted:
                interrupted.append(True);sleep(.25);raise KeyboardInterrupt()
            sleep(delay)
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen',side_effect=launch),patch('tools.profile_evolution.campaign_runner.time.sleep',side_effect=stop_after_headers):
            with self.assertRaises(ToolError) as caught:self.execute()
        self.assertEqual(caught.exception.code,'campaign_run_interrupted')
        self.assertEqual(len(children),4)
        self.assertTrue(all(child.poll() is not None for child in children))
        self.assertFalse((self.output/'readiness.json').exists())
        self.assertTrue(all((self.output/f'shard_{i:04d}.checkpoint/header.json').is_file() for i in range(4)))
        self.mode('success')
        self.execute()
        self.assertTrue(all('--resume' in c['argv'] for c in self.calls()[-4:]))

    def test_sigterm_stops_workers_and_restores_callers_signal_handler(self):
        self.mode('pause')
        original=subprocess.Popen;children=[]
        def launch(*args,**kwargs):
            child=original(*args,**kwargs);children.append(child);return child
        sleep=time.sleep
        interrupted=[]
        old_handler=signal.getsignal(signal.SIGTERM)
        def terminate_after_headers(delay):
            if not interrupted:
                interrupted.append(True);sleep(.25);os.kill(os.getpid(),signal.SIGTERM)
            sleep(delay)
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen',side_effect=launch),patch('tools.profile_evolution.campaign_runner.time.sleep',side_effect=terminate_after_headers):
            with self.assertRaises(ToolError) as caught:self.execute()
        self.assertEqual(caught.exception.code,'campaign_run_interrupted')
        self.assertTrue(all(child.poll() is not None for child in children))
        self.assertEqual(signal.getsignal(signal.SIGTERM),old_handler)
        self.assertFalse((self.output/'readiness.json').exists())

    def test_running_events_reuse_cli_progress_counts_and_remaining_work(self):
        self.mode('progress_pause')
        output=io.StringIO()
        with patch('tools.profile_evolution.campaign_runner.PROGRESS_INTERVAL_SECONDS',0),contextlib.redirect_stdout(output):
            run_manifest(self.input,str(self.engine),self.output,self.approval,workers=1,expected_provenance=self.provenance)
        events=[json.loads(line) for line in output.getvalue().splitlines()]
        live=[e for e in events if e['event']=='running' and e['completed_tournaments']>0]
        self.assertTrue(live)
        event=live[0]
        self.assertEqual(event['estimated_remaining_seconds'],314.0)
        self.assertEqual(event['worker_progress']['0']['assigned'],315)
        self.assertEqual(event['worker_progress']['0']['completed'],1)
        self.assertIn('throughput 1.00 tournaments/s',event['worker_progress']['0']['latest_progress_line'])

    def test_equal_exposure_schedule_with_missing_opponent_pairs_is_never_launched(self):
        manifest=copy.deepcopy(self.manifest)
        profile_ids=[profile['profile_id'] for profile in manifest['profiles']]
        # Consecutive cyclic windows retain nine appearances per profile and
        # equal seats, while never pairing players more than eight apart.
        for shift,matchup in enumerate(manifest['matchups']):
            matchup['profile_ids']=[profile_ids[(shift+i)%35] for i in range(9)]
        self.input.write_bytes(canonical_json_bytes(manifest))
        approval={'approved':True,'manifest_checksum':_simulation_manifest_checksum(manifest)}
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch,self.assertRaises(ToolError) as caught:
            self.execute(approval=approval)
        self.assertIn('cover every opponent pair',caught.exception.message)
        launch.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_shared_executor_cancels_threaded_jobs_and_resumes_owned_confirmation_outputs(self):
        campaign=_frozen_campaign()
        candidate=campaign['payload']['contenders'][0]['candidate_id']
        manifest=build_confirmation_manifests(campaign,candidate)['a']
        manifest_path=self.root/'confirmation_manifest.json'
        manifest_path.write_bytes(canonical_json_bytes(manifest))
        (self.root/'template.json').write_text(json.dumps(_report(manifest)))
        checksum=_simulation_manifest_checksum(manifest)
        # This unit fixture exercises an already-validated caller boundary;
        # campaign policy authorization itself belongs to the public cohort API.
        authorization={'policy_authorization':{'policy_version':'nine_player_promotion_v1',
                        'scope':'fixture_confirmation','campaign_checksum':campaign['checksum']}}
        audit={'manifest_checksum':checksum,'tournament_count':297,'policy':'fixture_confirmation_audit'}
        cancel=threading.Event()
        outputs=[self.root/'confirmation_job_a',self.root/'confirmation_job_b']
        self.mode('pause')
        original=subprocess.Popen;children=[]
        def launch(*args,**kwargs):
            child=original(*args,**kwargs);children.append(child);return child
        def job(output):
            return _execute_validated_manifest(manifest_path,manifest,str(self.engine),output,
                    authorization,1,self.provenance,audit,run_type='confirmation_job_run_v1',
                    ready_type='confirmation_job_readiness_v1',cancel_event=cancel)
        event_output=io.StringIO()
        with contextlib.redirect_stdout(event_output),patch('tools.profile_evolution.campaign_runner.subprocess.Popen',side_effect=launch):
            with ThreadPoolExecutor(max_workers=2) as executor:
                futures=[executor.submit(job,output) for output in outputs]
                deadline=time.monotonic()+5
                while not all((output/'shard_0000.checkpoint/header.json').is_file() for output in outputs) and time.monotonic()<deadline:
                    time.sleep(.01)
                self.assertTrue(all((output/'shard_0000.checkpoint/header.json').is_file() for output in outputs))
                cancel.set()
                for future in futures:
                    with self.assertRaises(ToolError) as caught:future.result(timeout=5)
                    self.assertEqual(caught.exception.code,'campaign_run_interrupted')
        self.assertEqual(len(children),2)
        events=[json.loads(line) for line in event_output.getvalue().splitlines()]
        self.assertEqual(sum(event['event']=='shard_started' for event in events),2)
        self.assertTrue(all(child.poll() is not None for child in children))
        self.assertTrue(all(not (output/'readiness.json').exists() for output in outputs))
        cancel.clear();self.mode('success')
        with contextlib.redirect_stdout(io.StringIO()):ready=job(outputs[0])
        self.assertEqual(ready['type'],'confirmation_job_readiness_v1')
        self.assertEqual(ready['payload']['workers'],1)
        self.assertEqual(ready['payload']['tournament_count'],297)
        marker=json.loads((outputs[0]/'run.json').read_text())
        self.assertEqual(marker['type'],'confirmation_job_run_v1')
        self.assertEqual(marker['payload']['policy_authorization'],authorization['policy_authorization'])
        self.assertNotIn('approval',marker['payload'])
        self.assertIn('--resume',self.calls()[-1]['argv'])

    def test_pre_cancelled_shared_job_does_not_create_outputs_or_launch(self):
        cancel=threading.Event();cancel.set()
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch,self.assertRaises(ToolError) as caught:
            _execute_validated_manifest(self.input,self.manifest,str(self.engine),self.output,
                {'policy_authorization':{'scope':'fixture_confirmation'}},1,self.provenance,
                {'manifest_checksum':self.approval['manifest_checksum']},
                run_type='confirmation_job_run_v1',ready_type='confirmation_job_readiness_v1',cancel_event=cancel)
        self.assertEqual(caught.exception.code,'campaign_run_interrupted')
        self.assertFalse(self.output.exists());launch.assert_not_called()

    def test_legacy_model_cannot_be_included_in_an_approved_run(self):
        manifest=copy.deepcopy(self.manifest)
        manifest['profiles'][0]['model_id']='random'
        manifest['profiles'][0]['parameters']={'fold_weight':1,'passive_weight':4,'aggressive_weight':2}
        self.input.write_bytes(canonical_json_bytes(manifest))
        approval={'approved':True,'manifest_checksum':_simulation_manifest_checksum(manifest)}
        with patch('tools.profile_evolution.campaign_runner.subprocess.Popen') as launch,self.assertRaises(ToolError):self.execute(approval=approval)
        launch.assert_not_called()


if __name__=='__main__':unittest.main()
