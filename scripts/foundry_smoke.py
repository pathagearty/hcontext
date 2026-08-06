from __future__ import annotations

import asyncio
import json

from backend.foundry_client import (
    FoundryClient,
    FoundryError,
    FoundryHTTPError,
    FoundryTransportError,
)
from backend.settings import FoundryConfigurationError, get_settings


async def run() -> int:
    try:
        settings = get_settings()
        settings.require_foundry()
    except FoundryConfigurationError as exc:
        print(json.dumps({"ok": False, "configuration_issues": list(exc.issues)}))
        return 2

    outcomes: list[dict] = []
    async with FoundryClient(settings) as client:
        for agent in ("manufacturing", "hexacontext"):
            try:
                result = await client.create_response(
                    agent,
                    input_value="Connection health check. Reply with exactly CONNECTION_OK.",
                )
                outcomes.append(
                    {
                        "agent": agent,
                        "ok": True,
                        "http_status": result.metadata.http_status,
                        "response_id_returned": bool(result.metadata.response_id),
                        "run_status": result.metadata.response_status,
                        "elapsed_ms": result.metadata.elapsed_ms,
                        "attempts": result.metadata.attempts,
                        "retry_count": len(result.metadata.retries),
                    }
                )
            except FoundryHTTPError as exc:
                outcomes.append(
                    {
                        "agent": agent,
                        "ok": False,
                        "http_status": exc.status_code,
                        "error_code": exc.error_code,
                        "retryable": exc.retryable,
                        "attempts": exc.attempts,
                        "retry_count": len(exc.retries),
                    }
                )
            except FoundryTransportError as exc:
                outcomes.append(
                    {
                        "agent": agent,
                        "ok": False,
                        "error_type": type(exc).__name__,
                        "attempts": exc.attempts,
                        "retry_count": len(exc.retries),
                    }
                )
            except FoundryError as exc:
                outcomes.append(
                    {
                        "agent": agent,
                        "ok": False,
                        "error_type": type(exc).__name__,
                    }
                )

    print(json.dumps({"ok": all(item["ok"] for item in outcomes), "agents": outcomes}))
    return 0 if all(item["ok"] for item in outcomes) else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(run()))
