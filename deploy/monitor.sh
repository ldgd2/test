#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   HERRAMIENTA — Monitor de ambos servicios                      ║
# ║   Muestra estado y logs de backend + frontend en tiempo real    ║
# ║   Uso: bash deploy/monitor.sh                                   ║
# ╚══════════════════════════════════════════════════════════════════╝

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

clear
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     🖥️  AutoWorks Bolivia — Monitor de Servicios      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Estado de los servicios ───────────────────────────────────────────
echo -e "${BOLD}  Estado de Servicios${NC}"
echo -e "  ─────────────────────────────────────────────────────"

for SERVICE in autoworks-backend autoworks-frontend; do
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        UPTIME=$(systemctl show "$SERVICE" --property=ActiveEnterTimestamp \
            | cut -d= -f2 | xargs -I{} date -d "{}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "?")
        echo -e "  ${GREEN}● ACTIVO${NC}  $SERVICE  (desde $UPTIME)"
    else
        echo -e "  ${RED}● INACTIVO${NC} $SERVICE"
    fi
done

echo ""

# ── Puertos en uso ────────────────────────────────────────────────────
echo -e "${BOLD}  Puertos en Uso${NC}"
echo -e "  ─────────────────────────────────────────────────────"
for PORT in 8000 4000; do
    if ss -tlnp | grep -q ":$PORT"; then
        PROC=$(ss -tlnp | grep ":$PORT" | awk '{print $NF}' | head -1)
        echo -e "  ${GREEN}●${NC} :$PORT → $PROC"
    else
        echo -e "  ${RED}●${NC} :$PORT → (libre)"
    fi
done

echo ""

# ── Uso de recursos del sistema ───────────────────────────────────────
echo -e "${BOLD}  Recursos del Sistema${NC}"
echo -e "  ─────────────────────────────────────────────────────"
echo -e "  CPU:    $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | tr -d '%us,')% uso"
echo -e "  RAM:    $(free -h | awk '/^Mem:/{print $3 " usados de " $2}')"
echo -e "  Disco:  $(df -h / | awk 'NR==2{print $3 " usados de " $2 " (" $5 " lleno)"}')"

echo ""
echo -e "${BOLD}  ¿Qué logs deseas ver?${NC}"
echo "  1) Backend  (journalctl -u autoworks-backend -f)"
echo "  2) Frontend (journalctl -u autoworks-frontend -f)"
echo "  3) Ambos    (tmux split)"
echo "  0) Salir"
echo ""
read -rp "  Opción: " OPT

case "$OPT" in
    1) journalctl -u autoworks-backend  -f -n 50 ;;
    2) journalctl -u autoworks-frontend -f -n 50 ;;
    3)
        if command -v tmux &>/dev/null; then
            tmux new-session \
                "journalctl -u autoworks-backend -f -n 30" \; \
                split-window -h "journalctl -u autoworks-frontend -f -n 30" \; \
                attach
        else
            echo "  tmux no instalado. Instala con: sudo apt-get install -y tmux"
            journalctl -u autoworks-backend -u autoworks-frontend -f -n 50
        fi
        ;;
    0) echo "  Bye!"; exit 0 ;;
    *) echo "  Opción inválida"; exit 1 ;;
esac
