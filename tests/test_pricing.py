from __future__ import annotations

from decimal import Decimal
import unittest

from backend.comparison_models import MetricAvailability
from backend.pricing import estimate_model_cost
from backend.telemetry import NormalizedUsage


class PricingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.usage = NormalizedUsage(1_000, 500, 1_500, 0, 0, True)

    def test_decimal_cost_estimate_uses_versioned_catalog(self) -> None:
        estimate = estimate_model_cost(
            "approved-model",
            self.usage,
            catalog={
                "pricing_catalog_version": "test-v1",
                "entries": [
                    {
                        "model": "approved-model",
                        "billing_type": "token",
                        "token_unit": 1_000,
                        "input_rate": "0.01",
                        "output_rate": "0.03",
                        "currency": "USD",
                    }
                ],
            },
        )
        self.assertEqual(estimate.availability, MetricAvailability.AVAILABLE)
        self.assertEqual(Decimal(estimate.amount or "0"), Decimal("0.025"))
        self.assertEqual(estimate.pricing_catalog_version, "test-v1")

    def test_missing_price_and_usage_are_unavailable(self) -> None:
        missing_price = estimate_model_cost(
            "unknown",
            self.usage,
            catalog={"pricing_catalog_version": "test-v1", "entries": []},
        )
        self.assertEqual(missing_price.availability, MetricAvailability.UNAVAILABLE)

        missing_usage = estimate_model_cost(
            "approved-model",
            NormalizedUsage(None, None, None, None, None, False),
            catalog={"pricing_catalog_version": "test-v1", "entries": []},
        )
        self.assertEqual(missing_usage.availability, MetricAvailability.UNAVAILABLE)


if __name__ == "__main__":
    unittest.main()
