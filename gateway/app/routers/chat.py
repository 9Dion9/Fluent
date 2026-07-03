from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app import ollama_client
from app.auth import require_gateway_secret
from app.config import settings
from app.ollama_client import OllamaError

router = APIRouter(dependencies=[Depends(require_gateway_secret)])


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1)
    model: str = settings.chat_model
    keep_alive: str | int | None = -1  # resident by default (CLAUDE.md §3 VRAM plan)


class ChatResponse(BaseModel):
    text: str
    model: str


@router.post("/v1/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    try:
        text = await ollama_client.chat(
            [m.model_dump() for m in req.messages],
            model=req.model,
            json_format=True,
            think=False,
            keep_alive=req.keep_alive,
        )
    except OllamaError as exc:
        raise HTTPException(status_code=502, detail=f"upstream model error: {exc}") from exc

    return ChatResponse(text=text, model=req.model)
