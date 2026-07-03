from app import ollama_client


def test_healthz_ok_when_ollama_reachable(client, monkeypatch):
    async def fake_healthy():
        return True

    monkeypatch.setattr(ollama_client, "is_healthy", fake_healthy)
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.json() == {"status": "ok", "ollama": True}


def test_healthz_503_when_ollama_unreachable(client, monkeypatch):
    async def fake_unhealthy():
        return False

    monkeypatch.setattr(ollama_client, "is_healthy", fake_unhealthy)
    res = client.get("/healthz")
    assert res.status_code == 503
    assert res.json() == {"status": "degraded", "ollama": False}


def test_healthz_requires_no_secret(client, monkeypatch):
    async def fake_healthy():
        return True

    monkeypatch.setattr(ollama_client, "is_healthy", fake_healthy)
    # No X-Gateway-Secret header at all — /healthz must stay open.
    res = client.get("/healthz")
    assert res.status_code == 200
