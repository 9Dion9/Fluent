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
    # "seen" comes before "word" deliberately — a small local VLM guesses more
    # accurately when it has to describe what's literally visible (shape,
    # color, material) before committing to a word, rather than naming an
    # object cold. Observed live: without this, gemma4:12b misidentified a
    # computer mouse as a water bottle. Still strict JSON, no chain-of-thought
    # prose outside the object.
    prompt = (
        f"Look carefully at the single main object in this image. Return ONLY valid JSON, "
        f'with keys in this order: {{"seen": string, "word": string, "translation": string, '
        f'"pos": string, "gender": string|null, "example": string}}. '
        f'"seen" is one literal sentence in English describing only what is physically visible '
        f"(its shape, color, size, material) — base it strictly on the image, not a guess at what "
        f'it might be. "word" is the {lang_name} word for that object given what "seen" describes '
        f'(with its article if {lang_name} has grammatical gender, e.g. "die Tasse"), "translation" '
        f'is the English meaning, "pos" is the part of speech ("noun", "verb", etc), "gender" is '
        f'"der"/"die"/"das" for German nouns or null for English, and "example" is one short '
        f"{lang_name} sentence using the word naturally."
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
