from __future__ import annotations

import json
from pathlib import Path

OUTPUT = Path(__file__).parent / "generated" / "hexacontext_demo.json"


def evidence(
    evidence_id: str,
    title: str,
    evidence_type: str,
    source_system: str,
    authority: str,
    retrieval_scope: str,
    summary: str,
    signals: dict,
    *,
    access_scope: str = "quality",
    observed_at: str = "2026-08-05T12:00:00Z",
    source_version: str = "v1",
) -> dict:
    return {
        "evidence_id": evidence_id,
        "title": title,
        "evidence_type": evidence_type,
        "source_system": source_system,
        "source_record_id": evidence_id.replace("EV-", "SRC-"),
        "authority": authority,
        "observed_at": observed_at,
        "source_version": source_version,
        "access_scope": access_scope,
        "retrieval_scope": retrieval_scope,
        "summary": summary,
        "signals": signals,
    }


def make_case(
    n: int,
    scenario: str,
    expected: str,
    overrides: dict | None = None,
    omit: set[str] | None = None,
    extra_evidence: list[dict] | None = None,
) -> dict:
    overrides = overrides or {}
    omit = omit or set()
    lot_id = f"HX-LOT-{1000 + n}"
    part_id = f"HX-PART-{(n - 1) % 4 + 1:03d}"
    supplier_id = f"HX-SUP-{(n - 1) % 3 + 1:03d}"
    machine_id = f"HX-EQP-{(n - 1) % 4 + 1:03d}"

    signals = {
        "inspection_passed": True,
        "critical_defect_count": 0,
        "coa_verified": True,
        "calibration_valid": True,
        "supplier_consecutive_failures": 0,
        "revision_match": True,
        "deviation_open": False,
        "relationship_evidence_stale": False,
        **overrides,
    }

    items = {
        "inspection": evidence(
            f"EV-{lot_id}-INSPECTION",
            "Final inspection result",
            "inspection",
            "QMS",
            "approved_quality_record",
            "direct",
            "Inspection measurements and defect disposition for this lot.",
            {
                "inspection_passed": signals["inspection_passed"],
                "critical_defect_count": signals["critical_defect_count"],
            },
        ),
        "coa": evidence(
            f"EV-{lot_id}-COA",
            "Certificate of analysis verification",
            "certificate",
            "Supplier Portal",
            "verified_supplier_record",
            "direct",
            "Certificate identity, lot linkage, and acceptance state.",
            {"coa_verified": signals["coa_verified"]},
        ),
        "calibration": evidence(
            f"EV-{lot_id}-CAL",
            "Inspection equipment calibration",
            "equipment_calibration",
            "eQMS",
            "approved_calibration_record",
            "relationship",
            f"Calibration status for equipment {machine_id} used by the lot inspection.",
            {"calibration_valid": signals["calibration_valid"]},
        ),
        "supplier": evidence(
            f"EV-{lot_id}-SUPPLIER",
            "Connected supplier quality history",
            "supplier_history",
            "Supplier Quality Hub",
            "approved_supplier_quality_record",
            "relationship",
            "Recent consecutive outcomes for the same supplier and part family.",
            {
                "supplier_consecutive_failures": signals["supplier_consecutive_failures"],
                "relationship_evidence_stale": signals["relationship_evidence_stale"],
            },
        ),
        "revision": evidence(
            f"EV-{lot_id}-REV",
            "Part and work-order revision alignment",
            "revision_control",
            "PLM",
            "released_engineering_record",
            "relationship",
            "Observed part revision compared with the currently released revision.",
            {"revision_match": signals["revision_match"]},
            source_version="rev-C",
        ),
        "deviation": evidence(
            f"EV-{lot_id}-DEV",
            "Open deviation relationship",
            "deviation",
            "eQMS",
            "approved_quality_record",
            "relationship",
            "Open deviation or exception linked to the lot, part, supplier, or equipment.",
            {"deviation_open": signals["deviation_open"]},
        ),
    }
    selected = [item for key, item in items.items() if key not in omit]
    selected.extend(extra_evidence or [])

    return {
        "lot_id": lot_id,
        "part_id": part_id,
        "part_revision": "C" if signals["revision_match"] else "B",
        "approved_revision": "C",
        "supplier_id": supplier_id,
        "machine_id": machine_id,
        "material": ["Titanium fastener", "Sterile polymer housing", "Control-board assembly", "Precision valve"][
            (n - 1) % 4
        ],
        "quantity": 250 + n * 25,
        "manufactured_at": f"2026-08-{(n % 4) + 1:02d}T08:00:00Z",
        "scenario": scenario,
        "expected_disposition": expected,
        "evidence": selected,
        "relationships": [
            {"from": lot_id, "type": "produced_by", "to": supplier_id},
            {"from": lot_id, "type": "contains_part", "to": part_id},
            {"from": lot_id, "type": "inspected_with", "to": machine_id},
            {"from": part_id, "type": "governed_by", "to": "HX-POLICY-LOT-001"},
        ],
    }


