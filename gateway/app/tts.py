import asyncio
import tempfile
from pathlib import Path

from app.config import settings


class TTSError(Exception):
    pass


class UnknownVoiceError(TTSError):
    pass


def voice_model_path(lang: str) -> Path:
    voice_name = settings.voice_by_lang.get(lang)
    if voice_name is None:
        raise UnknownVoiceError(f"no Piper voice configured for lang={lang!r}")
    path = settings.voices_dir / f"{voice_name}.onnx"
    if not path.exists():
        raise UnknownVoiceError(f"voice model missing on disk: {path}")
    return path


async def synthesize_m4a(text: str, lang: str) -> bytes:
    """Piper (WAV) -> ffmpeg (AAC .m4a 64kbps mono). Returns the .m4a bytes."""
    model_path = voice_model_path(lang)

    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / "out.wav"
        m4a_path = Path(tmp) / "out.m4a"

        piper = await asyncio.create_subprocess_exec(
            str(settings.piper_bin),
            "--model",
            str(model_path),
            "--output_file",
            str(wav_path),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, piper_stderr = await piper.communicate(text.encode("utf-8"))
        if piper.returncode != 0:
            raise TTSError(f"piper failed ({piper.returncode}): {piper_stderr.decode(errors='replace')}")

        ffmpeg = await asyncio.create_subprocess_exec(
            settings.ffmpeg_bin,
            "-y",
            "-i",
            str(wav_path),
            "-c:a",
            "aac",
            "-b:a",
            "64k",
            "-ac",
            "1",
            str(m4a_path),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, ffmpeg_stderr = await ffmpeg.communicate()
        if ffmpeg.returncode != 0:
            raise TTSError(f"ffmpeg failed ({ffmpeg.returncode}): {ffmpeg_stderr.decode(errors='replace')}")

        return m4a_path.read_bytes()
