#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 02 Compilar Angular (Production Build)             ║
# ║   Genera el bundle en dist/frontend/                            ║
# ║   Uso: bash frontend/02_build.sh                                ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()     { echo -e "${CYAN}[FRONTEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FRONTEND_DIR="$PROJECT_DIR/frontend"

log "Compilando Angular en modo producción..."
log "Directorio: $FRONTEND_DIR"
echo ""

cd "$FRONTEND_DIR"

# ── Verificar node_modules ────────────────────────────────────────────
if [ ! -d "node_modules" ]; then
    warn "node_modules no encontrado. Instalando dependencias primero..."
    npm install --legacy-peer-deps
fi

# ── Limpiar build anterior ────────────────────────────────────────────
if [ -d "dist" ]; then
    log "Limpiando build anterior..."
    rm -rf dist
fi

# ── Build de producción ───────────────────────────────────────────────
log "Ejecutando compilación directa con binario local..."
echo ""

# Aumentar memoria Node.js para evitar errores de memoria
export NODE_OPTIONS="--max_old_space_size=4096"

START_TIME=$(date +%s)
# Llamada directa al binario para evitar alias o comportamientos del shell
./node_modules/.bin/ng build --configuration production
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo ""
success "✅ Build completado en ${BUILD_TIME}s"

# ── Verificar artefactos ──────────────────────────────────────────────
log "Verificando artefactos en $FRONTEND_DIR/dist/..."

# Posibles rutas de server.mjs en Angular 17/18/21
SERVER_PATH_1="$FRONTEND_DIR/dist/frontend/server/server.mjs"
SERVER_PATH_2="$FRONTEND_DIR/dist/frontend/server/main.server.mjs"

if [ -f "$SERVER_PATH_1" ]; then
    success "SSR Server detectado: $SERVER_PATH_1"
elif [ -f "$SERVER_PATH_2" ]; then
    success "SSR Server detectado: $SERVER_PATH_2"
    # Crear un enlace simbólico o renombrar si el servicio espera server.mjs
    ln -sf "$SERVER_PATH_2" "$SERVER_PATH_1"
elif [ -d "$FRONTEND_DIR/dist/frontend/browser" ]; then
    success "SPA Browser detectado: dist/frontend/browser/"
else
    warn "Contenido de la carpeta dist:"
    ls -R "$FRONTEND_DIR/dist" || echo "Carpeta dist vacía o no existe"
    error "No se encontraron artefactos de build esperados en dist/frontend/ (browser o server)"
fi

echo ""
echo -e "  ${BOLD}Tamaño del build:${NC}"
du -sh "$FRONTEND_DIR/dist/" 2>/dev/null | awk '{print "    " $0}'
echo ""
echo -e "  Siguiente paso: bash frontend/03_create_service.sh"
