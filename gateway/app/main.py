from fastapi import FastAPI

from app.routers import chat, health, tts

app = FastAPI(title="fluent-gateway")

app.include_router(health.router)
app.include_router(chat.router)
app.include_router(tts.router)
