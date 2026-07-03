from app import ollama_client
from app.ollama_client import OllamaError
from tests.conftest import AUTH_HEADERS


def test_chat_rejects_missing_secret(client):
    res = client.post("/v1/chat", json={"messages": [{"role": "user", "content": "hi"}]})
    assert res.status_code == 401


def test_chat_rejects_wrong_secret(client):
    res = client.post(
        "/v1/chat",
        json={"messages": [{"role": "user", "content": "hi"}]},
        headers={"X-Gateway-Secret": "wrong"},
    )
    assert res.status_code == 401


def test_chat_happy_path(client, monkeypatch):
    captured = {}

    async def fake_chat(messages, **kwargs):
        captured["messages"] = messages
        captured["kwargs"] = kwargs
        return '{"reply": "Hallo!"}'

    monkeypatch.setattr(ollama_client, "chat", fake_chat)

    res = client.post(
        "/v1/chat",
        json={"messages": [{"role": "user", "content": "hi"}]},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 200
    body = res.json()
    assert body["text"] == '{"reply": "Hallo!"}'
    assert body["model"] == "qwen3:14b"
    # non-thinking mode is the CLAUDE.md §3 requirement for live chat
    assert captured["kwargs"]["think"] is False
    assert captured["kwargs"]["json_format"] is True


def test_chat_upstream_error_maps_to_502(client, monkeypatch):
    async def failing_chat(messages, **kwargs):
        raise OllamaError("boom")

    monkeypatch.setattr(ollama_client, "chat", failing_chat)

    res = client.post(
        "/v1/chat",
        json={"messages": [{"role": "user", "content": "hi"}]},
        headers=AUTH_HEADERS,
    )
    assert res.status_code == 502
