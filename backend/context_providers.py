from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Any

from data.generate_supabase_v1 import PRIMARY_TENANT, build_dataset

from .comparison_models import EvidenceSummary


AUTHORIZED_SCOPES = frozenset({"quality", "general"})
CONTEXT_CORE_ID = "manufacturing_context_core"
CONTEXT_CORE_VERSION = "1.0"
PROJECTION_STRATEGY = "MINIMUM_SUFFICIENT"

EVIDENCE_TITLES = {
    "lot_record": "Manufacturing lot record",
    "final_inspection": "Final inspection",
    "certificate_of_analysis": "Certificate of analysis",
    "equipment_calibration": "Equipment calibration",
    "released_revision_alignment": "Released engineering revision",
    "supplier_part_family_history": "Supplier quality history",
    "open_deviation_check": "Connected deviation",
    "authorized_narrative_conflict_check": "Authorized manufacturing note",
}

EVIDENCE_METADATA = {
    "lot_record": ("MANUFACTURING_EXECUTION", "manufacturing_lots"),
    "final_inspection": ("QUALITY_MANAGEMENT", "inspections"),
    "certificate_of_analysis": ("SUPPLIER_QUALITY", "certificates_of_analysis"),
    "equipment_calibration": ("EQUIPMENT_CALIBRATION", "calibration_records"),
    "released_revision_alignment": ("ENGINEERING_LIFECYCLE", "engineering_revisions"),
    "supplier_part_family_history": ("SUPPLIER_QUALITY", "supplier_quality_events"),
    "open_deviation_check": ("QUALITY_MANAGEMENT", "deviations"),
    "authorized_narrative_conflict_check": ("MANUFACTURING_EXECUTION", "manufacturing_notes"),
}

CONTEXT_REQUIREMENTS = {
    "lot_record": {
        "requirement_key": "lot_identity",
        "relationship": ["manufacturing_lot"],
        "selection_reason": "Required subject identity from the active Decision Profile.",
    },
    "final_inspection": {
        "requirement_key": "final_inspection",
        "relationship": ["manufacturing_lot", "inspection"],
        "selection_reason": "Required signed inspection evidence connected to the subject lot.",
    },
    "certificate_of_analysis": {
        "requirement_key": "direct_certificate",
        "relationship": ["manufacturing_lot", "certificate_of_analysis"],
        "selection_reason": "Required supplier certificate evidence connected to the subject lot.",
    },
    "equipment_calibration": {
        "requirement_key": "inspection_calibration",
        "relationship": ["manufacturing_lot", "inspection", "equipment", "calibration_record"],
        "selection_reason": "Calibration selected through the inspection-equipment relationship and evaluated at the pinned time.",
    },
    "released_revision_alignment": {
        "requirement_key": "released_revision",
        "relationship": ["manufacturing_lot", "part", "engineering_revision"],
        "selection_reason": "Time-effective released revision selected through the lot-part relationship.",
    },
    "supplier_part_family_history": {
        "requirement_key": "supplier_history",
        "relationship": ["manufacturing_lot", "supplier", "part", "supplier_quality_event"],
        "selection_reason": "Bounded recent supplier/part history required by the Decision Profile.",
    },
    "open_deviation_check": {
        "requirement_key": "open_deviations",
        "relationship": ["manufacturing_lot", "deviation"],
        "selection_reason": "Open governed deviation connected to the lot, part, supplier, or inspection equipment.",
    },
    "authorized_narrative_conflict_check": {
        "requirement_key": "authorized_narrative",
        "relationship": ["manufacturing_lot", "manufacturing_note"],
        "selection_reason": "Authorized source narrative retained as evidence, never interpreted as an instruction.",
    },
}

CORE_FACT_TABLES = tuple(
    sorted(
        {
            table
            for _, table in EVIDENCE_METADATA.values()
        }
        | {"parts", "equipment", "suppliers", "decision_profiles"}
    )
)


@lru_cache(maxsize=1)
def runtime_dataset() -> dict[str, list[dict[str, Any]]]:
    runtime, _ = build_dataset()
    return runtime


def authorized(row: dict[str, Any]) -> bool:
    return row.get("tenant_id") == PRIMARY_TENANT and set(row.get("required_scopes", [])) <= AUTHORIZED_SCOPES


