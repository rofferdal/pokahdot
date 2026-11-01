#!/usr/bin/env python3
"""Compare frozen BFCR banks and whole paired tournament cohorts."""
from __future__ import annotations

import argparse
import hashlib
from collections import Counter
import json
import math
from pathlib import Path
import random
import sys

IMMUTABLE = tuple('res://tests/' + p for p in (
    'support/strategy_aggression_decision_bank.gd',
    'support/strategy_aggression_tournament_benchmark.gd',
    'manual/strategy_aggression_benchmark.gd'))
ACTIONS = {'FOLD', 'CALL', 'RAISE', 'CHECK', 'BET', 'ALL_IN'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value, name, low=0, high=math.inf, integer=False):
    require(type(value) in ((int,) if integer else (int, float))
            and math.isfinite(value) and low <= value <= high, 'Invalid number: ' + name)
    return value


def counts(value, name, allowed=None):
    require(isinstance(value, dict), 'Invalid counts: ' + name)
    for key, count in value.items():
        require(isinstance(key, str) and bool(key) and (allowed is None or key in allowed), name)
        number(count, name, integer=True)
    return sum(value.values())


def metadata(report, schema):
    require(report.get('schema') == schema, 'Unsupported schema')
    number(report.get('seed_start'), 'seed_start', 1, integer=True)
    number(report.get('runtime_seconds'), 'runtime_seconds', 1e-9)
    require(isinstance(report.get('policy_version'), str), 'Missing policy identity')
    hashes = report.get('source_hashes')
    require(isinstance(hashes, dict), 'Missing source hashes')
    for path, digest in hashes.items():
        require(isinstance(path, str) and isinstance(digest, str) and len(digest) == 64
                and all(c in '0123456789abcdef' for c in digest), 'Invalid source hash')


def validate_bank(report):
    metadata(report, 'bfcr_aggression_bank_v1')
    n = number(report.get('samples'), 'samples', 1, 256, integer=True)
    rows = report.get('rows')
    require(isinstance(rows, list) and bool(rows), 'Missing bank rows')
    keys = set()
    cases, profiles = set(), set()
    for row in rows:
        key = (row['case_id'], row['profile'])
        require(key not in keys, 'Duplicate bank row')
        keys.add(key)
        cases.add(key[0])
        profiles.add(key[1])
        require(row.get('valid') is True and row.get('samples') == n, 'Invalid legal bank state')
        for field in ('legal_raise', 'legal_bet'):
            require(type(row.get(field)) is bool, 'Invalid legality flag')
        require(counts(row['actions'], 'actions', ACTIONS) == n
                and counts(row['branches'], 'branches') == n, 'Bank count mismatch')
        require(row['legal_raise'] or not row['actions'].get('RAISE'), 'Illegal bank raise')
        require(row['legal_bet'] or not row['actions'].get('BET'), 'Illegal bank bet')
        for field in ('value_eligible', 'bluff_eligible'):
            number(row.get(field), field, 0, n, integer=True)
        for field, upper in (('score', 100), ('call_price', 1), ('draw_outs', 52),
                             ('draw_quality', 100), ('raise_percentage', 100)):
            number(row.get(field), field, 0, upper)
        require(not row['value_eligible'] or row['legal_raise'] or row['legal_bet'],
                'Value eligibility without aggression rights')
    require(report.get('cases') == len(cases) and len(cases) == 237
            and len(profiles) == 20 and len(keys) == len(cases) * len(profiles),
            'Incomplete fixed bank')


