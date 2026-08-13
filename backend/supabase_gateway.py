from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
import re
import secrets
import time
from typing import Any

import httpx

from .settings import AppSettings


TOOL_CONTRACT_VERSION = "1.0"
_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
_ALLOWED_RELATED_SUBJECT_TYPES = frozenset({"part", "supplier", "equipment"})


@dataclass(frozen=True)
class ToolRequestContext:
    """Immutable server-owned context for one comparison request.

    The model never supplies the access token, tenant, scopes, subject lot,
    snapshot, or pinned time. Tenant and scopes are resolved by Supabase RLS from
    signed Auth app_metadata in ``access_token``.
    """

    comparison_run_id: str
    request_id: str
    subject_lot_id: str
    snapshot_id: str
    as_of_time: str
    access_token: str = field(repr=False)


class SupabaseToolGateway:
    def __init__(
        self,
        settings: AppSettings,
        context: ToolRequestContext,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        settings.require_supabase_gateway()
        if transport is not None and http_client is not None:
            raise ValueError("Provide either transport or http_client, not both")
        if context.snapshot_id != settings.supabase_snapshot_id:
            raise ValueError("Tool context snapshot does not match configured snapshot")
        if context.as_of_time != settings.supabase_as_of_time:
            raise ValueError("Tool context time does not match configured pinned time")
        self._require_identifier("subject_lot_id", context.subject_lot_id)
        if not context.access_token.strip():
            raise ValueError("An approved Supabase user access token is required")
        if settings.supabase_secret_key and secrets.compare_digest(
            context.access_token, settings.supabase_secret_key
        ):
            raise ValueError("The service-role/secret key cannot be used as the evidence-query identity")

        self.settings = settings
        self.context = context
        self._client = http_client or httpx.AsyncClient(
            base_url=settings.supabase_url.rstrip("/") + "/rest/v1/",
            timeout=settings.supabase_timeout_seconds,
            transport=transport,
        )
        self._owns_client = http_client is None

    async def __aenter__(self) -> SupabaseToolGateway:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    @staticmethod
    def _require_identifier(name: str, value: str) -> None:
        if not _IDENTIFIER.fullmatch(value):
            raise ValueError(f"{name} must be an exact 1-64 character identifier")

    def _envelope(
        self,
        tool_name: str,
        *,
        ok: bool,
        items: Sequence[Mapping[str, Any]] = (),
        errors: Sequence[Mapping[str, str]] = (),
        duration_ms: int = 0,
    ) -> dict[str, Any]:
        return {
            "ok": ok,
            "tool_name": tool_name,
            "tool_contract_version": TOOL_CONTRACT_VERSION,
            "data_snapshot_id": self.context.snapshot_id,
            "items": list(items),
            "excluded_unauthorized_count": 0,
            "next_page_token": None,
            "warnings": [],
            "errors": list(errors),
            "duration_ms": duration_ms,
        }

    def _invalid(self, tool_name: str, message: str) -> dict[str, Any]:
        return self._envelope(
            tool_name,
            ok=False,
            errors=[{"code": "INVALID_ARGUMENT", "message": message}],
        )

    async def _rpc(self, tool_name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        started = time.perf_counter()
        try:
            response = await self._client.post(
                f"rpc/{tool_name}",
                headers={
                    "apikey": self.settings.supabase_publishable_key,
                    "authorization": f"Bearer {self.context.access_token}",
                    "accept": "application/json",
                    "content-type": "application/json",
                },
                json=arguments,
            )
        except httpx.TimeoutException:
            return self._envelope(
                tool_name,
                ok=False,
                errors=[{"code": "TIMEOUT", "message": "The approved source query timed out."}],
                duration_ms=round((time.perf_counter() - started) * 1000),
            )
        except httpx.TransportError:
            return self._envelope(
                tool_name,
                ok=False,
                errors=[{"code": "SOURCE_UNAVAILABLE", "message": "The approved source is unavailable."}],
                duration_ms=round((time.perf_counter() - started) * 1000),
            )

        duration_ms = round((time.perf_counter() - started) * 1000)
        if response.status_code >= 400:
            if response.status_code in {401, 403}:
                code, message = "UNAUTHORIZED", "The approved source rejected this actor context."
            elif response.status_code == 404:
                code, message = "SCHEMA_ERROR", "The approved tool operation is unavailable."
            elif response.status_code == 429:
                code, message = "RATE_LIMITED", "The approved source rate limit was reached."
            elif response.status_code >= 500:
                code, message = "SOURCE_UNAVAILABLE", "The approved source is unavailable."
            else:
                code, message = "SCHEMA_ERROR", "The approved source rejected the tool operation."
            return self._envelope(
                tool_name,
                ok=False,
                errors=[{"code": code, "message": message}],
                duration_ms=duration_ms,
            )

        try:
            payload = response.json()
        except ValueError:
            payload = None
        if not isinstance(payload, dict):
            return self._envelope(
                tool_name,
                ok=False,
                errors=[{"code": "SCHEMA_ERROR", "message": "The approved source returned an invalid envelope."}],
                duration_ms=duration_ms,
            )
        if (
            payload.get("tool_name") != tool_name
            or payload.get("tool_contract_version") != TOOL_CONTRACT_VERSION
            or payload.get("data_snapshot_id") != self.context.snapshot_id
            or not isinstance(payload.get("items"), list)
            or not isinstance(payload.get("errors"), list)
        ):
            return self._envelope(
                tool_name,
                ok=False,
                errors=[{"code": "SCHEMA_ERROR", "message": "The approved source returned a mismatched envelope."}],
                duration_ms=duration_ms,
            )
        payload["duration_ms"] = duration_ms
        return payload

    async def get_decision_profile(
        self, profile_id: str, profile_version: str
    ) -> dict[str, Any]:
        try:
            self._require_identifier("profile_id", profile_id)
        except ValueError as error:
            return self._invalid("get_decision_profile", str(error))
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", profile_version):
            return self._invalid("get_decision_profile", "profile_version must be an exact numeric version")
        return await self._rpc(
            "get_decision_profile",
            {
                "p_profile_id": profile_id,
                "p_profile_version": profile_version,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_lot_record(self, lot_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("lot_id", lot_id)
        except ValueError as error:
            return self._invalid("get_lot_record", str(error))
        if lot_id != self.context.subject_lot_id:
            return self._invalid("get_lot_record", "lot_id must match the server-bound subject lot")
        return await self._rpc(
            "get_lot_record",
            {"p_lot_id": lot_id, "p_snapshot_id": self.context.snapshot_id},
        )

    async def get_supplier_quality_history(
        self,
        supplier_id: str,
        part_id: str,
        *,
        lookback_days: int = 90,
        limit: int = 20,
    ) -> dict[str, Any]:
        try:
            self._require_identifier("supplier_id", supplier_id)
            self._require_identifier("part_id", part_id)
        except ValueError as error:
            return self._invalid("get_supplier_quality_history", str(error))
        if not 1 <= lookback_days <= 365 or not 1 <= limit <= 20:
            return self._invalid(
                "get_supplier_quality_history", "lookback_days must be 1-365 and limit must be 1-20"
            )
        return await self._rpc(
            "get_supplier_quality_history",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_supplier_id": supplier_id,
                "p_part_id": part_id,
                "p_as_of_time": self.context.as_of_time,
                "p_lookback_days": lookback_days,
                "p_limit": limit,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_equipment_calibration(self, equipment_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("equipment_id", equipment_id)
        except ValueError as error:
            return self._invalid("get_equipment_calibration", str(error))
        return await self._rpc(
            "get_equipment_calibration",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_equipment_id": equipment_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_released_part_revision(self, part_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("part_id", part_id)
        except ValueError as error:
            return self._invalid("get_released_part_revision", str(error))
        return await self._rpc(
            "get_released_part_revision",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_part_id": part_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_open_deviations(
        self,
        related_subject_types: Sequence[str],
        *,
        max_relationship_depth: int = 2,
        limit: int = 20,
    ) -> dict[str, Any]:
        subjects = list(dict.fromkeys(related_subject_types))
        if (
            not set(subjects) <= _ALLOWED_RELATED_SUBJECT_TYPES
            or not 0 <= max_relationship_depth <= 2
            or not 1 <= limit <= 20
        ):
            return self._invalid(
                "get_open_deviations",
                "Use approved subject types, relationship depth 0-2 and limit 1-20",
            )
        return await self._rpc(
            "get_open_deviations",
            {
                "p_lot_id": self.context.subject_lot_id,
                "p_related_subject_types": subjects,
                "p_as_of_time": self.context.as_of_time,
                "p_max_relationship_depth": max_relationship_depth,
                "p_limit": limit,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def search_manufacturing_notes(
        self,
        subject_ids: Sequence[str],
        query: str,
        *,
        limit: int = 10,
    ) -> dict[str, Any]:
        subjects = list(dict.fromkeys(subject_ids))
        try:
            for subject_id in subjects:
                self._require_identifier("subject_id", subject_id)
        except ValueError as error:
            return self._invalid("search_manufacturing_notes", str(error))
        if not subjects or not 2 <= len(query.strip()) <= 200 or not 1 <= limit <= 10:
            return self._invalid(
                "search_manufacturing_notes",
                "At least one exact subject, a 2-200 character query and limit 1-10 are required",
            )
        return await self._rpc(
            "search_manufacturing_notes",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_subject_ids": subjects,
                "p_query": query.strip(),
                "p_as_of_time": self.context.as_of_time,
                "p_limit": limit,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_lot_work_orders(self) -> dict[str, Any]:
        return await self._rpc(
            "get_lot_work_orders",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_work_order_operations(self, work_order_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("work_order_id", work_order_id)
        except ValueError as error:
            return self._invalid("get_work_order_operations", str(error))
        return await self._rpc(
            "get_work_order_operations",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_work_order_id": work_order_id,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_operation_equipment_usage(self, operation_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("operation_id", operation_id)
        except ValueError as error:
            return self._invalid("get_operation_equipment_usage", str(error))
        return await self._rpc(
            "get_operation_equipment_usage",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_operation_id": operation_id,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_connected_equipment_calibration(
        self, equipment_id: str
    ) -> dict[str, Any]:
        try:
            self._require_identifier("equipment_id", equipment_id)
        except ValueError as error:
            return self._invalid("get_connected_equipment_calibration", str(error))
        return await self._rpc(
            "get_connected_equipment_calibration",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_equipment_id": equipment_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_part_bom(self, part_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("part_id", part_id)
        except ValueError as error:
            return self._invalid("get_part_bom", str(error))
        return await self._rpc(
            "get_part_bom",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_part_id": part_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_lot_component_usage(self, bom_item_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("bom_item_id", bom_item_id)
        except ValueError as error:
            return self._invalid("get_lot_component_usage", str(error))
        return await self._rpc(
            "get_lot_component_usage",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_bom_item_id": bom_item_id,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_material_batch_records(self, material_batch_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("material_batch_id", material_batch_id)
        except ValueError as error:
            return self._invalid("get_material_batch_records", str(error))
        return await self._rpc(
            "get_material_batch_records",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_material_batch_id": material_batch_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )

    async def get_engineering_change_orders(self, part_id: str) -> dict[str, Any]:
        try:
            self._require_identifier("part_id", part_id)
        except ValueError as error:
            return self._invalid("get_engineering_change_orders", str(error))
        return await self._rpc(
            "get_engineering_change_orders",
            {
                "p_subject_lot_id": self.context.subject_lot_id,
                "p_part_id": part_id,
                "p_as_of_time": self.context.as_of_time,
                "p_snapshot_id": self.context.snapshot_id,
            },
        )
