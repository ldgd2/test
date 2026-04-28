#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   Configurador Interactivo de .env — AutoWorks Bolivia          ║
# ║   Guía paso a paso para configurar todas las variables          ║
# ║   Uso: bash deploy/configure_env.sh                             ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m'
W='\033[1;37m' DIM='\033[2m' BOLD='\033[1m' NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/backend/.env"
ENV_BACKUP="$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"

# ── Helper: leer campo con valor por defecto ──────────────────────────
ask() {
    local prompt="$1"
    local default="${2:-}"
    local secret="${3:-false}"
    local value

    if [ "$secret" = "true" ]; then
        read -rsp "  ${C}${prompt}${NC} ${DIM}[oculto]${NC}: " value
        echo ""
    else
        if [ -n "$default" ]; then
            read -rp "  ${C}${prompt}${NC} ${DIM}[${default}]${NC}: " value
            value="${value:-$default}"
        else
            read -rp "  ${C}${prompt}${NC}: " value
        fi
    fi
    echo "$value"
}

# ── Helper: confirmar ─────────────────────────────────────────────────
confirm() {
    local msg="$1"
    read -rp "  ${Y}${msg} [s/N]${NC}: " c
    [[ "$c" =~ ^[Ss]$ ]]
}

clear
echo -e "${BOLD}${C}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║     ⚙️  Configurador de .env — AutoWorks Bolivia         ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Cargar valores actuales del .env (si existe) ──────────────────────
if [ -f "$ENV_FILE" ]; then
    echo -e "  ${G}✓${NC} Archivo .env encontrado: ${DIM}$ENV_FILE${NC}"
    echo -e "  ${DIM}Cargando valores actuales como predeterminados...${NC}"
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE" 2>/dev/null || true; set +a

    cp "$ENV_FILE" "$ENV_BACKUP"
    echo -e "  ${DIM}Backup guardado en: $ENV_BACKUP${NC}"
else
    echo -e "  ${Y}⚠  .env no encontrado — se creará uno nuevo${NC}"
fi
echo ""

# ══════════════════════════════════════════════════════════════════════
# SECCIÓN 1: PostgreSQL
# ══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  ─── 🐘 Configuración de PostgreSQL ───────────────────────${NC}"
DB_HOST=$(ask "Host de PostgreSQL"         "${DB_HOST:-localhost}")
DB_PORT=$(ask "Puerto de PostgreSQL"       "${DB_PORT:-5432}")
DB_NAME=$(ask "Nombre de la base de datos" "${DB_NAME:-autoworks}")
DB_USER=$(ask "Usuario de PostgreSQL"      "${DB_USER:-autoworks_user}")
DB_PASSWORD=$(ask "Contraseña del usuario" "${DB_PASSWORD:-}" "true")

echo ""

# ══════════════════════════════════════════════════════════════════════
# SECCIÓN 2: API
# ══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  ─── 🌐 Configuración de la API ────────────────────────────${NC}"
API_BASE_URL=$(ask "URL base pública (ej: http://185.214.134.23:8000)" "${API_BASE_URL:-http://185.214.134.23:8000}")
API_PORT=$(ask "Puerto Uvicorn" "${API_PORT:-8000}")
echo ""

# ══════════════════════════════════════════════════════════════════════
# SECCIÓN 3: JWT
# ══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  ─── 🔐 Configuración de Seguridad (JWT) ───────────────────${NC}"

if confirm "¿Generar nueva SECRET_KEY automáticamente?"; then
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null \
                 || openssl rand -hex 32)
    echo -e "  ${G}Nueva clave generada:${NC} ${DIM}${SECRET_KEY:0:16}...${NC}"
else
    SECRET_KEY=$(ask "SECRET_KEY" "${SECRET_KEY:-}" "true")
fi

ACCESS_TOKEN_EXPIRE_MINUTES=$(ask "Expiración token acceso (minutos)" "${ACCESS_TOKEN_EXPIRE_MINUTES:-60}")
REFRESH_TOKEN_EXPIRE_DAYS=$(ask "Expiración token refresh (días)"   "${REFRESH_TOKEN_EXPIRE_DAYS:-7}")
echo ""

