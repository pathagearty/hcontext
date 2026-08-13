from __future__ import annotations

from collections.abc import Mapping, Sequence
from datetime import datetime
from typing import Any

import httpx

from .settings import AppSettings


class SupabaseEvaluatorStore:
    """Server-only access to the private scoring plane.

    This class must never be registered as a Foundry tool. Unlike the runtime
    gateway, it deliberately uses the service key and can call only the two
    service_role-only evaluator RPCs.
    """

    def __init__(
        self,
        settings: AppSettings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        settings.require_supabase_evaluator()
        if transport is not None and http_client is not None:
            raise ValueError("Provide either transport or http_client, not both")
        self.settings = settings
        self._client = http_client or httpx.AsyncClient(
            base_url=settings.supabase_url.rstrip("/") + "/rest/v1/",
            timeout=settings.supabase_timeout_seconds,
            transport=transport,
        )
        self._owns_client = http_client is None

    async def __aenter__(self) -> SupabaseEvaluatorStore:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def _rpc(self, name: str, arguments: Mapping[str, Any]) -> dict[str, Any]:
        response = await self._client.post(
            f"rpc/{name}",
            headers={
                "apikey": self.settings.supabase_secret_key,
                "authorization": f"Bearer {self.settings.supabase_secret_key}",
                "accept": "application/json",
                "content-type": "application/json",
            },
            json=dict(arguments),
        )
        response.raise_for_status()
        payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("Evaluator RPC returned an invalid response")
        return payload

    async def get_case(self, lot_id: str, snapshot_id: str) -> dict[str, Any]:
        payload = await self._rpc(
            "get_private_case_evaluation",
            {"p_lot_id": lot_id, "p_snapshot_id": snapshot_id},
        )
        if not payload:
            raise KeyError(lot_id)
        return payload

    async def store_run(
        self,
        *,
        comparison_run_id: str,
        lot_id: str,
        snapshot_id: str,
        execution_mode: str,
        request_hash: str,
        started_at: datetime,
        completed_at: datetime,
        model_versions: Mapping[str, Any],
        baseline_result: Mapping[str, Any],
        hexacontext_result: Mapping[str, Any],
        baseline_trace: Sequence[Mapping[str, Any]],
        hexacontext_trace: Sequence[Mapping[str, Any]],
        scores: Mapping[str, Any],
    ) -> dict[str, Any]:
        return await self._rpc(
            "store_private_evaluation_run",
            {
                "p_comparison_run_id": comparison_run_id,
                "p_lot_id": lot_id,
                "p_snapshot_id": snapshot_id,
                "p_execution_mode": execution_mode,
                "p_request_hash": request_hash,
                "p_started_at": started_at.isoformat(),
                "p_completed_at": completed_at.isoformat(),
                "p_model_versions": dict(model_versions),
                "p_baseline_result": dict(baseline_result),
                "p_hexacontext_result": dict(hexacontext_result),
                "p_baseline_trace": list(baseline_trace),
                "p_hexacontext_trace": list(hexacontext_trace),
                "p_scores": dict(scores),
            },
        )
