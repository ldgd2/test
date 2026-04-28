#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 07 Ver Logs del servicio                            ║
# ║   Uso: bash backend/07_logs_backend.sh [--lines N] [--follow]   ║
# ╚══════════════════════════════════════════════════════════════════╝

LINES=50
FOLLOW=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines|-n) LINES="$2"; shift 2 ;;
        --follow|-f) FOLLOW=true; shift ;;
        --errors|-e) ERRORS_ONLY=true; shift ;;
        *) shift ;;
    esac
done

SERVICE="autoworks-backend"
CYAN='\033[0;36m'; NC='\033[0m'
echo -e "${CYAN}[BACKEND]${NC} Mostrando logs del servicio: $SERVICE"
echo -e "${CYAN}[BACKEND]${NC} Últimas $LINES líneas ${FOLLOW:+(siguiendo en tiempo real...)}${NC}"
echo ""

if [ "$FOLLOW" = true ]; then
    journalctl -u "$SERVICE" -n "$LINES" -f
else
    journalctl -u "$SERVICE" -n "$LINES" --no-pager
fi
