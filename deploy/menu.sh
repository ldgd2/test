#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   AutoWorks Bolivia — Menú Principal de Administración          ║
# ║   Uso: sudo bash deploy/menu.sh                                 ║
# ╚══════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Colores ───────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m'
B='\033[0;34m' M='\033[0;35m' W='\033[1;37m' DIM='\033[2m' NC='\033[0m'
BOLD='\033[1m'

# ── Helpers ────────────────────────────────────────────────────────────
cls()     { clear; }
pause()   { echo ""; read -rp "  $(echo -e "${DIM}Presiona ENTER para continuar...${NC}")" _; }
run()     { bash "$@"; pause; }
need_root() { [[ "$EUID" -ne 0 ]] && echo -e "${R}  ⚠  Ejecuta con sudo${NC}" && pause && return 1; return 0; }

svc_status() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${G}● ACTIVO${NC}"
    else
        echo -e "${R}● INACTIVO${NC}"
    fi
}

header() {
    cls
    echo -e "${C}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║     🔧 AutoWorks Bolivia — Panel de Administración       ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    # Estado de servicios en la cabecera
    local be=$(svc_status "autoworks-backend")
    local fe=$(svc_status "autoworks-frontend")
    echo -e "     Backend:  $be  ${DIM}http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo '?'):8000${NC}"
    echo -e "     Frontend: $fe  ${DIM}http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo '?'):4000${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════
# SUBMENÚ: BACKEND
# ══════════════════════════════════════════════════════════════════════
menu_backend() {
    while true; do
        header
        echo -e "  ${C}${BOLD}🐍 BACKEND — FastAPI + Uvicorn (PostgreSQL)${NC}"
        echo -e "  ${DIM}────────────────────────────────────────────────────────${NC}"
        echo -e "   ${W}1.${NC}  Instalar dependencias Python + PostgreSQL"
        echo -e "   ${W}2.${NC}  Inicializar / migrar base de datos"
        echo -e "   ${W}3.${NC}  Ejecutar seeder (datos de prueba)"
        echo -e "   ${W}4.${NC}  Crear servicio systemd"
        echo -e "   ${W}5.${NC}  Iniciar / Reiniciar backend"
        echo -e "   ${W}6.${NC}  Detener backend"
        echo -e "   ${W}7.${NC}  Ver logs  ${DIM}[--lines N] [--follow]${NC}"
        echo -e "   ${W}8.${NC}  Estado del servicio"
        echo -e "   ${W}9.${NC}  Abrir consola psql"
        echo -e "   ${W}10.${NC} Backup de la base de datos"
        echo ""
        echo -e "   ${DIM}0. ← Volver${NC}"
        echo ""
        read -rp "  Opción: " opt
        case "$opt" in
            1) need_root && run "$SCRIPT_DIR/backend/01_install_deps.sh" ;;
            2) run "$SCRIPT_DIR/backend/02_init_db.sh" ;;
            3)
                echo ""
                echo -e "  ${Y}Seeder:${NC}  a) Interactivo   b) Automático (N registros)"
                read -rp "  Modo [a/b]: " sm
                if [[ "$sm" == "b" ]]; then
                    read -rp "  Número de registros por tabla [default: 30]: " sn
                    sn="${sn:-30}"
                    run "$SCRIPT_DIR/backend/03_seed_db.sh" --auto "$sn"
                else
                    run "$SCRIPT_DIR/backend/03_seed_db.sh"
                fi
                ;;
            4) need_root && run "$SCRIPT_DIR/backend/04_create_service.sh" ;;
            5) need_root && run "$SCRIPT_DIR/backend/05_start_backend.sh" ;;
            6) need_root && run "$SCRIPT_DIR/backend/06_stop_backend.sh" ;;
            7)
                echo ""
                read -rp "  Líneas a mostrar [default: 50]: " ln
                ln="${ln:-50}"
                echo -e "  ¿Seguir en tiempo real? [s/N]: "; read -rp "  " fw
                if [[ "$fw" =~ ^[Ss]$ ]]; then
                    bash "$SCRIPT_DIR/backend/07_logs_backend.sh" --lines "$ln" --follow
                else
                    bash "$SCRIPT_DIR/backend/07_logs_backend.sh" --lines "$ln"
                    pause
                fi
                ;;
            8) run "$SCRIPT_DIR/backend/08_status_backend.sh" ;;
            9)
                source "$PROJECT_DIR/backend/.env" 2>/dev/null || true
                echo -e "\n  ${C}Abriendo psql...${NC}"
                PGPASSWORD="${DB_PASSWORD:-}" psql -h "${DB_HOST:-localhost}" \
                    -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" "${DB_NAME:-autoworks}" || true
                pause
                ;;
            10)
                source "$PROJECT_DIR/backend/.env" 2>/dev/null || true
                TS=$(date +%Y%m%d_%H%M%S)
                DUMP="$PROJECT_DIR/backup_${DB_NAME:-autoworks}_${TS}.sql"
                echo -e "\n  ${C}Creando backup: $DUMP${NC}"
                PGPASSWORD="${DB_PASSWORD:-}" pg_dump -h "${DB_HOST:-localhost}" \
                    -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" "${DB_NAME:-autoworks}" > "$DUMP" \
                    && echo -e "  ${G}✅ Backup creado: $DUMP${NC}" \
                    || echo -e "  ${R}❌ Error en el backup${NC}"
                pause
                ;;
            0) break ;;
            *) echo -e "  ${Y}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════
