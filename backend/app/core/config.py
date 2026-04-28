from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ── PostgreSQL ──────────────────────────────────────────────────
    DB_HOST:     str = "localhost"
    DB_PORT:     int = 5432
    DB_NAME:     str
    DB_USER:     str
    DB_PASSWORD: str

    # ── API ─────────────────────────────────────────────────────────
    # URL base pública de la API (sin /api al final)
    API_BASE_URL: str = "http://localhost:8000"
    API_PORT:     int = 8000

    # ── JWT ─────────────────────────────────────────────────────────
    SECRET_KEY:                  str
    ALGORITHM:                   str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS:   int = 7

    # ── Servicios de IA ─────────────────────────────────────────────
    GEMINI_API_KEY:     str = ""
    OPENROUTER_API_KEY: str = ""

    class Config:
        env_file = ".env"

settings = Settings()