from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

from .models import LotSummary

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "generated" / "hexacontext_demo.json"


@lru_cache(maxsize=1)
def load_dataset() -> dict[str, Any]:
    if not DATA_PATH.exists():
        raise RuntimeError("Synthetic dataset is missing; run `python3 data/generate.py`")
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def list_lots() -> list[LotSummary]:
    return [LotSummary.model_validate(item) for item in load_dataset()["lots"]]


def get_lot(lot_id: str) -> dict[str, Any]:
    for lot in load_dataset()["lots"]:
        if lot["lot_id"] == lot_id:
            return lot
    raise KeyError(lot_id)


def decision_profile() -> dict[str, Any]:
    return load_dataset()["decision_profile"]
