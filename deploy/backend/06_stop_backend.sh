#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 06 Detener servicio                                 ║
# ║   Uso: sudo bash backend/06_stop_backend.sh                     ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[BACKEND]${NC} $*"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $*"; }

SERVICE="autoworks-backend"

log "Deteniendo servicio: $SERVICE"
systemctl stop "$SERVICE"

warn "⏹  Backend detenido"