# ══════════════════════════════════════════════════════════════════════
# SECCIÓN 4: IA
# ══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  ─── 🤖 Servicios de IA (opcional) ────────────────────────${NC}"
echo -e "  ${DIM}Presiona ENTER para mantener el valor actual o dejarlo vacío${NC}"
GEMINI_API_KEY=$(ask "GEMINI_API_KEY"       "${GEMINI_API_KEY:-}" "true")
OPENROUTER_API_KEY=$(ask "OPENROUTER_API_KEY" "${OPENROUTER_API_KEY:-}" "true")
echo ""

# ══════════════════════════════════════════════════════════════════════
# RESUMEN Y CONFIRMACIÓN
# ══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}  ─── 📋 Resumen de Configuración ──────────────────────────${NC}"
echo ""
echo -e "  ${W}PostgreSQL:${NC}"
echo -e "    Host:     ${DB_HOST}:${DB_PORT}"
echo -e "    Base:     ${DB_NAME}"
echo -e "    Usuario:  ${DB_USER}"
echo -e "    Password: ${DIM}(configurada)${NC}"
echo ""
echo -e "  ${W}API:${NC}"
echo -e "    URL:      ${API_BASE_URL}"
echo -e "    Puerto:   ${API_PORT}"
echo ""
echo -e "  ${W}JWT:${NC}"
echo -e "    Expiración: ${ACCESS_TOKEN_EXPIRE_MINUTES}min / ${REFRESH_TOKEN_EXPIRE_DAYS}d"
echo ""
echo -e "  ${W}IA:${NC}"
echo -e "    Gemini:       ${GEMINI_API_KEY:+configurada}${GEMINI_API_KEY:-no configurada}"
echo -e "    OpenRouter:   ${OPENROUTER_API_KEY:+configurada}${OPENROUTER_API_KEY:-no configurada}"
echo ""

if ! confirm "¿Guardar configuración en $ENV_FILE?"; then
    echo -e "\n  ${Y}Cancelado. El archivo no fue modificado.${NC}\n"
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════
# ESCRITURA DEL .env
# ══════════════════════════════════════════════════════════════════════
mkdir -p "$(dirname "$ENV_FILE")"

cat > "$ENV_FILE" <<EOF
# ╔══════════════════════════════════════════════════════════════╗
# ║   .env — AutoWorks Bolivia                                   ║
# ║   Generado: $(date '+%Y-%m-%d %H:%M:%S')
# ║   ⚠️  NUNCA subas este archivo al repositorio Git            ║
# ╚══════════════════════════════════════════════════════════════╝

# ── PostgreSQL ──────────────────────────────────────────────────────
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# ── API ─────────────────────────────────────────────────────────────
API_BASE_URL=${API_BASE_URL}
API_PORT=${API_PORT}

# ── JWT ─────────────────────────────────────────────────────────────
SECRET_KEY=${SECRET_KEY}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=${ACCESS_TOKEN_EXPIRE_MINUTES}
REFRESH_TOKEN_EXPIRE_DAYS=${REFRESH_TOKEN_EXPIRE_DAYS}

# ── Servicios de IA ─────────────────────────────────────────────────
GEMINI_API_KEY=${GEMINI_API_KEY}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
EOF

chmod 600 "$ENV_FILE"

echo ""
echo -e "  ${G}✅ .env guardado correctamente en: $ENV_FILE${NC}"
echo -e "  ${DIM}Permisos: 600 (solo lectura del propietario)${NC}"

# ══════════════════════════════════════════════════════════════════════
# OPCIONAL: Crear usuario y base de datos en PostgreSQL
# ══════════════════════════════════════════════════════════════════════
echo ""
if confirm "¿Crear el usuario y la base de datos en PostgreSQL ahora?"; then
    echo -e "\n  ${C}Ejecutando como usuario postgres...${NC}"
    sudo -u postgres psql <<PSQL 2>&1 | sed 's/^/    /'
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        RAISE NOTICE 'Usuario ${DB_USER} creado.';
    ELSE
        ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
        RAISE NOTICE 'Password de ${DB_USER} actualizada.';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}') \gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};

\c ${DB_NAME}
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
PSQL
    echo -e "\n  ${G}✅ Usuario y base de datos configurados${NC}"
fi

echo ""
echo -e "  ${DIM}Próximo paso:  bash deploy/backend/02_init_db.sh${NC}"
echo ""
