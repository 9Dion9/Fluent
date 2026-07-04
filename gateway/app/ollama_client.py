from typing import Literal

import httpx

from app.config import settings

Role = Literal["system", "user", "assistant"]


class OllamaError(Exception):
    pass


async def chat(
    messages: list[dict],
    *,
    model: str = settings.chat_model,
    json_format: bool = True,
    think: bool = False,
    keep_alive: str | int | None = None,
    timeout_s: float | None = None,
) -> str:
    """Non-streaming chat completion. Returns the assistant message content."""
    payload: dict = {
        "model": model,
        "messages": messages,
        "stream": False,
        "think": think,
    }
    if json_format:
        payload["format"] = "json"
    if keep_alive is not None:
        payload["keep_alive"] = keep_alive

    try:
        async with httpx.AsyncClient(timeout=timeout_s or settings.chat_timeout_s) as client:
            res = await client.post(f"{settings.ollama_host}/api/chat", json=payload)
            res.raise_for_status()
    except httpx.HTTPError as exc:
        raise OllamaError(str(exc)) from exc

    data = res.json()
    content = data.get("message", {}).get("content")
    if not content:
        raise OllamaError(f"Ollama returned no content: {data}")
    return content


async def is_healthy() -> bool:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.get(f"{settings.ollama_host}/api/tags")
            return res.status_code == 200
    except httpx.HTTPError:
        return False
