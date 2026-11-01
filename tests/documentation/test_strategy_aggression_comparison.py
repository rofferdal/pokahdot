"""Balanced acceptance rejects corrupt counts and independent policy regressions."""
from __future__ import annotations
import copy
import unittest
import json
from pathlib import Path
import tempfile
from unittest.mock import patch

from tools.compare_strategy_aggression import IMMUTABLE, compare, main, paired_uncertainty, validate_bank, validate_tournaments


def fixtures():
    hashes = {k: 'a' * 64 for k in IMMUTABLE}
    hashes.update({f'res://resources/bot_profiles/p{i}.tres': 'b' * 64 for i in range(15)})
    profiles = [f'p{i}' for i in range(15)] + [f'control_raise_{v}' for v in (0, 50, 100)] + ['control_bluff_0', 'control_bluff_100']
    cases = [('value_resistance/preflop/p2/s1000', 'value_resistance')]
    cases += [(f'{name}/flop/p2/s1000', name) for name in ('delayed_backdoor', 'prior_call_backdoor', 'two_increases_backdoor')]
    cases += [(f'case{i}', 'expensive_value') for i in range(233)]
    rows = []
    for case, scenario in cases:
        for profile in profiles:
            rows.append(dict(case_id=case, scenario=scenario, profile=profile, street='preflop',
                             player_count=2, starting_stack=1000, legal_raise=True, legal_bet=False,
                             valid=True, samples=32, actions={'CALL': 32}, branches={'continue_passive': 32},
                             score=49, call_price=.1, draw_outs=0, draw_quality=0,
                             raise_percentage=0, value_eligible=0, bluff_eligible=0))
    for row in rows:
        if row['scenario'].endswith('backdoor'):
            row['street'] = 'flop'
            row['player_count'] = 2 if row['scenario'] == 'delayed_backdoor' else 3
    bank = dict(schema='bfcr_aggression_bank_v1', policy_version='v2', seed_start=151001,
                runtime_seconds=1, samples=32, cases=237, source_hashes=hashes, rows=rows)
    tournaments = []
    for i in range(180):
        row = dict(decisions=10, actions={'CALL': 9, 'RAISE': 1}, branches={'continue_passive': 9, 'continue_aggressive': 1},
                   legal_raise=10, legal_bet=0, value_eligible=10, bluff_eligible=0, post_aggression=10)
        response = dict(opportunities=10, CALL=9, FOLD=0, RAISE=1, other=0, fold_rate=0., fold_wilson95=[0., .3])
        tournaments.append(dict(seed=201001+i, player_count=2, starting_stack=100,
                               mirrored=False, seat_profiles=[f'p{i%15}', f'p{(i+1)%15}'], winner=0,
                               completed=True, error='', invalid_actions=0, chip_total=200, expected_chip_total=200,
                               decisions=10, hands=1, maximum_raise_chain=1, betting_streets=1, streets_over_12_raises=0,
                               long_chains=0, repeated_weak_bluffs=0, raise_chain_histogram={'1': 1}, street_raise_tails=[1],
                               summaries={'all': copy.deepcopy(row), f'profile:p{i%15}': copy.deepcopy(row),
                                          'street:preflop': copy.deepcopy(row), 'category:value_response': copy.deepcopy(row),
                                          'post_aggression': copy.deepcopy(row)},
                               response_summary={k: copy.deepcopy(response) for k in ('all', 'nonweak', 'cheap_nonweak')}))
    tours = dict(schema='bfcr_aggression_tournaments_v1', policy_version='v2', seed_start=201001,
                 runtime_seconds=1, source_hashes=copy.deepcopy(hashes), tournaments=tournaments)
    candidate_bank, candidate_tours = copy.deepcopy(bank), copy.deepcopy(tours)
    for row in candidate_bank['rows']:
        if row['scenario'] == 'value_resistance' and row['profile'] in ('control_raise_50', 'control_raise_100'):
            count = 8 if row['profile'].endswith('50') else 16
            row.update(actions={'CALL': 32-count, 'RAISE': count}, branches={'continue_passive': 32-count, 'continue_aggressive': count},
                       raise_percentage=count/32*100, value_eligible=32)
        if row['scenario'].endswith('backdoor') and row['profile'] == 'control_bluff_100':
            row.update(actions={'RAISE': 32}, branches={'bluff_raise': 32}, bluff_eligible=32)
    for t in candidate_tours['tournaments']:
        t['raise_chain_histogram'] = {'1': 2}
        for row in t['summaries'].values():
            row['actions'] = {'CALL': 8, 'RAISE': 2}
            row['branches'] = {'continue_passive': 8, 'continue_aggressive': 2}
        for row in t['response_summary'].values():
            row.update(CALL=8, RAISE=2)
    return bank, candidate_bank, tours, candidate_tours