def rows(table: str, **matches: Any) -> list[dict[str, Any]]:
    return [
        row
        for row in runtime_dataset()[table]
        if authorized(row) and all(row.get(key) == value for key, value in matches.items())
    ]


def _source_path(table: str, source_record_id: str) -> list[str]:
    return [f"source_table:{table}", f"source_record:{source_record_id}"]


def _context_path(evidence_class: str, row: dict[str, Any]) -> list[str]:
    semantic = CONTEXT_REQUIREMENTS[evidence_class]["relationship"]
    return [*semantic, f"source_record:{row['source_record_id']}"]


def evidence_summary(
    evidence_class: str,
    row: dict[str, Any],
    *,
    relationship_path: list[str],
    selection_reason: str,
) -> EvidenceSummary:
    source_domain, source_table = EVIDENCE_METADATA[evidence_class]
    return EvidenceSummary(
        evidence_class=evidence_class,
        source_domain=source_domain,
        source_table=source_table,
        source_system=row["source_system"],
        source_record_id=row["source_record_id"],
        title=EVIDENCE_TITLES[evidence_class],
        authority=row["authority"],
        observed_at=row["observed_at"],
        relationship_path=relationship_path,
        selection_reason=selection_reason,
    )


@dataclass(frozen=True)
class AccessResult:
    detail: dict[str, Any]
    evidence: list[EvidenceSummary]
    tool_counts: list[tuple[str, int]]
    access_contract: str
    projection_metadata: dict[str, Any] | None = None


