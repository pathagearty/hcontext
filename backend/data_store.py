from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from .models import LotSummary

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "generated" / "hexacontext_demo.json"
EVALUATION_DATA_PATH = ROOT / "data" / "generated" / "hexacontext_evaluation.json"


@lru_cache(maxsize=1)
def load_dataset() -> dict[str, Any]:
    if not DATA_PATH.exists():
        raise RuntimeError("Synthetic dataset is missing; run `python3 data/generate.py`")
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def load_evaluation_dataset() -> dict[str, Any]:
    if not EVALUATION_DATA_PATH.exists():
        raise RuntimeError("Evaluator fixture is missing; run `python3 data/generate.py`")
    return json.loads(EVALUATION_DATA_PATH.read_text(encoding="utf-8"))


def expected_dispositions() -> dict[str, str]:
    """Answer keys are available only to evaluator code, never runtime/public models."""

    return {
        item["lot_id"]: item["expected_disposition"]
        for item in load_evaluation_dataset()["cases"]
    }


def list_lots() -> list[LotSummary]:
    return [LotSummary.model_validate(item) for item in load_dataset()["lots"]]


def get_lot(lot_id: str) -> dict[str, Any]:
    for lot in load_dataset()["lots"]:
        if lot["lot_id"] == lot_id:
            return lot
    raise KeyError(lot_id)


def decision_profile() -> dict[str, Any]:
    return load_dataset()["decision_profile"]
