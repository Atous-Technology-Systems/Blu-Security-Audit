#!/bin/bash
# production-monitor.sh - Monitor de produção BlueSecAudit v2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
RESULTS_DIR="$SCRIPT_DIR/results"

monitor_system() {
    echo "📊 BlueSecAudit v2.0 - Production Monitor"
    echo "Time: $(date)"
    echo ""
    
    # Status sistema
    echo "🖥️ SYSTEM STATUS:"
    echo "  CPU: $(top -bn1 | grep Cpu | awk '{print $2}' | sed 's/%us,//')"
    echo "  RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $5}')"
    echo ""
    
    # Processos Bluetooth
    echo "🔧 BLUETOOTH PROCESSES:"
    ps aux | grep -E "(bluetooth|hci|gatt)" | grep -v grep | head -5
    echo ""
    
    # Adaptadores ativos
    echo "📡 BLUETOOTH ADAPTERS:"
    hciconfig | grep -E "(hci|UP|DOWN)" | head -10
    echo ""
    
    # Sessões ativas
    echo "📋 ACTIVE SESSIONS:"
    find "$RESULTS_DIR" -name "*$(date +%Y%m%d)*" -type f | wc -l | awk '{print "  Today: " $1 " files"}'
    find "$LOG_DIR" -name "*.log" -mtime -1 | wc -l | awk '{print "  Recent logs: " $1}'
    echo ""
    
    # Capturas ativas
    echo "📹 ACTIVE CAPTURES:"
    if pgrep -f "hcidump\|tshark" >/dev/null; then
        echo "  🔴 Capture processes running"
        pgrep -f "hcidump\|tshark" | wc -l | awk '{print "  Processes: " $1}'
    else
        echo "  ⚪ No captures running"
    fi
    echo ""
    
    # Alertas
    echo "⚠️ ALERTS:"
    local alerts=0
    
    # Verificar espaço em disco
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        echo "  🔴 High disk usage: ${disk_usage}%"
        ((alerts++))
    fi
    
    # Verificar memória
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 85 ]]; then
        echo "  🔴 High memory usage: ${mem_usage}%"
        ((alerts++))
    fi
    
    # Verificar adaptador Bluetooth
    if ! hciconfig hci0 >/dev/null 2>&1; then
        echo "  🔴 Bluetooth adapter not available"
        ((alerts++))
    fi
    
    if [[ $alerts -eq 0 ]]; then
        echo "  ✅ No alerts"
    fi
    
    echo ""
    echo "================================================"
}

# Modo contínuo
if [[ "${1:-}" == "--continuous" ]]; then
    echo "Starting continuous monitoring (Ctrl+C to stop)..."
    while true; do
        clear
        monitor_system
        sleep 30
    done
else
    monitor_system
fi 