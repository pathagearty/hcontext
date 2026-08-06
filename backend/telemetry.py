from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any


@dataclass(frozen=True)
class NormalizedUsage:
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    cached_input_tokens: int | None
    reasoning_tokens: int | None
    complete: bool
    derived_total: bool = False


def _token(value: Any) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None


def normalize_foundry_usage(raw: dict[str, Any] | None) -> NormalizedUsage:
    if not isinstance(raw, dict):
        return NormalizedUsage(None, None, None, None, None, False)

    input_tokens = _token(raw.get("input_tokens"))
    output_tokens = _token(raw.get("output_tokens"))
    total_tokens = _token(raw.get("total_tokens"))
    input_details = raw.get("input_tokens_details")
    output_details = raw.get("output_tokens_details")
    cached = _token(input_details.get("cached_tokens")) if isinstance(input_details, dict) else None
    reasoning = _token(output_details.get("reasoning_tokens")) if isinstance(output_details, dict) else None

    derived = False
    if total_tokens is None and input_tokens is not None and output_tokens is not None:
        total_tokens = input_tokens + output_tokens
        derived = True
    if cached is not None and input_tokens is not None and cached > input_tokens:
        cached = None

    complete = input_tokens is not None and output_tokens is not None and total_tokens is not None
    return NormalizedUsage(
        input_tokens,
        output_tokens,
        total_tokens,
        cached,
        reasoning,
        complete,
        derived,
    )


def simulated_usage(input_text: str, output_text: str) -> NormalizedUsage:
    """Deterministic UI-contract estimate; never label this provider-reported."""

    input_tokens = max(1, math.ceil(len(input_text) / 4))
    output_tokens = max(1, math.ceil(len(output_text) / 4))
    return NormalizedUsage(
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        total_tokens=input_tokens + output_tokens,
        cached_input_tokens=0,
        reasoning_tokens=0,
        complete=True,
        derived_total=True,
    )