# SUBMENÚ: FRONTEND
# ══════════════════════════════════════════════════════════════════════
menu_frontend() {
    while true; do
        header
        echo -e "  ${M}${BOLD}🅰️  FRONTEND — Angular SSR + Node.js${NC}"
        echo -e "  ${DIM}────────────────────────────────────────────────────────${NC}"
        echo -e "   ${W}1.${NC}  Instalar dependencias (Node.js + npm)"
        echo -e "   ${W}2.${NC}  Compilar Angular (production build)"
        echo -e "   ${W}3.${NC}  Crear servicio systemd"
        echo -e "   ${W}4.${NC}  Iniciar / Reiniciar frontend"
        echo -e "   ${W}5.${NC}  Detener frontend"
        echo -e "   ${W}6.${NC}  Ver logs  ${DIM}[--lines N] [--follow]${NC}"
        echo -e "   ${W}7.${NC}  Estado del servicio"
        echo -e "   ${W}8.${NC}  Limpiar build (dist/)"
        echo ""
        echo -e "   ${DIM}0. ← Volver${NC}"
        echo ""
        read -rp "  Opción: " opt
        case "$opt" in
            1) need_root && run "$SCRIPT_DIR/frontend/01_install_deps.sh" ;;
            2) run "$SCRIPT_DIR/frontend/02_build.sh" ;;
            3) need_root && run "$SCRIPT_DIR/frontend/03_create_service.sh" ;;
            4) need_root && run "$SCRIPT_DIR/frontend/04_start_frontend.sh" ;;
            5) need_root && run "$SCRIPT_DIR/frontend/05_stop_frontend.sh" ;;
            6)
                read -rp "  Líneas a mostrar [default: 50]: " ln
                ln="${ln:-50}"
                read -rp "  ¿Seguir en tiempo real? [s/N]: " fw
                if [[ "$fw" =~ ^[Ss]$ ]]; then
                    bash "$SCRIPT_DIR/frontend/06_logs_frontend.sh" --lines "$ln" --follow
                else
                    bash "$SCRIPT_DIR/frontend/06_logs_frontend.sh" --lines "$ln"
                    pause
                fi
                ;;
            7) run "$SCRIPT_DIR/frontend/07_status_frontend.sh" ;;
            8)
                echo -e "\n  ${Y}¿Borrar dist/ del frontend? [s/N]:${NC} "; read -rp "  " c
                [[ "$c" =~ ^[Ss]$ ]] && rm -rf "$PROJECT_DIR/frontend/dist" \
                    && echo -e "  ${G}✅ dist/ eliminado${NC}" || echo "  Cancelado"
                pause
                ;;
            0) break ;;
            *) echo -e "  ${Y}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════
# SUBMENÚ: CONFIGURACIÓN
# ══════════════════════════════════════════════════════════════════════
menu_config() {
    while true; do
        header
        echo -e "  ${Y}${BOLD}⚙️  CONFIGURACIÓN${NC}"
        echo -e "  ${DIM}────────────────────────────────────────────────────────${NC}"
        echo -e "   ${W}1.${NC}  Configurar .env interactivo"
        echo -e "   ${W}2.${NC}  Ver .env actual  ${DIM}(oculta passwords)${NC}"
        echo -e "   ${W}3.${NC}  Configurar firewall UFW"
        echo -e "   ${W}4.${NC}  Generar SECRET_KEY segura"
        echo -e "   ${W}5.${NC}  Verificar conectividad PostgreSQL"
        echo -e "   ${W}6.${NC}  Habilitar extensión uuid-ossp en PostgreSQL"
        echo ""
        echo -e "   ${DIM}0. ← Volver${NC}"
        echo ""
        read -rp "  Opción: " opt
        case "$opt" in
            1) run "$SCRIPT_DIR/configure_env.sh" ;;
            2)
                echo ""
                if [ -f "$PROJECT_DIR/backend/.env" ]; then
                    grep -v "PASSWORD\|SECRET\|KEY\|TOKEN" "$PROJECT_DIR/backend/.env" \
                        | sed 's/^/    /' || true
                    echo -e "    ${DIM}(passwords/keys ocultos por seguridad)${NC}"
                else
                    echo -e "  ${R}  .env no encontrado${NC}"
                fi
                pause
                ;;
            3) need_root && run "$SCRIPT_DIR/setup_firewall.sh" ;;
            4)
                echo ""
                KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null \
                      || openssl rand -hex 32)
                echo -e "  ${G}Nueva SECRET_KEY:${NC}"
                echo -e "  ${W}$KEY${NC}"
                echo ""
                echo -e "  ${DIM}Copia esta clave y pégala en SECRET_KEY del .env${NC}"
                pause
                ;;
            5)
                source "$PROJECT_DIR/backend/.env" 2>/dev/null || true
                echo ""
                if PGPASSWORD="${DB_PASSWORD:-}" psql -h "${DB_HOST:-localhost}" \
                       -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" \
                       "${DB_NAME:-autoworks}" -c "\conninfo" 2>/dev/null; then
                    echo -e "\n  ${G}✅ Conexión exitosa a PostgreSQL${NC}"
                else
                    echo -e "\n  ${R}❌ No se pudo conectar a PostgreSQL${NC}"
                fi
                pause
                ;;
            6)
                source "$PROJECT_DIR/backend/.env" 2>/dev/null || true
                PGPASSWORD="${DB_PASSWORD:-}" psql -h "${DB_HOST:-localhost}" \
                    -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" "${DB_NAME:-autoworks}" \
                    -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' \
                    && echo -e "  ${G}✅ Extensión uuid-ossp habilitada${NC}" \
                    || echo -e "  ${R}❌ Error al habilitar la extensión${NC}"
                pause
                ;;
            0) break ;;
            *) echo -e "  ${Y}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════
