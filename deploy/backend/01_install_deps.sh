#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 01 Instalar Dependencias (PostgreSQL)               ║
# ║   Instala: Python 3.11, pip, PostgreSQL, psycopg2, venv         ║
# ║   Uso: sudo bash backend/01_install_deps.sh [--skip-pg]         ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' NC='\033[0m'
log()     { echo -e "${C}[BACKEND]${NC} $*"; }
success() { echo -e "${G}[  OK  ]${NC} $*"; }
warn()    { echo -e "${Y}[ WARN ]${NC} $*"; }
error()   { echo -e "${R}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKEND_DIR="$PROJECT_DIR/backend"
SKIP_PG=false

while [[ $# -gt 0 ]]; do
    case "$1" in --skip-pg) SKIP_PG=true; shift ;; *) shift ;; esac
done

log "Directorio del backend: $BACKEND_DIR"
echo ""

# ── 1. Sistema ────────────────────────────────────────────────────────
log "Actualizando paquetes del sistema..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl git build-essential libssl-dev libffi-dev \
    software-properties-common ca-certificates gnupg lsb-release
success "Sistema actualizado"

# ── 2. Python 3.12 ────────────────────────────────────────────────────
log "Instalando Python 3.12..."
add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
apt-get update -y
apt-get install -y python3.12 python3.12-venv python3.12-dev python3-pip
success "Python $(python3.12 --version) instalado"

# ── 3. PostgreSQL (cliente + servidor) ───────────────────────────────
if [ "$SKIP_PG" = false ]; then
    log "Instalando PostgreSQL 16..."
    if ! dpkg -l | grep -q "postgresql-16"; then
        # Repositorio oficial de PostgreSQL
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
            | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
        echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
            > /etc/apt/sources.list.d/pgdg.list
        apt-get update -y
        apt-get install -y postgresql-16 postgresql-client-16 libpq-dev
    else
        warn "PostgreSQL ya instalado, omitiendo..."
    fi

    # Iniciar y habilitar PostgreSQL
    systemctl enable postgresql && systemctl start postgresql
    success "PostgreSQL $(psql --version | head -1) instalado y corriendo"
else
    warn "Instalación de PostgreSQL omitida (--skip-pg)"
    # Instalar solo libpq-dev para psycopg2
    apt-get install -y libpq-dev postgresql-client
fi

# ── 4. Entorno virtual Python ─────────────────────────────────────────
log "Creando entorno virtual en $BACKEND_DIR/venv..."
cd "$BACKEND_DIR"
if [ ! -d "venv" ]; then
    python3.12 -m venv venv
    success "Entorno virtual creado"
else
    warn "Entorno virtual ya existe, actualizando..."
fi

# ── 5. Dependencias Python ────────────────────────────────────────────
log "Instalando dependencias Python (requirements.txt)..."
source "$BACKEND_DIR/venv/bin/activate"
pip install --upgrade pip wheel setuptools
pip install -r "$BACKEND_DIR/requirements.txt"
deactivate
success "Dependencias Python instaladas"

# ── 6. Carpetas estáticas ─────────────────────────────────────────────
log "Creando carpetas de archivos estáticos..."
mkdir -p "$BACKEND_DIR/static/fotos_vehiculos"
mkdir -p "$BACKEND_DIR/static/logos_talleres"
mkdir -p "$BACKEND_DIR/static/fotos_perfil"
chmod -R 755 "$BACKEND_DIR/static"
success "Carpetas estáticas creadas"

echo ""
success "✅ Instalación del backend completada"
echo ""
echo -e "  Siguiente paso: bash deploy/configure_env.sh"
