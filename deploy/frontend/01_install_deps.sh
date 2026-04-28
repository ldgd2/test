#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 01 Instalar Dependencias                           ║
# ║   Instala: Node.js 20 LTS, npm, Angular CLI, dependencias       ║
# ║   Uso: sudo bash frontend/01_install_deps.sh                    ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[FRONTEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FRONTEND_DIR="$PROJECT_DIR/frontend"

log "Directorio del frontend: $FRONTEND_DIR"
echo ""

# ── 1. Instalar Node.js 20 LTS via NodeSource ─────────────────────────
if ! command -v node &>/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d 'v')" -lt 18 ]]; then
    log "Instalando Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    success "Node.js $(node -v) instalado"
else
    warn "Node.js ya instalado: $(node -v)"
fi

# ── 2. Verificar npm ───────────────────────────────────────────────────
success "npm $(npm -v) disponible"

# ── 3. Instalar Angular CLI globalmente ───────────────────────────────
log "Instalando Angular CLI globalmente..."
npm install -g @angular/cli@latest --silent
success "Angular CLI $(ng version --skip-git 2>/dev/null | grep 'Angular CLI' | awk '{print $NF}' || echo 'instalado')"

# ── 4. Instalar dependencias del proyecto ─────────────────────────────
log "Instalando dependencias npm del proyecto ($FRONTEND_DIR)..."
cd "$FRONTEND_DIR"
npm install --legacy-peer-deps
success "Dependencias npm instaladas"

# ── 5. Verificar que la compilación es posible ────────────────────────
log "Verificando configuración de Angular..."
if [ -f "$FRONTEND_DIR/angular.json" ]; then
    success "angular.json encontrado"
else
    error "angular.json no encontrado — ¿estás en el directorio correcto?"
fi

echo ""
success "✅ Dependencias del frontend instaladas correctamente"
echo ""
echo -e "  Siguiente paso: bash frontend/02_build.sh"
