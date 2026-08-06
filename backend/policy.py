from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .models import Disposition, EvidenceItem, PolicyCheck


@dataclass(frozen=True)
class PolicyResult:
    disposition: Disposition
    checks: list[PolicyCheck]
    missing_information: list[str]
    conflicts: list[str]


def _signals(evidence: list[EvidenceItem]) -> tuple[dict[str, Any], dict[str, list[str]]]:
    values: dict[str, Any] = {}
    sources: dict[str, list[str]] = {}
    for item in evidence:
        for key, value in item.signals.items():
            if key in values and values[key] != value:
                values[f"{key}__conflict"] = True
            values[key] = value
            sources.setdefault(key, []).append(item.evidence_id)
    return values, sources


def _check(
    check_id: str,
    label: str,
    status: str,
    severity: str,
    reason: str,
    evidence_ids: list[str] | None = None,
) -> PolicyCheck:
    return PolicyCheck(
        check_id=check_id,
        label=label,
        status=status,
        severity=severity,
        reason=reason,
        evidence_ids=evidence_ids or [],
    )


def evaluate_policy(evidence: list[EvidenceItem]) -> PolicyResult:
    values, sources = _signals(evidence)
    checks: list[PolicyCheck] = []
    missing: list[str] = []
    conflicts: list[str] = []

    if "inspection_passed" not in values or "critical_defect_count" not in values:
        checks.append(_check("inspection", "Inspection acceptance", "unknown", "critical", "Required final-inspection evidence is missing."))
        missing.append("Final inspection result and critical-defect count")
    elif not values["inspection_passed"] or values["critical_defect_count"] > 0:
        checks.append(_check("inspection", "Inspection acceptance", "fail", "critical", f"Inspection passed={values['inspection_passed']}; critical defects={values['critical_defect_count']}.", sources.get("inspection_passed", []) + sources.get("critical_defect_count", [])))
    else:
        checks.append(_check("inspection", "Inspection acceptance", "pass", "info", "Final inspection passed with zero critical defects.", sources.get("inspection_passed", [])))

    if "coa_verified" not in values:
        checks.append(_check("coa", "Certificate verification", "unknown", "critical", "Certificate verification evidence is missing."))
        missing.append("Verified certificate of analysis")
    elif not values["coa_verified"]:
        checks.append(_check("coa", "Certificate verification", "fail", "critical", "The certificate of analysis could not be verified for this lot.", sources.get("coa_verified", [])))
    else:
        checks.append(_check("coa", "Certificate verification", "pass", "info", "The certificate is verified and linked to the lot.", sources.get("coa_verified", [])))

    if "calibration_valid" not in values:
        checks.append(_check("calibration", "Equipment calibration", "unknown", "critical", "Connected calibration evidence is missing."))
        missing.append("Calibration state for inspection equipment")
    elif not values["calibration_valid"]:
        checks.append(_check("calibration", "Equipment calibration", "fail", "critical", "Inspection equipment calibration is not valid.", sources.get("calibration_valid", [])))
    else:
        checks.append(_check("calibration", "Equipment calibration", "pass", "info", "Inspection equipment calibration is current.", sources.get("calibration_valid", [])))

    if "supplier_consecutive_failures" not in values:
        checks.append(_check("supplier_history", "Supplier failure history", "unknown", "critical", "Connected supplier/part-family quality history is missing."))
        missing.append("Recent consecutive supplier outcomes for the same part family")
    elif int(values["supplier_consecutive_failures"]) >= 3:
        checks.append(_check("supplier_history", "Supplier failure history", "fail", "critical", f"The connected supplier has {values['supplier_consecutive_failures']} consecutive failures for this part family.", sources.get("supplier_consecutive_failures", [])))
    else:
        checks.append(_check("supplier_history", "Supplier failure history", "pass", "info", f"Connected consecutive failures: {values['supplier_consecutive_failures']}.", sources.get("supplier_consecutive_failures", [])))

    if "revision_match" not in values:
        checks.append(_check("revision", "Released revision alignment", "unknown", "critical", "Released-revision comparison is missing."))
        missing.append("Observed versus released part revision")
    elif not values["revision_match"]:
        checks.append(_check("revision", "Released revision alignment", "fail", "critical", "The observed part revision does not match the released revision.", sources.get("revision_match", [])))
    else:
        checks.append(_check("revision", "Released revision alignment", "pass", "info", "The observed part revision matches the released revision.", sources.get("revision_match", [])))

    if "deviation_open" not in values or "relationship_evidence_stale" not in values:
        checks.append(_check("relationship_assurance", "Relationship evidence assurance", "unknown", "warning", "Deviation or evidence-freshness context is missing."))
        missing.append("Open-deviation and relationship-freshness state")
    elif values["deviation_open"]:
        checks.append(_check("relationship_assurance", "Relationship evidence assurance", "fail", "warning", "An open deviation is connected to the lot context.", sources.get("deviation_open", [])))
    elif values["relationship_evidence_stale"]:
        checks.append(_check("relationship_assurance", "Relationship evidence assurance", "fail", "warning", "Connected supplier evidence is outside the profile freshness window.", sources.get("relationship_evidence_stale", [])))
    else:
        checks.append(_check("relationship_assurance", "Relationship evidence assurance", "pass", "info", "No open deviation or stale relationship evidence was found.", sources.get("deviation_open", [])))

    if values.get("narrative_conflict") or values.get("narrative_conflict__conflict"):
        conflicts.append("Narrative evidence conflicts with the structured inspection record")
        checks.append(_check("narrative_conflict", "Narrative conflict check", "fail", "warning", conflicts[-1], sources.get("narrative_conflict", [])))
    else:
        checks.append(_check("narrative_conflict", "Narrative conflict check", "pass", "info", "No authorized narrative conflict was found in the retrieved scope."))

    critical_fail = any(check.status == "fail" and check.severity == "critical" for check in checks)
    unresolved = any(check.status == "unknown" for check in checks)
    warning_fail = any(check.status == "fail" and check.severity == "warning" for check in checks)
    if critical_fail:
        disposition = Disposition.HOLD
    elif unresolved or warning_fail:
        disposition = Disposition.ESCALATE
    else:
        disposition = Disposition.PASS

    return PolicyResult(disposition, checks, missing, conflicts)