def validate_tournaments(report):
    metadata(report, 'bfcr_aggression_tournaments_v1')
    tournaments = report.get('tournaments')
    require(isinstance(tournaments, list) and len(tournaments) == 180, 'Need 180 tournaments')
    profiles = set()
    for index, t in enumerate(tournaments):
        require(t['seed'] == report['seed_start'] + index, 'Tournament seed ordering mismatch')
        number(t['player_count'], 'players', 2, 9, integer=True)
        number(t['starting_stack'], 'stack', 1, integer=True)
        require(type(t['mirrored']) is bool and len(t['seat_profiles']) == t['player_count'],
                'Invalid roster')
        profiles.update(t['seat_profiles'])
        require(t['completed'] is True and t['error'] == '' and t['invalid_actions'] == 0,
                'Incomplete or invalid tournament')
        for field in ('invalid_actions', 'chip_total', 'expected_chip_total', 'decisions',
                      'hands', 'maximum_raise_chain', 'betting_streets', 'streets_over_12_raises',
                      'long_chains', 'repeated_weak_bluffs'):
            number(t[field], field, integer=True)
        number(t['winner'], 'winner', 0, t['player_count'] - 1, integer=True)
        require(t['chip_total'] == t['expected_chip_total'] == t['player_count'] * t['starting_stack'],
                'Chip drift')
        summaries = t['summaries']
        require('all' in summaries, 'Missing all-action denominator')
        for row in summaries.values():
            n = number(row['decisions'], 'decisions', integer=True)
            require(counts(row['actions'], 'actions', ACTIONS) == n
                    and counts(row['branches'], 'branches') == n, 'Summary count mismatch')
            for field in ('legal_raise', 'legal_bet', 'value_eligible', 'bluff_eligible', 'post_aggression'):
                number(row[field], field, 0, n, integer=True)
            require(row['value_eligible'] <= row['legal_raise'] + row['legal_bet'], 'Eligibility mismatch')
        require(summaries['all']['decisions'] == t['decisions'], 'Decision mismatch')
        for prefix in ('profile:', 'street:', 'category:'):
            subset = [r for k, r in summaries.items() if k.startswith(prefix)]
            for field in ('decisions', 'legal_raise', 'legal_bet', 'value_eligible', 'bluff_eligible', 'post_aggression'):
                require(sum(r[field] for r in subset) == summaries['all'][field], 'Partition mismatch')
            for field in ('actions', 'branches'):
                aggregate = Counter()
                for row in subset:
                    aggregate.update(row[field])
                require(aggregate == Counter(summaries['all'][field]), 'Partition action mismatch')
        hist = t['raise_chain_histogram']
        weighted = 0
        for length, frequency in hist.items():
            require(str(int(length)) == length and int(length) > 0, 'Invalid chain length')
            number(frequency, 'chain frequency', 1, integer=True)
            weighted += int(length) * frequency
        # ALL_IN cannot occur with these strategy profiles: full raises use RAISE.
        require(weighted == summaries['all']['actions'].get('RAISE', 0), 'Chain/raise mismatch')
        tails = t['street_raise_tails']
        require(isinstance(tails, list) and len(tails) == t['betting_streets'], 'Street denominator mismatch')
        for tail in tails:
            number(tail, 'street tail', integer=True)
        maximum = max(tails, default=0)
        require(maximum == t['maximum_raise_chain'] == max(map(int, hist), default=0)
                and sum(x > 12 for x in tails) == t['streets_over_12_raises'], 'Tail mismatch')
        require(t['long_chains'] == sum(v for k, v in hist.items() if int(k) >= 3), 'Long-chain mismatch')
        tail_counts = Counter(x for x in tails if x > 0)
        require(all(v <= hist.get(str(k), 0) for k, v in tail_counts.items()), 'Unsupported street maximum')
        require(sum(hist.values()) >= sum(x > 0 for x in tails)
                and sum(tails) <= weighted, 'Impossible street tails')
        for row in t['response_summary'].values():
            n = number(row['opportunities'], 'opportunities', integer=True)
            require(sum(number(row[k], k, integer=True) for k in ('CALL', 'FOLD', 'RAISE', 'other')) == n,
                    'Response count mismatch')
            number(row['fold_rate'], 'fold_rate', 0, 1)
            require(math.isclose(row['fold_rate'], row['FOLD'] / n if n else 0), 'Response rate mismatch')
            interval = row['fold_wilson95']
            require(isinstance(interval, list) and len(interval) == 2, 'Invalid interval')
            for x in interval:
                number(x, 'interval', 0, 1)
            require(interval[0] <= interval[1], 'Reversed interval')
        response_n = t['response_summary'].get('all', {}).get('opportunities', 0)
        require(response_n == summaries.get('post_aggression', {}).get('decisions', 0),
                'Response denominator mismatch')
        response_all = t['response_summary'].get('all', {})
        for pair in (('weak', 'nonweak'), ('cheap_nonweak', 'outside_cheap_nonweak')):
            require(all(sum(t['response_summary'].get(group, {}).get(field, 0) for group in pair)
                        == response_all.get(field, 0)
                        for field in ('opportunities', 'CALL', 'FOLD', 'RAISE', 'other')),
                    'Response stratum partition mismatch')
        require(all(response_all.get(k, 0) <= summaries['all']['actions'].get(k, 0)
                    for k in ('CALL', 'FOLD', 'RAISE')), 'Response/action mismatch')
    require(len(profiles) == 15, 'Need all 15 profiles')


