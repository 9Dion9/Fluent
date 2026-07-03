import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.main import app

AUTH_HEADERS = {"X-Gateway-Secret": settings.gateway_shared_secret}


@pytest.fixture
def client():
    return TestClient(app)
