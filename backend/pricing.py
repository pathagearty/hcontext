from __future__ import annotations

from decimal import Decimal
import json
from pathlib import Path

from .comparison_models import CostEstimate, MetricAvailability
from .telemetry import NormalizedUsage


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG_PATH = ROOT / "config" / "model_pricing.json"


def load_pricing_catalog(path: Path = DEFAULT_CATALOG_PATH) -> dict:
    if not path.is_file():
        return {"pricing_catalog_version": None, "entries": []}
    return json.loads(path.read_text(encoding="utf-8"))


def estimate_model_cost(
    model: str,
    usage: NormalizedUsage,
    *,
    catalog: dict | None = None,
) -> CostEstimate:
    catalog = catalog or load_pricing_catalog()
    if not usage.complete:
        return CostEstimate(
            availability=MetricAvailability.UNAVAILABLE,
            reason="Provider usage is incomplete",
            pricing_catalog_version=catalog.get("pricing_catalog_version"),
        )
    entry = next((item for item in catalog.get("entries", []) if item.get("model") == model), None)
    if entry is None:
        return CostEstimate(
            availability=MetricAvailability.UNAVAILABLE,
            reason="Approved pricing is not configured for this model",
            pricing_catalog_version=catalog.get("pricing_catalog_version"),
        )
    if entry.get("billing_type") != "token":
        return CostEstimate(
            availability=MetricAvailability.UNAVAILABLE,
            reason="The deployment is not billed per token",
            pricing_catalog_version=catalog.get("pricing_catalog_version"),
        )

    unit = Decimal(str(entry.get("token_unit", 1_000_000)))
    input_rate = Decimal(str(entry["input_rate"]))
    output_rate = Decimal(str(entry["output_rate"]))
    amount = (Decimal(usage.input_tokens or 0) / unit * input_rate) + (
        Decimal(usage.output_tokens or 0) / unit * output_rate
    )
    return CostEstimate(
        availability=MetricAvailability.AVAILABLE,
        currency=entry.get("currency", "USD"),
        amount=format(amount, "f"),
        pricing_catalog_version=catalog.get("pricing_catalog_version"),
    )