def identities(bank, tours):
    combined = dict(bank['source_hashes'])
    for key, digest in tours['source_hashes'].items():
        require(key not in combined or combined[key] == digest, 'Inconsistent source across reports')
        combined[key] = digest
    stable = {k: v for k, v in combined.items() if k.startswith('res://resources/bot_profiles/') or k in IMMUTABLE}
    require(all(k in stable for k in IMMUTABLE)
            and len([k for k in stable if k.endswith('.tres')]) == 15, 'Missing immutable identity')
    return stable


def aggregate_responses(tournaments):
    result = {}
    for t in tournaments:
        for group, row in t['response_summary'].items():
            target = result.setdefault(group, Counter())
            target.update({k: row[k] for k in ('opportunities', 'FOLD', 'CALL', 'RAISE', 'other')})
    return result


def rates(tournaments):
    rows = aggregate_responses(tournaments)
    def rate(group, action):
        row = rows.get(group, {})
        return row.get(action, 0) / row['opportunities'] if row.get('opportunities') else 0
    return {'nonweak_raise_share': rate('nonweak', 'RAISE'),
            'cheap_nonweak_fold_rate': rate('cheap_nonweak', 'FOLD')}


def paired_uncertainty(baseline, candidate, repetitions=1000):
    rng = random.Random(769013)
    deltas = {key: [] for key in rates(baseline)}
    for _ in range(repetitions):
        indices = rng.choices(range(len(baseline)), k=len(baseline))
        b = rates([baseline[i] for i in indices])
        c = rates([candidate[i] for i in indices])
        for key in deltas:
            deltas[key].append(c[key] - b[key])
    return {key: [sorted(values)[int(repetitions * .025)],
                  sorted(values)[int(repetitions * .975)]] for key, values in deltas.items()}


def profile_summaries(tournaments):
    result = {}
    for t in tournaments:
        for key, row in t['summaries'].items():
            if not key.startswith(('profile:', 'street:', 'category:')) and key != 'all':
                continue
            target = result.setdefault(key, {'actions': Counter(), 'branches': Counter(),
                                            'decisions': 0, 'legal_raise': 0, 'legal_bet': 0,
                                            'value_eligible': 0, 'bluff_eligible': 0})
            for field in ('actions', 'branches'):
                target[field].update(row[field])
            for field in ('decisions', 'legal_raise', 'legal_bet', 'value_eligible', 'bluff_eligible'):
                target[field] += row[field]
    for row in result.values():
        row['action_rates'] = {k: v / row['decisions'] for k, v in row['actions'].items()}
    return result


