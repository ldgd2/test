#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 07 Estado del servicio                             ║
# ║   Uso: bash frontend/07_status_frontend.sh                      ║
# ╚══════════════════════════════════════════════════════════════════╝

SERVICE="autoworks-frontend"
CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Estado: ${SERVICE}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl status "$SERVICE" --no-pager --lines=20

echo ""
echo -e "${CYAN}  Puerto(s) en uso:${NC}"
ss -tlnp | grep -E ':4000' | awk '{print "    " $0}' || echo "    (ninguno)"

echo ""
echo -e "${CYAN}  Últimas 5 líneas del log:${NC}"
journalctl -u "$SERVICE" -n 5 --no-pager | awk '{print "    " $0}'