def build_dataset() -> dict:
    narrative_conflict = evidence(
        "EV-HX-LOT-1009-NOTE",
        "Operator shift note",
        "narrative_note",
        "Manufacturing Log",
        "signed_operator_note",
        "narrative",
        "The narrative reports seal damage that conflicts with the structured inspection result.",
        {"narrative_conflict": True},
        access_scope="general",
    )
    restricted_distractor = evidence(
        "EV-HX-LOT-1012-RESTRICTED",
        "Restricted employment note",
        "restricted_note",
        "HR Case System",
        "non_quality_record",
        "narrative",
        "Irrelevant restricted information that must never influence lot disposition.",
        {"narrative_conflict": True},
        access_scope="restricted_hr",
    )

    cases = [
        make_case(1, "Complete, current, mutually consistent evidence", "PASS"),
        make_case(2, "Three connected supplier failures for the same part family", "HOLD", {"supplier_consecutive_failures": 3}),
        make_case(3, "Critical defect found in direct inspection evidence", "HOLD", {"critical_defect_count": 1}),
        make_case(4, "Inspection equipment calibration expired", "HOLD", {"calibration_valid": False}),
        make_case(5, "Observed part revision does not match released revision", "HOLD", {"revision_match": False}),
        make_case(6, "Certificate of analysis cannot be verified", "HOLD", {"coa_verified": False}),
        make_case(7, "Final inspection failed", "HOLD", {"inspection_passed": False}),
        make_case(8, "Open deviation linked through the context graph", "ESCALATE", {"deviation_open": True}),
        make_case(9, "Narrative evidence conflicts with structured inspection", "ESCALATE", extra_evidence=[narrative_conflict]),
        make_case(10, "Connected supplier evidence is stale", "ESCALATE", {"relationship_evidence_stale": True}),
        make_case(11, "Required supplier history is missing", "ESCALATE", omit={"supplier"}),
        make_case(12, "Authorized evidence passes; restricted distractor must be excluded", "PASS", extra_evidence=[restricted_distractor]),
    ]

    return {
        "dataset_metadata": {
            "dataset_id": "hexacontext-manufacturing-demo-v1",
            "created_for": "Sneha HexaContext MVP",
            "synthetic": True,
            "contains_real_company_or_client_data": False,
            "case_count": len(cases),
            "profile_id": "manufacturing_lot_disposition_v1",
            "description": "Designed synthetic cases for evaluating governed hybrid context retrieval and human-reviewed lot disposition readiness.",
        },
        "decision_profile": {
            "profile_id": "manufacturing_lot_disposition_v1",
            "decision": "Manufacturing lot disposition readiness",
            "required_signals": [
                "inspection_passed",
                "critical_defect_count",
                "coa_verified",
                "calibration_valid",
                "supplier_consecutive_failures",
                "revision_match",
                "deviation_open",
                "relationship_evidence_stale",
            ],
            "rules": [
                "Failed inspection or any critical defect places the lot on HOLD.",
                "Unverified certificate, expired calibration, revision mismatch, or three consecutive connected supplier failures places the lot on HOLD.",
                "Open deviations, stale relationship evidence, conflicting narratives, or missing mandatory evidence require ESCALATION.",
                "Only authorized evidence can enter the packet; a human quality reviewer owns the final disposition.",
            ],
        },
        "lots": cases,
    }


def main() -> None:
    dataset = build_dataset()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(dataset, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(dataset['lots'])} synthetic cases to {OUTPUT}")


if __name__ == "__main__":
    main()
