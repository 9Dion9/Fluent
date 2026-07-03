from fastapi import APIRouter, Response

from app import ollama_client

router = APIRouter()


@router.get("/healthz")
async def healthz(response: Response):
    ollama_ok = await ollama_client.is_healthy()
    if not ollama_ok:
        # Non-2xx so the Worker's gateway health check (CLAUDE.md §2) treats
        # "gateway up but Ollama unreachable" the same as "gateway down".
        response.status_code = 503
    return {"status": "ok" if ollama_ok else "degraded", "ollama": ollama_ok}
