from __future__ import annotations

import unittest

from backend.telemetry import normalize_foundry_usage, simulated_usage


class TelemetryTests(unittest.TestCase):
    def test_normalizes_provider_usage_and_details_without_double_counting(self) -> None:
        usage = normalize_foundry_usage(
            {
                "input_tokens": 120,
                "output_tokens": 30,
                "total_tokens": 150,
                "input_tokens_details": {"cached_tokens": 40},
                "output_tokens_details": {"reasoning_tokens": 10},
            }
        )
        self.assertTrue(usage.complete)
        self.assertEqual(usage.total_tokens, 150)
        self.assertEqual(usage.cached_input_tokens, 40)
        self.assertEqual(usage.reasoning_tokens, 10)
        self.assertFalse(usage.derived_total)

    def test_derives_total_only_when_both_components_are_valid(self) -> None:
        usage = normalize_foundry_usage({"input_tokens": 12, "output_tokens": 5})
        self.assertTrue(usage.complete)
        self.assertEqual(usage.total_tokens, 17)
        self.assertTrue(usage.derived_total)

        malformed = normalize_foundry_usage({"input_tokens": -1, "output_tokens": 5})
        self.assertFalse(malformed.complete)
        self.assertIsNone(malformed.total_tokens)

    def test_missing_usage_is_unavailable_not_zero(self) -> None:
        usage = normalize_foundry_usage(None)
        self.assertFalse(usage.complete)
        self.assertIsNone(usage.input_tokens)
        self.assertIsNone(usage.total_tokens)

    def test_simulated_usage_is_explicit_and_deterministic(self) -> None:
        first = simulated_usage("request", "response")
        second = simulated_usage("request", "response")
        self.assertEqual(first, second)
        self.assertGreater(first.total_tokens or 0, 0)


if __name__ == "__main__":
    unittest.main()