def _related_source_rows(lot: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    """Resolve case facts through source-specific keys.

    This helper expresses the immutable evidence universe only. Provider classes
    decide how it is accessed and represented; neither comparison arm receives
    the other arm's access contract.
    """

    lot_id = lot["lot_id"]
    deviations = [
        row
        for row in rows("deviations")
        if row.get("lot_id") == lot_id
        or row.get("part_id") == lot["part_id"]
        or row.get("supplier_id") == lot["supplier_id"]
        or row.get("equipment_id") == lot["inspection_equipment_id"]
    ]
    notes = [
        row
        for row in rows("manufacturing_notes")
        if row.get("lot_id") == lot_id
        or row.get("part_id") == lot["part_id"]
        or row.get("equipment_id") == lot["inspection_equipment_id"]
    ]
    return {
        "inspections": rows("inspections", lot_id=lot_id),
        "certificates": rows("certificates_of_analysis", lot_id=lot_id),
        "calibrations": rows("calibration_records", equipment_id=lot["inspection_equipment_id"]),
        "revisions": rows("engineering_revisions", part_id=lot["part_id"]),
        "supplier_events": rows(
            "supplier_quality_events",
            supplier_id=lot["supplier_id"],
            part_id=lot["part_id"],
        ),
        "deviations": deviations,
        "notes": notes,
    }


class FragmentedSourceToolPlane:
    """Direct Review access to separate, bounded source-domain tools."""

    access_contract = "FRAGMENTED_SOURCE_TOOLS"

    def collect_case(self, lot_id: str) -> AccessResult:
        lots = rows("manufacturing_lots", lot_id=lot_id)
        if len(lots) != 1:
            raise KeyError(lot_id)
        lot = lots[0]
        related = _related_source_rows(lot)

        selected: list[tuple[str, dict[str, Any]]] = [("lot_record", lot)]
        selected.extend(("final_inspection", row) for row in related["inspections"])
        selected.extend(("certificate_of_analysis", row) for row in related["certificates"])
        selected.extend(("equipment_calibration", row) for row in related["calibrations"])
        selected.extend(("released_revision_alignment", row) for row in related["revisions"])
        selected.extend(("supplier_part_family_history", row) for row in related["supplier_events"])
        selected.extend(
            ("open_deviation_check", row)
            for row in related["deviations"]
            if row["status"] == "OPEN"
        )
        selected.extend(("authorized_narrative_conflict_check", row) for row in related["notes"])

        evidence = [
            evidence_summary(
                evidence_class,
                row,
                relationship_path=_source_path(EVIDENCE_METADATA[evidence_class][1], row["source_record_id"]),
                selection_reason="Returned by a bounded source-domain tool for direct agent reconciliation.",
            )
            for evidence_class, row in selected
        ]
        evidence.sort(key=lambda item: (item.evidence_class, item.source_record_id))

        open_deviations = [row for row in related["deviations"] if row["status"] == "OPEN"]
        tool_counts = [
            ("get_decision_profile", 1),
            ("get_lot_record", 1 + len(related["inspections"]) + len(related["certificates"])),
            ("get_supplier_quality_history", len(related["supplier_events"])),
            ("get_equipment_calibration", len(related["calibrations"])),
            ("get_released_part_revision", len(related["revisions"])),
            ("get_open_deviations", len(open_deviations)),
            ("search_manufacturing_notes", len(related["notes"])),
        ]
        return AccessResult(
            detail={"lot": lot, **related},
            evidence=evidence,
            tool_counts=tool_counts,
            access_contract=self.access_contract,
        )


class ManufacturingContextCoreProvider:
    """Compiler-only projection from the persistent shared context representation.

    The local deterministic preview uses indexes over the immutable generated
    snapshot. The deployed Supabase contract exposes the same separation through
    get_context_core_manifest and get_decision_profile_requirements plus the
    governed normalized relationship tables/RPCs.
    """

    access_contract = "CONTEXT_CORE_QUERY"

    def compile_case(self, lot_id: str, decision_profile_id: str) -> AccessResult:
        profiles = rows("decision_profiles", profile_id=decision_profile_id)
        if len(profiles) != 1:
            raise KeyError(decision_profile_id)
        profile = profiles[0]
        lots = rows("manufacturing_lots", lot_id=lot_id)
        if len(lots) != 1:
            raise KeyError(lot_id)
        lot = lots[0]

        # The compiler traverses governed semantic links required by the profile.
        # It does not expose source-domain operations to the assisted reviewer.
        related = _related_source_rows(lot)
        selected: list[tuple[str, dict[str, Any]]] = [("lot_record", lot)]
        selected.extend(("final_inspection", row) for row in related["inspections"])
        selected.extend(("certificate_of_analysis", row) for row in related["certificates"])
        selected.extend(("equipment_calibration", row) for row in related["calibrations"])
        selected.extend(("released_revision_alignment", row) for row in related["revisions"])
        selected.extend(("supplier_part_family_history", row) for row in related["supplier_events"])
        selected.extend(
            ("open_deviation_check", row)
            for row in related["deviations"]
            if row["status"] == "OPEN"
        )
        selected.extend(("authorized_narrative_conflict_check", row) for row in related["notes"])

        evidence = [
            evidence_summary(
                evidence_class,
                row,
                relationship_path=_context_path(evidence_class, row),
                selection_reason=CONTEXT_REQUIREMENTS[evidence_class]["selection_reason"],
            )
            for evidence_class, row in selected
        ]
        evidence.sort(key=lambda item: (item.evidence_class, item.source_record_id))

        core_record_count = sum(
            len([row for row in runtime_dataset().get(table, []) if authorized(row)])
            for table in CORE_FACT_TABLES
        )
        requirement_keys = sorted(
            {
                CONTEXT_REQUIREMENTS[item.evidence_class]["requirement_key"]
                for item in evidence
            }
        )
        tool_counts = [
            ("get_context_core_manifest", len(CORE_FACT_TABLES)),
            ("get_decision_profile_requirements", len(CONTEXT_REQUIREMENTS)),
            ("query_context_projection", len(evidence)),
        ]
        return AccessResult(
            detail={"lot": lot, **related},
            evidence=evidence,
            tool_counts=tool_counts,
            access_contract=self.access_contract,
            projection_metadata={
                "context_core_id": CONTEXT_CORE_ID,
                "context_core_version": CONTEXT_CORE_VERSION,
                "persistence_model": "POSTGRES_CANONICAL_CONTEXT",
                "decision_profile_id": profile["profile_id"],
                "decision_profile_version": profile["profile_version"],
                "projection_strategy": PROJECTION_STRATEGY,
                "core_snapshot_record_count": core_record_count,
                "selected_evidence_count": len(evidence),
                "excluded_evidence_count": max(core_record_count - len(evidence), 0),
                "satisfied_requirement_keys": requirement_keys,
                "relationship_paths": [item.relationship_path for item in evidence],
            },
        )
