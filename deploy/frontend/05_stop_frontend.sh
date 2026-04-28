#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 05 Detener servicio                                ║
# ║   Uso: sudo bash frontend/05_stop_frontend.sh                   ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[FRONTEND]${NC} $*"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $*"; }

SERVICE="autoworks-frontend"

log "Deteniendo servicio: $SERVICE"
systemctl stop "$SERVICE"

warn "⏹  Frontend detenido"
