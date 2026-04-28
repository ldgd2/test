#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   HERRAMIENTA — Configurar Firewall (UFW)                       ║
# ║   Abre solo los puertos necesarios: 22, 8000, 4000              ║
# ║   Uso: sudo bash deploy/setup_firewall.sh                       ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[FIREWALL]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

[[ "$EUID" -ne 0 ]] && error "Ejecuta como root: sudo bash setup_firewall.sh"

log "Configurando UFW (Uncomplicated Firewall)..."
echo ""

# Instalar UFW si no está disponible
if ! command -v ufw &>/dev/null; then
    log "Instalando UFW..."
    apt-get install -y ufw
fi

# ── Reset de reglas ────────────────────────────────────────────────────
log "Reseteando reglas existentes..."
ufw --force reset

# ── Política por defecto ───────────────────────────────────────────────
ufw default deny incoming
ufw default allow outgoing
success "Política por defecto: deny incoming, allow outgoing"

# ── SSH (CRÍTICO: siempre primero para no perder acceso) ──────────────
ufw allow 22/tcp comment "SSH"
success "Puerto 22 (SSH) abierto"

# ── Backend FastAPI ────────────────────────────────────────────────────
ufw allow 8000/tcp comment "AutoWorks Backend (FastAPI)"
success "Puerto 8000 (Backend) abierto"

# ── Frontend Angular SSR ──────────────────────────────────────────────
ufw allow 4000/tcp comment "AutoWorks Frontend (Angular SSR)"
success "Puerto 4000 (Frontend) abierto"

# ── Habilitar UFW ─────────────────────────────────────────────────────
log "Habilitando UFW..."
ufw --force enable

# ── Mostrar estado ────────────────────────────────────────────────────
echo ""
ufw status verbose

echo ""
success "✅ Firewall configurado correctamente"
echo ""
echo "  Puertos abiertos:"
echo "    :22   → SSH"
echo "    :8000 → Backend  (http://185.214.134.23:8000)"
echo "    :4000 → Frontend (http://185.214.134.23:4000)"
