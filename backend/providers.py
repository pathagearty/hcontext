from __future__ import annotations

import asyncio
import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

import boto3
import httpx


@dataclass(frozen=True)
class ExplanationRequest:
    disposition: str
    lot_id: str
    checks: list[dict]
    missing_information: list[str]
    conflicts: list[str]
    evidence_summaries: list[str]


class ExplanationProvider(ABC):
    name: str

    @abstractmethod
    async def explain(self, request: ExplanationRequest) -> str:
        """Explain a deterministic packet; never choose the disposition."""
        raise NotImplementedError


class MockExplanationProvider(ExplanationProvider):
    name = "mock"

    async def explain(self, request: ExplanationRequest) -> str:
        failures = [c["label"] for c in request.checks if c["status"] == "fail"]
        unknowns = [c["label"] for c in request.checks if c["status"] == "unknown"]
        if request.disposition == "PASS":
            return (
                f"Lot {request.lot_id} has the required authorized evidence and no active "
                "policy blockers in the retrieved context. It is ready for an authorized "
                "quality reviewer to consider release."
            )
        if request.disposition == "HOLD":
            reason = ", ".join(failures) or "a mandatory policy gate"
            return (
                f"Lot {request.lot_id} is on hold because the governed checks identified: "
                f"{reason}. The hold remains until an authorized reviewer resolves the evidence."
            )
        reason = ", ".join(request.conflicts + request.missing_information + unknowns)
        return (
            f"Lot {request.lot_id} requires escalation because the context is incomplete or "
            f"conflicting: {reason or 'manual review is required'}. No release recommendation "
            "should be inferred from missing information."
        )


class AzureFoundryExplanationProvider(ExplanationProvider):
    """Thin adapter for an approved Azure Foundry Responses-compatible endpoint.

    The endpoint is a full URL because project/deployment paths vary. The model
    explains an already-determined result and is not allowed to change it.
    """

    name = "azure_foundry"

    def __init__(self) -> None:
        self.url = os.getenv("AZURE_FOUNDRY_RESPONSES_URL", "").strip()
        self.model = os.getenv("AZURE_FOUNDRY_MODEL", "").strip()
        self.api_key = os.getenv("AZURE_FOUNDRY_API_KEY", "").strip()
        self.bearer_token = os.getenv("AZURE_FOUNDRY_BEARER_TOKEN", "").strip()
        if not self.url:
            raise RuntimeError("AZURE_FOUNDRY_RESPONSES_URL is not configured")
        if not (self.api_key or self.bearer_token):
            raise RuntimeError("Configure an approved Foundry API key or bearer token")

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["api-key"] = self.api_key
        else:
            headers["Authorization"] = f"Bearer {self.bearer_token}"
        return headers

    @staticmethod
    def _prompt(request: ExplanationRequest) -> str:
        return (
            "You are explaining a governed manufacturing context packet. "
            "Do not change the disposition, invent evidence, or recommend autonomous action.\n"
            f"Lot: {request.lot_id}\nFixed disposition: {request.disposition}\n"
            f"Checks: {request.checks}\nMissing: {request.missing_information}\n"
            f"Conflicts: {request.conflicts}\nEvidence summaries: {request.evidence_summaries}\n"
            "Return two concise sentences for a quality reviewer."
        )

    @staticmethod
    def _extract_text(payload: dict[str, Any]) -> str:
        if isinstance(payload.get("output_text"), str):
            return payload["output_text"].strip()
        chunks: list[str] = []
        for item in payload.get("output", []) or []:
            for content in item.get("content", []) or []:
                text = content.get("text")
                if isinstance(text, str):
                    chunks.append(text)
        if chunks:
            return " ".join(chunks).strip()
        raise RuntimeError("Foundry response did not contain extractable output text")

    async def explain(self, request: ExplanationRequest) -> str:
        body: dict[str, Any] = {"input": self._prompt(request), "temperature": 0}
        if self.model:
            body["model"] = self.model
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(self.url, headers=self._headers(), json=body)
            response.raise_for_status()
            return self._extract_text(response.json())


class BedrockExplanationProvider(ExplanationProvider):
    name = "aws_bedrock"

    def __init__(self) -> None:
        self.region = os.getenv("AWS_REGION", "us-east-1")
        self.profile = os.getenv("AWS_PROFILE", "").strip()
        self.model_id = os.getenv("AWS_BEDROCK_MODEL_ID", "").strip()
        if not self.model_id:
            raise RuntimeError("AWS_BEDROCK_MODEL_ID is not configured")

    def _client(self):
        session = boto3.Session(profile_name=self.profile or None, region_name=self.region)
        return session.client("bedrock-runtime")

    @staticmethod
    def _prompt(request: ExplanationRequest) -> str:
        return (
            "Explain this governed manufacturing packet in two concise sentences. "
            "The disposition is fixed; do not change it or invent evidence.\n"
            f"Lot={request.lot_id}\nDisposition={request.disposition}\n"
            f"Checks={request.checks}\nMissing={request.missing_information}\n"
            f"Conflicts={request.conflicts}\nEvidence={request.evidence_summaries}"
        )

    def _invoke(self, request: ExplanationRequest) -> str:
        response = self._client().converse(
            modelId=self.model_id,
            system=[{"text": "You explain governed evidence packets for human reviewers."}],
            messages=[{"role": "user", "content": [{"text": self._prompt(request)}]}],
            inferenceConfig={"temperature": 0, "maxTokens": 220},
        )
        blocks = response["output"]["message"]["content"]
        text = " ".join(block.get("text", "") for block in blocks).strip()
        if not text:
            raise RuntimeError("Bedrock response did not contain text")
        return text

    async def explain(self, request: ExplanationRequest) -> str:
        return await asyncio.to_thread(self._invoke, request)


def get_provider(name: str) -> ExplanationProvider:
    if name == "mock":
        return MockExplanationProvider()
    if name == "azure_foundry":
        return AzureFoundryExplanationProvider()
    if name == "aws_bedrock":
        return BedrockExplanationProvider()
    raise ValueError(f"Unsupported provider: {name}")
