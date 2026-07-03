from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field

from app import tts
from app.auth import require_gateway_secret
from app.config import settings
from app.tts import TTSError, UnknownVoiceError

router = APIRouter(dependencies=[Depends(require_gateway_secret)])


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=settings.tts_max_chars)
    lang: str = Field(min_length=2, max_length=5)


@router.post("/v1/tts")
async def synthesize(req: TTSRequest) -> Response:
    try:
        audio = await tts.synthesize_m4a(req.text, req.lang)
    except UnknownVoiceError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except TTSError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return Response(content=audio, media_type="audio/mp4")
