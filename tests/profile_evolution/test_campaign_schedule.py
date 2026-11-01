"""Nine-player schedule fairness, coverage and seed reservation checks."""
from __future__ import annotations

import copy
import unittest
from itertools import combinations

from tests.profile_evolution.test_campaign import _prepared_campaign
from tools.profile_evolution.artifacts import create_artifact
from tools.profile_evolution.campaign import freeze_candidates
from tools.profile_evolution.campaign_generation import generate_candidates
from tools.profile_evolution.campaign_schedule import _manifest, audit_manifest, build_pilot_manifest, build_round_manifest
from tools.profile_evolution.errors import ToolError
from tools.profile_evolution.fitness import _validate_manifest


class CampaignScheduleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        prepared = _prepared_campaign()
        cls.campaign = freeze_candidates(prepared, generate_candidates(prepared))
        cls.survivors = [row["candidate_id"] for row in cls.campaign["payload"]["contenders"][:25]]
        cls.round1 = build_round_manifest(cls.campaign)
        cls.round2 = build_round_manifest(cls.campaign, 2, cls.survivors)

    def test_thirty_participant_design_has_equal_participation_seats_and_balanced_pairs(self) -> None:
        # This is a synthetic test cohort, never the campaign's actual survivors.
        for manifest, participants, total, exposure, seats in ((self.round2, 30, 17820, 5346, 594),):
            with self.subTest(participants=participants):
                _validate_manifest(manifest)
                certificate = audit_manifest(manifest)
                self.assertEqual(participants, certificate["profile_count"])
                self.assertEqual(participants, certificate["matchup_count"])
                self.assertEqual(total, certificate["tournament_count"])
                self.assertEqual({exposure}, set(certificate["appearances_by_profile"].values()))
                self.assertEqual({(seats,) * 9}, {tuple(row) for row in certificate["seat_counts_by_profile"].values()})
                actual_pairs = {tuple(row["profile_ids"]) for row in certificate["pair_counts"]}
                self.assertEqual(set(combinations(sorted(certificate["appearances_by_profile"]), 2)), actual_pairs)
                self.assertEqual({9}, set(certificate["matchup_appearances_by_profile"].values()))
                self.assertEqual(2, certificate["minimum_pair_matchup_frequency"])
                self.assertEqual(3, certificate["maximum_pair_matchup_frequency"])
                self.assertEqual({2, 3}, {row["matchup_count"] for row in certificate["pair_counts"]})
                self.assertTrue(all(row["tournament_count"] == 594 * row["matchup_count"] for row in certificate["pair_counts"]))
                self.assertGreater(certificate["minimum_pair_frequency"], 0)
                self.assertGreaterEqual(certificate["maximum_pair_frequency"], certificate["minimum_pair_frequency"])
                self.assertEqual(sum(certificate["appearances_by_profile"].values()), total * 9)

    def test_round1_uses_user_seed_and_cyclic_shifts_with_pair_spread_two(self) -> None:
        manifest = self.round1
        ids = [p["profile_id"] for p in manifest["profiles"]]
        base = (0, 1, 4, 6, 11, 17, 23, 31, 32)
        for shift, table in enumerate(manifest["matchups"]):
            self.assertEqual([ids[(i + shift) % 35] for i in base], table["profile_ids"])
        certificate = audit_manifest(manifest)
        self.assertEqual(35, certificate["matchup_count"])
        self.assertEqual({9}, set(certificate["matchup_appearances_by_profile"].values()))
        self.assertEqual({2673}, set(certificate["appearances_by_profile"].values()))
        self.assertEqual({(297,) * 9}, {tuple(x) for x in certificate["seat_counts_by_profile"].values()})
        counts = [p["matchup_count"] for p in certificate["pair_counts"]]
        self.assertEqual(35, counts.count(1))
        self.assertEqual(455, counts.count(2))
        self.assertEqual(105, counts.count(3))
        self.assertEqual(595, len(counts))
        self.assertEqual(2, max(counts) - min(counts))

    def test_old_high_variance_round1_schedule_is_rejected(self) -> None:
        context = self.campaign["payload"]
        profiles = [r["profile"] for r in context["contenders"]] + context["inventory"]["fixed_controls"]
        base = [2, 1, 4, 6, 11, 17, 23, 31, 32]
        tables = [[profiles[(index + shift) % 35]["profile_id"] for index in base] for shift in range(35)]
        manifest = _manifest(context, profiles, tables, "round1", 35 * 297)
        with self.assertRaisesRegex(ToolError, "frequency spread"):
            audit_manifest(manifest)

    def test_thirty_participant_schedule_may_have_pair_spread_two(self) -> None:
        manifest = copy.deepcopy(self.round2)
        ids = [p["profile_id"] for p in manifest["profiles"]]
        base = [4, 14, 21, 0, 5, 24, 11, 6, 2]
        for shift, table in enumerate(manifest["matchups"]):
            table["profile_ids"] = [ids[(index + shift) % 30] for index in base]
        certificate = audit_manifest(manifest)
        self.assertEqual(435, certificate["opponent_pair_count"])
        self.assertEqual(2, certificate["minimum_pair_matchup_frequency"])
        self.assertEqual(4, certificate["maximum_pair_matchup_frequency"])
        self.assertEqual(2, certificate["maximum_allowed_pair_matchup_spread"])

    def test_balanced_pairs_do_not_replace_cyclic_construction(self) -> None:
        manifest = copy.deepcopy(self.round2)
        table = manifest["matchups"][1]["profile_ids"]
        table[0], table[1] = table[1], table[0]
        with self.assertRaisesRegex(ToolError, "complete cyclic shifts"):
            audit_manifest(manifest)

    def test_generation_is_deterministic_and_survivor_input_order_is_irrelevant(self) -> None:
        self.assertEqual(self.round2, build_round_manifest(self.campaign, 2, reversed(self.survivors)))
        original = copy.deepcopy(self.campaign)
        build_round_manifest(self.campaign, 2, self.survivors)
        self.assertEqual(original, self.campaign)

    def test_round_two_profiles_are_seed_shuffled_before_matchup_numbering(self) -> None:
        context = self.campaign["payload"]
        expected_profiles = [r["profile"] for r in context["contenders"] if r["candidate_id"] in self.survivors] + context["inventory"]["fixed_controls"]
        ordered = self.round2["profiles"]
        self.assertNotEqual([p["profile_id"] for p in expected_profiles], [p["profile_id"] for p in ordered])
        self.assertEqual({p["profile_id"] for p in expected_profiles}, {p["profile_id"] for p in ordered})
        self.assertEqual(self.round2, build_round_manifest(self.campaign, 2, list(reversed(self.survivors))))
        for shift, table in enumerate(self.round2["matchups"]):
            previous = self.round2["matchups"][0]["profile_ids"]
            first_indices = [next(i for i, p in enumerate(ordered) if p["profile_id"] == identifier) for identifier in previous]
            self.assertEqual([ordered[(i + shift) % 30]["profile_id"] for i in first_indices], table["profile_ids"])
        protected = {p["profile_id"] for p in context["inventory"]["fixed_controls"]}
        self.assertTrue(protected.issubset({p["profile_id"] for p in ordered}))

    def test_round2_requires_twenty_five_distinct_known_candidate_ids(self) -> None:
        bad = (None, [], self.survivors[:24], self.survivors + [self.survivors[-1]],
               [self.survivors[0]] * 25, self.survivors[:24] + ["unknown"],
               self.survivors[:24] + [self.campaign["payload"]["inventory"]["fixed_controls"][0]["profile_id"]],
               "candidate", self.survivors[:24] + [True])
        for ids in bad:
            with self.subTest(ids=ids), self.assertRaises(ToolError):
                build_round_manifest(self.campaign, 2, ids)
        for number in (0, 3, True, 1.0):
            with self.subTest(number=number), self.assertRaises(ToolError):
                build_round_manifest(self.campaign, number)
        with self.assertRaises(ToolError):
            build_round_manifest(self.campaign, 1, self.survivors)

    def test_duplicate_seats_missing_tables_and_missing_profiles_are_rejected(self) -> None:
        mutations = (
            lambda m: m["matchups"][0]["profile_ids"].__setitem__(0, m["matchups"][0]["profile_ids"][1]),
            lambda m: m["matchups"].pop(),
            lambda m: m["profiles"].pop(),
            lambda m: m["evaluation_plans"][0]["matchup_ids"].pop(),
            lambda m: m["evaluation_plans"][0]["matchup_ids"].append(m["evaluation_plans"][0]["matchup_ids"][0]),
            lambda m: m["evaluation_plans"][0].__setitem__("tournament_count", 31501),
        )
        for index, mutate in enumerate(mutations):
            manifest = copy.deepcopy(self.round2)
            mutate(manifest)
            with self.subTest(index=index), self.assertRaises(ToolError):
                audit_manifest(manifest)

    def test_equal_appearance_schedule_with_missing_pairs_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.round2)
        ids = [profile["profile_id"] for profile in manifest["profiles"]]
        for translation, table in enumerate(manifest["matchups"]):
            table["profile_ids"] = [ids[(offset + translation) % len(ids)] for offset in range(9)]
        with self.assertRaisesRegex(ToolError, "every opponent pair"):
            audit_manifest(manifest)

    def test_non_nine_player_start_is_rejected(self) -> None:
        for size in (2, 6, 8, 10):
            manifest = copy.deepcopy(self.round2)
            manifest["regimes"][0]["player_count"] = size
            for table in manifest["matchups"]:
                table["profile_ids"] = table["profile_ids"][:size]
            with self.subTest(size=size), self.assertRaises(ToolError):
                audit_manifest(manifest)

    def test_legacy_models_cannot_participate(self) -> None:
        manifest = copy.deepcopy(self.round2)
        manifest["profiles"][0].update(model_id="random", parameters={"fold_weight": 1, "passive_weight": 4, "aggressive_weight": 2})
        with self.assertRaisesRegex(ToolError, "strategic model"):
            audit_manifest(manifest)

    def test_expected_profile_identity_set_is_checked(self) -> None:
        ids = [profile["profile_id"] for profile in self.round2["profiles"]]
        audit_manifest(self.round2, ids)
        for expected in (ids[:-1], ids + [ids[0]], ids[:-1] + ["unknown"]):
            with self.subTest(expected=expected), self.assertRaises(ToolError):
                audit_manifest(self.round2, expected)

    def test_verified_patterns_reject_unsupported_participant_counts(self) -> None:
        from tools.profile_evolution.campaign_schedule import _base_block
        for count in (9, 29, 31, 36):
            with self.subTest(count=count), self.assertRaisesRegex(ToolError, "supports thirty"):
                _base_block(count, 2026110112)

    def test_pilot_starts_nine_distinct_strategic_profiles_on_reserved_seeds(self) -> None:
        pilot = build_pilot_manifest(self.campaign)
        self.assertEqual(pilot, build_pilot_manifest(self.campaign))
        _validate_manifest(pilot)
        self.assertEqual(9, len(pilot["profiles"]))
        self.assertTrue(all(p["model_id"] == "strategy_parameterized" for p in pilot["profiles"]))
        self.assertEqual(9, len(set(pilot["matchups"][0]["profile_ids"])))
        self.assertEqual(36, pilot["evaluation_plans"][0]["tournament_count"])
        self.assertEqual(self.campaign["payload"]["config"]["seed_blocks"]["pilot"]["minimum"], pilot["seed_start"])
        for count in (0, 1, 35, True, 36.0):
            with self.subTest(count=count), self.assertRaises(ToolError):
                build_pilot_manifest(self.campaign, count)

    def test_reserved_seed_block_overflow_and_prepared_campaign_are_rejected(self) -> None:
        prepared = _prepared_campaign()
        for function in (build_round_manifest, build_pilot_manifest):
            with self.subTest(function=function.__name__), self.assertRaises(ToolError):
                function(prepared)
        prepared["payload"]["config"]["seed_blocks"]["round2"]["maximum"] = prepared["payload"]["config"]["seed_blocks"]["round2"]["minimum"]
        prepared = create_artifact(prepared["type"], prepared["payload"])
        frozen = freeze_candidates(prepared, generate_candidates(prepared))
        with self.assertRaisesRegex(ToolError, "reserved block"):
            build_round_manifest(frozen, 2, [r["candidate_id"] for r in frozen["payload"]["contenders"][:25]])


if __name__ == "__main__":
    unittest.main()
