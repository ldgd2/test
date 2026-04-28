from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# ── Construcción de la URL de conexión PostgreSQL ──────────────────────
DATABASE_URL = (
    f"postgresql+psycopg2://{settings.DB_USER}:{settings.DB_PASSWORD}"
    f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
)

engine = create_engine(
    DATABASE_URL,
    echo=False,           # True para ver SQL en consola (debug)
    pool_pre_ping=True,   # Verifica conexión antes de usarla
    pool_size=10,
    max_overflow=20,
    pool_recycle=300,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependencia para inyectar sesión en los routers
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()