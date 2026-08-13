from __future__ import annotations

import os
from pathlib import Path
import secrets

import httpx
from fastapi import FastAPI, Header, HTTPException, Response
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .comparison_models import ComparisonCase, ComparisonRequest, ComparisonResult, EvaluationSummary
from .comparison_service import (
    comparison_cases,
    evaluation_summary,
    get_comparison,
    run_comparison,
)
from .data_store import decision_profile, expected_dispositions, get_lot, list_lots, load_dataset
from .engine import compile_decision
from .models import DecisionPacket, DecisionRequest, EvaluationReport, EvaluationRow, RetrievalMode
from .settings import get_settings
from .supabase_evaluator import SupabaseEvaluatorStore

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"

app = FastAPI(
    title="HexaContext MVP",
    version="0.2.0",
    description="Three-agent material-deviation decision-readiness comparison using synthetic manufacturing evidence.",
)


@app.get("/api/health")
def health() -> dict:
    dataset = load_dataset()
    settings = get_settings()
    return {
        "status": "ok",
        "dataset_id": dataset["dataset_metadata"]["dataset_id"],
        "synthetic": dataset["dataset_metadata"]["synthetic"],
        "case_count": len(dataset["lots"]),
        "foundry": settings.foundry_public_status(),
        "supabase": settings.supabase_public_status(),
        "comparison": {
            "available": True,
            "workflow_id": "synthetic_material_deviation_readiness_v1",
            "target_foundry_agent_count": 3,
            "execution_mode": "SIMULATED_LOCAL",
            "foundry_live": False,
            "note": (
                "Local deterministic preview; the three Foundry agents and the remote Supabase Data API "
                "are not invoked on this computer."
            ),
        },
        "providers": {
            "mock": {"configured": True, "live_tested": True},
            "azure_foundry": {
                "configured": bool(os.getenv("AZURE_FOUNDRY_RESPONSES_URL"))
                and bool(os.getenv("AZURE_FOUNDRY_API_KEY") or os.getenv("AZURE_FOUNDRY_BEARER_TOKEN")),
                "live_tested": False,
            },
            "aws_bedrock": {
                "configured": bool(os.getenv("AWS_BEDROCK_MODEL_ID")),
                "live_tested": False,
            },
        },
    }


@app.get("/api/comparison-cases", response_model=list[ComparisonCase])
def get_comparison_cases() -> list[ComparisonCase]:
    """Neutral benchmark subjects; answer-key labels remain evaluator-only."""

    return comparison_cases()


@app.post("/api/comparisons", response_model=ComparisonResult)
def create_comparison(request: ComparisonRequest) -> ComparisonResult:
    try:
        return run_comparison(request)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown benchmark lot: {request.lot_id}") from exc


@app.get("/api/comparisons/{comparison_run_id}", response_model=ComparisonResult)
def comparison_detail(comparison_run_id: str) -> ComparisonResult:
    try:
        return get_comparison(comparison_run_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Unknown comparison run") from exc


@app.get("/api/evaluations/summary", response_model=EvaluationSummary)
def comparison_evaluation_summary() -> EvaluationSummary:
    return evaluation_summary()


@app.get("/api/evaluator/cases/{lot_id}")
async def private_case_evaluation(
    lot_id: str,
    response: Response,
    x_evaluator_token: str | None = Header(default=None, alias="X-Evaluator-Token"),
) -> dict:
    """Operator-only answer key for post-run scoring and review.

    This route is never included in an agent tool definition. It is disabled
    until a separate operator token is configured and uses the server-only
    Supabase secret solely through the private evaluator store.
    """

    settings = get_settings()
    if not settings.evaluator_ui_token:
        raise HTTPException(status_code=503, detail="Private evaluator UI access is disabled")
    if not x_evaluator_token or not secrets.compare_digest(
        x_evaluator_token, settings.evaluator_ui_token
    ):
        raise HTTPException(status_code=401, detail="Evaluator authorization required")
    response.headers["Cache-Control"] = "no-store, private"
    try:
        async with SupabaseEvaluatorStore(settings) as evaluator:
            return await evaluator.get_case(lot_id, settings.supabase_snapshot_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Unknown evaluation case") from exc
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Private evaluator source unavailable") from exc


@app.get("/api/profile")
def profile() -> dict:
    return decision_profile()


@app.get("/api/lots")
def lots() -> list[dict]:
    return [item.model_dump(mode="json") for item in list_lots()]


@app.get("/api/lots/{lot_id}")
def lot_detail(lot_id: str) -> dict:
    try:
        source = get_lot(lot_id)
        # The demo detail view receives only the same default quality/general
        # scopes used by the compiler. Restricted distractors stay server-side.
        visible = dict(source)
        visible["evidence"] = [
            item for item in source["evidence"] if item["access_scope"] in {"quality", "general"}
        ]
        visible["excluded_restricted_source_count"] = len(source["evidence"]) - len(visible["evidence"])
        return visible
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown lot: {lot_id}") from exc


@app.post("/api/compile", response_model=DecisionPacket)
async def compile_packet(request: DecisionRequest) -> DecisionPacket:
    try:
        return await compile_decision(request)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"Unknown lot: {request.lot_id}") from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Provider invocation failed: {type(exc).__name__}") from exc


@app.get("/api/evaluation", response_model=EvaluationReport)
async def evaluation() -> EvaluationReport:
    dataset = load_dataset()
    answer_keys = expected_dispositions()
    rows: list[EvaluationRow] = []
    for mode in RetrievalMode:
        correct = 0
        critical_false_passes = 0
        over_escalations = 0
        for lot in dataset["lots"]:
            packet = await compile_decision(
                DecisionRequest(lot_id=lot["lot_id"], retrieval_mode=mode, provider="mock")
            )
            predicted = packet.disposition.value
            expected = answer_keys[lot["lot_id"]]
            correct += int(predicted == expected)
            critical_false_passes += int(predicted == "PASS" and expected != "PASS")
            over_escalations += int(predicted == "ESCALATE" and expected == "PASS")
        total = len(dataset["lots"])
        rows.append(
            EvaluationRow(
                mode=mode,
                correct=correct,
                total=total,
                accuracy=round(correct / total, 4),
                critical_false_passes=critical_false_passes,
                over_escalations=over_escalations,
            )
        )
    return EvaluationReport(
        dataset_id=dataset["dataset_metadata"]["dataset_id"],
        rows=rows,
        note="Metrics are calculated live from designed synthetic fixtures; they are not production performance claims.",
    )


@app.get("/")
def index() -> FileResponse:
    return FileResponse(FRONTEND / "index.html")


app.mount("/static", StaticFiles(directory=FRONTEND), name="static")