def compare(baseline_bank, candidate_bank, baseline_tournaments, candidate_tournaments, stage='final',
            uncertainty=True):
    require(stage in ('value', 'final'), 'Invalid stage')
    for bank in (baseline_bank, candidate_bank):
        validate_bank(bank)
    for tours in (baseline_tournaments, candidate_tournaments):
        validate_tournaments(tours)
    require(identities(baseline_bank, baseline_tournaments)
            == identities(candidate_bank, candidate_tournaments), 'Immutable inputs changed')
    for field in ('seed_start', 'samples', 'cases'):
        require(baseline_bank[field] == candidate_bank[field], 'Unmatched bank metadata')
    require(baseline_tournaments['seed_start'] == candidate_tournaments['seed_start'], 'Unmatched cohort')
    b_rows = {(r['case_id'], r['profile']): r for r in baseline_bank['rows']}
    c_rows = {(r['case_id'], r['profile']): r for r in candidate_bank['rows']}
    require(b_rows.keys() == c_rows.keys(), 'Unmatched bank cases/profiles')
    checks = {}
    def check(name, passed):
        checks[name] = bool(passed)
    continuation = exact_call = folds = initial = positive = bluff = negative = True
    for key, b in b_rows.items():
        c = c_rows[key]
        for field in ('scenario', 'street', 'player_count', 'starting_stack', 'legal_raise', 'legal_bet',
                      'score', 'call_price', 'draw_outs', 'draw_quality'):
            require(b[field] == c[field], 'Fixed bank state changed')
        n = b['samples']
        if b['profile'].startswith('control_raise_'):
            if sum(b['actions'].get(a, 0) for a in ('CALL', 'RAISE')) == n:
                continuation &= sum(c['actions'].get(a, 0) for a in ('CALL', 'RAISE')) == n
            if not b['legal_raise'] and b['actions'].get('CALL') == n:
                exact_call &= c['actions'].get('CALL') == n
        if b['scenario'] in ('expensive_value', 'weak_repeat', 'missed_draw') and b['actions'].get('FOLD') == n:
            folds &= c['actions'].get('FOLD') == n
        if b['scenario'] in ('initial_value', 'initial_bluff', 'strong_resistance'):
            initial &= b['actions'] == c['actions'] and b['branches'] == c['branches']
        if c['value_eligible'] and c['legal_raise'] and c['profile'] not in ('control_raise_0', 'control_bluff_0', 'control_bluff_100'):
            positive &= c['raise_percentage'] > 0
        bluff_count = sum(c['branches'].get(a, 0) for a in ('bluff_bet', 'bluff_raise'))
        if stage == 'value':
            bluff &= c['bluff_eligible'] == b['bluff_eligible'] and bluff_count == sum(b['branches'].get(a, 0) for a in ('bluff_bet', 'bluff_raise'))
        if c['profile'] == 'control_bluff_0':
            bluff &= bluff_count == 0
        if stage == 'final' and c['profile'] == 'control_bluff_100':
            bluff &= bluff_count == c['bluff_eligible']
            selected_backdoor = (c['street'] == 'flop' and c['starting_stack'] in (100, 1000)
                                 and ((c['scenario'] == 'delayed_backdoor' and c['player_count'] == 2)
                                      or (c['scenario'] in ('two_increases_backdoor', 'prior_call_backdoor')
                                          and c['player_count'] == 3)))
            if selected_backdoor:
                bluff &= c['bluff_eligible'] == n
            elif c['scenario'] in ('delayed_backdoor', 'two_increases_backdoor', 'prior_call_backdoor'):
                negative &= c['bluff_eligible'] == 0
            if c['scenario'] in ('delayed_bluff', 'prior_call_bluff', 'two_increases_weak', 'weak_repeat', 'missed_draw'):
                negative &= c['bluff_eligible'] == 0
    check('preserved_continuations', continuation)
    check('exact_call_when_raise_closed', exact_call)
    check('preserved_control_folds', folds)
    check('unchanged_initial_and_strong_controls', initial)
    check('positive_effective_value_percentage', positive)
    check('bluff_windows', bluff)
    check('negative_bluff_controls', negative)
    selected = [c_rows[('value_resistance/preflop/p2/s1000', f'control_raise_{gene}')] for gene in (0, 50, 100)]
    raising = [r['actions'].get('RAISE', 0) / r['samples'] for r in selected]
    check('ak_preference_response', raising[0] == 0 and .05 < raising[1] < raising[2] and .20 <= raising[2] <= .85)
    monotonic = True
    for case in {key[0] for key in c_rows}:
        control_rows = [c_rows[(case, f'control_raise_{gene}')] for gene in (0, 50, 100)]
        realized = [r['actions'].get('RAISE', 0) for r in control_rows]
        effective = [r['raise_percentage'] for r in control_rows]
        monotonic &= realized == sorted(realized) and effective == sorted(effective)
    check('coupled_control_count_monotonicity', monotonic)
    bt, ct = baseline_tournaments['tournaments'], candidate_tournaments['tournaments']
    for b, c in zip(bt, ct):
        for field in ('seed', 'player_count', 'starting_stack', 'mirrored', 'seat_profiles'):
            require(b[field] == c[field], 'Unmatched tournament metadata')
    br, cr = rates(bt), rates(ct)
    check('nonweak_raise_improvement', cr['nonweak_raise_share'] - br['nonweak_raise_share'] >= .05 - 1e-12)
    check('cheap_nonweak_fold_retention', cr['cheap_nonweak_fold_rate'] <= br['cheap_nonweak_fold_rate'] + .02 + 1e-12)
    streets = sum(t['betting_streets'] for t in ct)
    check('bounded_escalation', max(t['maximum_raise_chain'] for t in ct) <= 32 and streets > 0
          and sum(t['streets_over_12_raises'] for t in ct) / streets <= .01)
    check('no_repeated_weak_bluffs', all(t['repeated_weak_bluffs'] == 0 for t in ct))
    check('runtime', candidate_tournaments['runtime_seconds'] <= 2 * baseline_tournaments['runtime_seconds']
          and candidate_bank['runtime_seconds'] <= 2 * baseline_bank['runtime_seconds'])
    return {'schema': 'bfcr_aggression_comparison_v1', 'stage': stage, 'passed': all(checks.values()),
            'checks': checks, 'ak_raise_rates': raising, 'baseline_rates': br, 'candidate_rates': cr,
            'paired_tournament_delta_ci95': paired_uncertainty(bt, ct) if uncertainty else {},
            'baseline_summaries': profile_summaries(bt), 'candidate_summaries': profile_summaries(ct),
            'baseline_responses': aggregate_responses(bt), 'candidate_responses': aggregate_responses(ct),
            'baseline_chain_histogram': dict(sum((Counter(t['raise_chain_histogram']) for t in bt), Counter())),
            'candidate_chain_histogram': dict(sum((Counter(t['raise_chain_histogram']) for t in ct), Counter())),
            'limitations': ['Tournament policy changes alter encountered states; paired bootstrap resamples whole tournaments (1000 draws, seed 769013).',
                             'Bank counts use coupled seeds but cannot prove same-seed nesting; QA must separately verify monotonic decisions.',
                             'Observed betting streets exclude all-in runouts without a decision.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('baseline-bank', 'candidate-bank', 'baseline-tournaments', 'candidate-tournaments', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--stage', choices=('value', 'final'), default='final')
    parser.add_argument('--value-only-bank', type=Path)
    parser.add_argument('--value-only-tournaments', type=Path)
    parser.add_argument('--bluff-only-bank', type=Path)
    parser.add_argument('--bluff-only-tournaments', type=Path)
    args = parser.parse_args()
    try:
        require(not args.output.exists(), 'Output must be new')
        require(bool(args.value_only_bank) == bool(args.value_only_tournaments), 'Ablation requires both reports')
        require(bool(args.bluff_only_bank) == bool(args.bluff_only_tournaments), 'Bluff ablation requires both reports')
        load = lambda path: json.loads(path.read_text())
        bb, cb, bt, ct = [load(getattr(args, name)) for name in
                          ('baseline_bank', 'candidate_bank', 'baseline_tournaments', 'candidate_tournaments')]
        result = compare(bb, cb, bt, ct, args.stage)
        result['input_sha256'] = {name: hashlib.sha256(getattr(args, name).read_bytes()).hexdigest()
                                  for name in ('baseline_bank', 'candidate_bank', 'baseline_tournaments', 'candidate_tournaments')}
        result['immutable_source_hashes'] = identities(bb, bt)
        if args.value_only_bank:
            vb, vt = load(args.value_only_bank), load(args.value_only_tournaments)
            result['value_only_validation'] = compare(bb, vb, bt, vt, 'value')
            result['passed'] &= result['value_only_validation']['passed']
            result['ablation_final_minus_value_rates'] = {k: v - rates(vt['tournaments'])[k]
                                                         for k, v in rates(ct['tournaments']).items()}
        if args.bluff_only_bank:
            ab, at = load(args.bluff_only_bank), load(args.bluff_only_tournaments)
            validate_bank(ab)
            validate_tournaments(at)
            require(identities(bb, bt) == identities(ab, at), 'Bluff ablation immutable inputs changed')
            require(ab['seed_start'] == bb['seed_start'] and ab['samples'] == bb['samples']
                    and at['seed_start'] == bt['seed_start'], 'Unmatched bluff ablation cohort')
            for b, a in zip(bt['tournaments'], at['tournaments']):
                require(all(b[k] == a[k] for k in ('seed', 'player_count', 'starting_stack', 'mirrored', 'seat_profiles')),
                        'Unmatched bluff ablation roster')
            require({(r['case_id'], r['profile']) for r in ab['rows']}
                    == {(r['case_id'], r['profile']) for r in bb['rows']}, 'Unmatched bluff ablation bank')
            base_rows = {(r['case_id'], r['profile']): r for r in bb['rows']}
            for row in ab['rows']:
                original = base_rows[(row['case_id'], row['profile'])]
                require(all(row[k] == original[k] for k in ('scenario', 'street', 'player_count', 'starting_stack',
                            'legal_raise', 'legal_bet', 'score', 'call_price', 'draw_outs', 'draw_quality')),
                        'Bluff ablation fixed-state metadata changed')
            result['bluff_only_rates'] = rates(at['tournaments'])
            result['ablation_final_minus_bluff_rates'] = {k: v - rates(at['tournaments'])[k]
                                                         for k, v in rates(ct['tournaments']).items()}
            result['bluff_only_summaries'] = profile_summaries(at['tournaments'])
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('x') as stream:
            json.dump(result, stream, indent=2, allow_nan=False)
            stream.write('\n')
        return 0 if result['passed'] else 1
    except (ValueError, KeyError, TypeError, OSError) as error:
        print('Invalid aggression evidence: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
