#!/bin/bash
# capture-bluetooth.sh - Sistema de captura de tráfego Bluetooth
# BlueSecAudit v2.0

set -euo pipefail

CAPTURE_DIR="${1:-/var/log/bluesecaudit/captures}"
DURATION="${2:-300}"
INTERFACE="${3:-hci0}"
SESSION_ID="${4:-$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$CAPTURE_DIR"

echo "🚀 BlueSecAudit v2.0 - Captura Bluetooth"
echo "Session: $SESSION_ID | Duration: ${DURATION}s | Interface: $INTERFACE"

# Verificar dependências
check_deps() {
    local missing=()
    command -v hcidump >/dev/null || missing+=("hcidump")
    command -v tshark >/dev/null || missing+=("tshark")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ Missing: ${missing[*]}"
        echo "Install: sudo apt install bluetooth wireshark-common"
        exit 1
    fi
}

# Verificar interface
check_interface() {
    if ! hciconfig "$INTERFACE" >/dev/null 2>&1; then
        echo "❌ Interface $INTERFACE not found"
        exit 1
    fi
    hciconfig "$INTERFACE" up || true
}

# Iniciar capturas
start_captures() {
    local hci_file="$CAPTURE_DIR/hci_${SESSION_ID}.pcap"
    local tshark_file="$CAPTURE_DIR/tshark_${SESSION_ID}.pcap"
    
    echo "📡 Starting HCI capture..."
    hcidump -i "$INTERFACE" -w "$hci_file" &
    echo "$!" > "$CAPTURE_DIR/hci_${SESSION_ID}.pid"
    
    echo "📡 Starting Tshark capture..."
    if tshark -D | grep -q bluetooth; then
        tshark -i bluetooth0 -w "$tshark_file" &
        echo "$!" > "$CAPTURE_DIR/tshark_${SESSION_ID}.pid"
    fi
    
    echo "✅ Captures started"
}

# Parar capturas
stop_captures() {
    echo "🛑 Stopping captures..."
    
    for pid_file in "$CAPTURE_DIR"/*"${SESSION_ID}".pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            kill "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        fi
    done
    
    echo "✅ Captures stopped"
    
    # Resumo
    echo "📋 Capture Summary:"
    for file in "$CAPTURE_DIR"/*"${SESSION_ID}"*; do
        if [[ -f "$file" && ! "$file" =~ \.pid$ ]]; then
            local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            local size_mb=$((size / 1024 / 1024))
            echo "  📄 $(basename "$file") (${size_mb}MB)"
        fi
    done
}

# Trap para limpeza
trap stop_captures EXIT SIGINT SIGTERM

# Main
check_deps
check_interface
start_captures

echo "📊 Monitoring for ${DURATION}s... (Ctrl+C to stop)"
sleep "$DURATION" 