# SUBMENÚ: DESPLIEGUE
# ══════════════════════════════════════════════════════════════════════
menu_deploy() {
    while true; do
        header
        echo -e "  ${G}${BOLD}🚀 DESPLIEGUE${NC}"
        echo -e "  ${DIM}────────────────────────────────────────────────────────${NC}"
        echo -e "   ${W}1.${NC}  Deploy completo (primera vez)"
        echo -e "   ${W}2.${NC}  Actualizar solo backend"
        echo -e "   ${W}3.${NC}  Actualizar solo frontend"
        echo -e "   ${W}4.${NC}  Actualizar ambos"
        echo -e "   ${W}5.${NC}  Reiniciar todos los servicios"
        echo -e "   ${W}6.${NC}  Detener todos los servicios"
        echo ""
        echo -e "   ${DIM}0. ← Volver${NC}"
        echo ""
        read -rp "  Opción: " opt
        case "$opt" in
            1) need_root && run "$SCRIPT_DIR/deploy.sh" ;;
            2) need_root && run "$SCRIPT_DIR/update.sh" --backend ;;
            3) need_root && run "$SCRIPT_DIR/update.sh" --frontend ;;
            4) need_root && run "$SCRIPT_DIR/update.sh" ;;
            5)
                need_root || continue
                echo -e "\n  ${C}Reiniciando autoworks-backend y autoworks-frontend...${NC}"
                systemctl restart autoworks-backend autoworks-frontend 2>/dev/null \
                    && echo -e "  ${G}✅ Servicios reiniciados${NC}" \
                    || echo -e "  ${R}❌ Error al reiniciar${NC}"
                pause
                ;;
            6)
                need_root || continue
                echo -e "\n  ${Y}¿Detener ambos servicios? [s/N]:${NC} "; read -rp "  " c
                [[ "$c" =~ ^[Ss]$ ]] && systemctl stop autoworks-backend autoworks-frontend 2>/dev/null \
                    && echo -e "  ${Y}⏹  Servicios detenidos${NC}" || echo "  Cancelado"
                pause
                ;;
            0) break ;;
            *) echo -e "  ${Y}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        header
        echo -e "  ${BOLD}¿Qué deseas hacer?${NC}"
        echo -e "  ${DIM}────────────────────────────────────────────────────────${NC}"
        echo -e "   ${C}${BOLD}1.${NC}  🐍 Backend       ${DIM}FastAPI + Uvicorn + PostgreSQL${NC}"
        echo -e "   ${M}${BOLD}2.${NC}  🅰️  Frontend      ${DIM}Angular SSR + Node.js${NC}"
        echo -e "   ${Y}${BOLD}3.${NC}  ⚙️  Configuración  ${DIM}.env, firewall, PostgreSQL${NC}"
        echo -e "   ${G}${BOLD}4.${NC}  🚀 Despliegue     ${DIM}deploy, update, restart${NC}"
        echo -e "   ${W}${BOLD}5.${NC}  🖥️  Monitor        ${DIM}estado, logs, recursos${NC}"
        echo ""
        echo -e "   ${DIM}0. Salir${NC}"
        echo ""
        read -rp "  Opción: " opt
        case "$opt" in
            1) menu_backend ;;
            2) menu_frontend ;;
            3) menu_config ;;
            4) menu_deploy ;;
            5) bash "$SCRIPT_DIR/monitor.sh"; pause ;;
            0) echo -e "\n  ${DIM}👋 Hasta luego!${NC}\n"; exit 0 ;;
            *) echo -e "  ${Y}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

main_menu