class StrategyAggressionComparisonTests(unittest.TestCase):
    def test_accepts_all_independent_margins(self):
        result = compare(*fixtures(), uncertainty=False)
        self.assertTrue(result['passed'], result['checks'])
        self.assertEqual(result['candidate_rates']['nonweak_raise_share'], .2)

    def test_rejects_bad_numeric_types_and_nonfinite_evidence(self):
        for value in (True, float('nan'), float('inf'), -1):
            with self.subTest(value=value):
                bank, _, _, _ = fixtures()
                bank['rows'][0]['score'] = value
                with self.assertRaises(ValueError):
                    validate_bank(bank)

    def test_rejects_corrupt_denominators_legality_and_identities(self):
        for mutation in ('counts', 'hash', 'seed', 'chip', 'tail', 'hist', 'response', 'profile_partition', 'illegal'):
            with self.subTest(mutation=mutation):
                b, c, bt, ct = fixtures()
                t = ct['tournaments'][0]
                if mutation == 'counts': c['rows'][0]['actions']['CALL'] = 31
                if mutation == 'hash': c['source_hashes'][IMMUTABLE[0]] = 'c'*64
                if mutation == 'seed': t['seed'] += 1
                if mutation == 'chip': t['chip_total'] -= 1
                if mutation == 'tail': t['street_raise_tails'] = [2]
                if mutation == 'hist': t['raise_chain_histogram'] = {'1': 1}
                if mutation == 'response': t['response_summary']['all']['RAISE'] = 10
                if mutation == 'profile_partition': t['summaries']['profile:p0']['decisions'] = 9
                if mutation == 'illegal': c['rows'][20]['legal_raise'] = False; c['rows'][20]['actions'] = {'RAISE': 32}
                with self.assertRaises(ValueError): compare(b, c, bt, ct, uncertainty=False)

    def test_independent_acceptance_failures(self):
        for mutation, check in (('raise', 'nonweak_raise_improvement'), ('runtime', 'runtime'), ('bank_runtime', 'runtime'),
                                ('ak', 'ak_preference_response'), ('bluff', 'bluff_windows'),
                                ('call', 'preserved_continuations')):
            with self.subTest(mutation=mutation):
                b, c, bt, ct = fixtures()
                if mutation == 'raise': ct = copy.deepcopy(bt)
                if mutation == 'runtime': ct['runtime_seconds'] = 2.01
                if mutation == 'bank_runtime': c['runtime_seconds'] = 2.01
                if mutation == 'ak': c['rows'][17].update(actions={'CALL':32}, branches={'continue_passive':32})
                if mutation == 'bluff': c['rows'][39].update(actions={'CALL':32}, branches={'continue_passive':32})
                if mutation == 'call': c['rows'][15].update(actions={'FOLD':32}, branches={'fold':32})
                self.assertFalse(compare(b, c, bt, ct, uncertainty=False)['checks'][check])

    def test_value_stage_rejects_bluff_changes(self):
        b, c, bt, ct = fixtures()
        self.assertFalse(compare(b, c, bt, ct, 'value', uncertainty=False)['checks']['bluff_windows'])

    def test_backdoor_eligibility_is_restricted_to_selected_cohorts(self):
        b, c, bt, ct = fixtures()
        for bank in (b, c):
            for row in bank['rows']:
                if row['scenario'] == 'delayed_backdoor':
                    row['street'] = 'turn'
        result = compare(b, c, bt, ct, uncertainty=False)
        self.assertFalse(result['checks']['negative_bluff_controls'])

    def test_initial_behavior_guard_covers_published_profiles(self):
        b, c, bt, ct = fixtures()
        for bank in (b, c):
            bank['rows'][0]['scenario'] = 'initial_value'
        c['rows'][0].update(actions={'FOLD': 32}, branches={'fold': 32})
        self.assertFalse(compare(b, c, bt, ct, uncertainty=False)['checks']['unchanged_initial_and_strong_controls'])

    def test_supplied_failed_value_ablation_fails_overall_cli(self):
        b, c, bt, ct = fixtures()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            args = ['compare']
            for name, value in (('baseline-bank', b), ('candidate-bank', c),
                                ('baseline-tournaments', bt), ('candidate-tournaments', ct),
                                ('value-only-bank', c), ('value-only-tournaments', ct)):
                path = root / (name + '.json')
                path.write_text(json.dumps(value))
                args.extend(['--' + name, str(path)])
            output = root / 'comparison.json'
            args.extend(['--output', str(output)])
            with patch('sys.argv', args), patch('tools.compare_strategy_aggression.paired_uncertainty', return_value={}):
                self.assertEqual(main(), 1)
            result = json.loads(output.read_text())
            self.assertFalse(result['passed'])
            self.assertFalse(result['value_only_validation']['passed'])

    def test_bootstrap_is_reproducible_and_resamples_whole_pairs(self):
        _, _, bt, ct = fixtures()
        a = paired_uncertainty(bt['tournaments'], ct['tournaments'], 100)
        self.assertEqual(a, paired_uncertainty(bt['tournaments'], ct['tournaments'], 100))
        self.assertAlmostEqual(a['nonweak_raise_share'][0], .1)
        self.assertAlmostEqual(a['nonweak_raise_share'][1], .1)


if __name__ == '__main__':
    unittest.main()
