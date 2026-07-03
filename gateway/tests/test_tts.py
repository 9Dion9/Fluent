from app import tts
from app.tts import TTSError, UnknownVoiceError
from tests.conftest import AUTH_HEADERS


def test_tts_rejects_missing_secret(client):
    res = client.post("/v1/tts", json={"text": "hallo", "lang": "de"})
    assert res.status_code == 401


def test_tts_happy_path(client, monkeypatch):
    async def fake_synth(text, lang):
        assert lang == "de"
        return b"FAKE_M4A_BYTES"

    monkeypatch.setattr(tts, "synthesize_m4a", fake_synth)

    res = client.post("/v1/tts", json={"text": "Hallo!", "lang": "de"}, headers=AUTH_HEADERS)
    assert res.status_code == 200
    assert res.headers["content-type"] == "audio/mp4"
    assert res.content == b"FAKE_M4A_BYTES"


def test_tts_unknown_voice_is_422(client, monkeypatch):
    async def fake_synth(text, lang):
        raise UnknownVoiceError("no voice for fr")

    monkeypatch.setattr(tts, "synthesize_m4a", fake_synth)

    res = client.post("/v1/tts", json={"text": "bonjour", "lang": "fr"}, headers=AUTH_HEADERS)
    assert res.status_code == 422


def test_tts_engine_failure_is_502(client, monkeypatch):
    async def fake_synth(text, lang):
        raise TTSError("piper crashed")

    monkeypatch.setattr(tts, "synthesize_m4a", fake_synth)

    res = client.post("/v1/tts", json={"text": "Hallo", "lang": "de"}, headers=AUTH_HEADERS)
    assert res.status_code == 502


def test_tts_rejects_text_over_400_chars(client):
    res = client.post(
        "/v1/tts",
        json={"text": "a" * 401, "lang": "de"},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 422
