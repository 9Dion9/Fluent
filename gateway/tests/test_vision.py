from app import ollama_client
from app.ollama_client import OllamaError
from tests.conftest import AUTH_HEADERS


def test_vision_rejects_missing_secret(client):
    res = client.post("/v1/vision", json={"image_b64": "abc", "target_lang": "de"})
    assert res.status_code == 401


def test_vision_happy_path(client, monkeypatch):
    captured = {}

    async def fake_chat(messages, **kwargs):
        captured["messages"] = messages
        captured["kwargs"] = kwargs
        return '{"word": "die Tasse", "translation": "cup", "pos": "noun", "gender": "die", "example": "Die Tasse ist leer."}'

    monkeypatch.setattr(ollama_client, "chat", fake_chat)

    res = client.post(
        "/v1/vision",
        json={"image_b64": "aGVsbG8=", "target_lang": "de"},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 200
    body = res.json()
    assert body["word"] == "die Tasse"
    assert body["translation"] == "cup"
    assert body["gender"] == "die"
    # multimodal payload must actually carry the image to Ollama
    assert captured["messages"][0]["images"] == ["aGVsbG8="]
    assert captured["kwargs"]["keep_alive"] == 0


def test_vision_malformed_json_maps_to_502(client, monkeypatch):
    async def fake_chat(messages, **kwargs):
        return '{"not_word": "oops"}'

    monkeypatch.setattr(ollama_client, "chat", fake_chat)

    res = client.post(
        "/v1/vision",
        json={"image_b64": "aGVsbG8=", "target_lang": "de"},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 502


def test_vision_upstream_error_maps_to_502(client, monkeypatch):
    async def failing_chat(messages, **kwargs):
        raise OllamaError("boom")

    monkeypatch.setattr(ollama_client, "chat", failing_chat)

    res = client.post(
        "/v1/vision",
        json={"image_b64": "aGVsbG8=", "target_lang": "de"},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 502
