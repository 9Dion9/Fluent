from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

GATEWAY_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    gateway_shared_secret: str = "dev-secret-change-me"
    ollama_host: str = "http://localhost:11434"
    chat_model: str = "qwen3:14b"
    chat_timeout_s: float = 25.0

    piper_bin: Path = GATEWAY_ROOT / "bin" / "piper" / "piper"
    voices_dir: Path = GATEWAY_ROOT / "voices"
    ffmpeg_bin: str = "ffmpeg"
    tts_max_chars: int = 400

    # lang -> piper voice basename (without .onnx)
    voice_by_lang: dict[str, str] = {
        "de": "de_DE-thorsten-high",
        "en": "en_US-lessac-high",
    }


settings = Settings()
