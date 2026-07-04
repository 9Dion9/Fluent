import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app import ollama_client
from app.auth import require_gateway_secret
from app.config import settings
from app.ollama_client import OllamaError

router = APIRouter(dependencies=[Depends(require_gateway_secret)])

LANG_NAMES = {"de": "German", "en": "English"}


class VisionRequest(BaseModel):
    image_b64: str = Field(min_length=1)
    target_lang: str = Field(min_length=2, max_length=5)


class VisionResponse(BaseModel):
    word: str
    translation: str
    pos: str | None = None
    gender: str | None = None
    example: str | None = None


@router.post("/v1/vision", response_model=VisionResponse)
async def identify(req: VisionRequest) -> VisionResponse:
    """VLM fallback for the camera lens (CLAUDE.md §9) — only hit when the
    on-device Vision label has no vision_labels mapping. Result is inserted
    by the Worker as source='camera_vlm', verified=0 (not Wiktionary-checked)."""
    lang_name = LANG_NAMES.get(req.target_lang, req.target_lang)
    prompt = (
        f"Identify the single main object in this image. Return ONLY valid JSON: "
        f'{{"word": string, "translation": string, "pos": string, "gender": string|null, "example": string}} '
        f'where "word" is the {lang_name} word for the object (with its article if {lang_name} has grammatical '
        f'gender, e.g. "die Tasse"), "translation" is the English meaning, "pos" is the part of speech '
        f'("noun", "verb", etc), "gender" is "der"/"die"/"das" for German nouns or null for English, '
        f"and \"example\" is one short {lang_name} sentence using the word naturally."
    )
    try:
        raw = await ollama_client.chat(
            [{"role": "user", "content": prompt, "images": [req.image_b64]}],
            model=settings.vision_model,
            json_format=True,
            think=False,
            keep_alive=0,  # VLM is a rare path (CLAUDE.md §3) — don't hold it resident
            timeout_s=settings.vision_timeout_s,
        )
        data = json.loads(raw)
    except (OllamaError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=502, detail=f"vision model error: {exc}") from exc

    if not (isinstance(data.get("word"), str) and isinstance(data.get("translation"), str)):
        raise HTTPException(status_code=502, detail=f"vision model returned malformed JSON: {raw}")

    return VisionResponse(
        word=data["word"],
        translation=data["translation"],
        pos=data.get("pos"),
        gender=data.get("gender"),
        example=data.get("example"),
    )
