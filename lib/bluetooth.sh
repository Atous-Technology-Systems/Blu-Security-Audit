#!/bin/bash
# lib/bluetooth.sh - Módulo Bluetooth com funcionalidades reais avançadas

set -euo pipefail

# Importar dependências
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Configurações
HCIDUMP_PID_FILE="/tmp/hcidump.pid"
DEFAULT_ADAPTER="hci0"
SCAN_TIMEOUT=30
INQUIRY_LENGTH=8
MAX_DEVICES=255

# Verificar dependências Bluetooth reais
check_bluetooth_dependencies() {
    local missing_deps=()
    
    # Verificar ferramentas essenciais
    command -v bluetoothctl >/dev/null 2>&1 || missing_deps+=("bluetoothctl")
    command -v hcitool >/dev/null 2>&1 || missing_deps+=("hcitool")
    command -v hciconfig >/dev/null 2>&1 || missing_deps+=("hciconfig")
    command -v sdptool >/dev/null 2>&1 || missing_deps+=("sdptool")
    command -v l2ping >/dev/null 2>&1 || missing_deps+=("l2ping")
    
    # Verificar ferramentas opcionais
    command -v hcidump >/dev/null 2>&1 || echo "⚠️ hcidump não encontrado - captura limitada"
    command -v tshark >/dev/null 2>&1 || echo "⚠️ tshark não encontrado - análise limitada"
    command -v obexftp >/dev/null 2>&1 || echo "⚠️ obexftp não encontrado - OBEX limitado"
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ Dependências faltando: ${missing_deps[*]}"
        echo "Execute: sudo apt-get install bluez bluez-tools"
        return 1
    fi
    
    return 0
}

# Verificar se adaptador está ativo
is_adapter_up() {
    local adapter="${1:-$DEFAULT_ADAPTER}"
    hciconfig "$adapter" 2>/dev/null | grep -q "UP RUNNING"
}

# Ativar adaptador
bring_adapter_up() {
    local adapter="${1:-$DEFAULT_ADAPTER}"
    
    if ! is_adapter_up "$adapter"; then
        echo "Ativando adaptador $adapter..."
        sudo hciconfig "$adapter" up 2>/dev/null || {
            echo "Falha ao ativar $adapter"
            return 1
        }
        sleep 2
    fi
    
    # Configurar modo discoverable se necessário
    sudo hciconfig "$adapter" piscan 2>/dev/null || true
    
    return 0
}

# Desativar adaptador
bring_adapter_down() {
    local adapter="${1:-$DEFAULT_ADAPTER}"
    
    if is_adapter_up "$adapter"; then
        echo "Desativando adaptador $adapter..."
        sudo hciconfig "$adapter" down 2>/dev/null || {
            echo "Falha ao desativar $adapter"
            return 1
        }
    fi
    
    return 0
}

# Scanning Bluetooth avançado
scan_bluetooth_devices() {
    local adapter="${1:-$DEFAULT_ADAPTER}"
    local duration="${2:-$SCAN_TIMEOUT}"
    local output_file="${3:-}"
    
    echo "🔍 Iniciando scanning Bluetooth avançado..."
    echo "Adaptador: $adapter | Duração: ${duration}s"
    
    # Garantir que adaptador está ativo
    if ! bring_adapter_up "$adapter"; then
        echo "❌ Falha ao ativar adaptador"
        return 1
    fi
    
    local temp_file="/tmp/bt_scan_$$.txt"
    local devices_found=0
    
    # Método 1: hcitool inquiry (mais completo)
    echo "Método 1: hcitool inquiry..."
    if timeout "$duration" hcitool -i "$adapter" inq > "$temp_file" 2>&1; then
        # Processar resultados do inquiry
        while read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([0-9A-F:]{17})[[:space:]]+.*$ ]]; then
                local mac="${BASH_REMATCH[1]}"
                local name=$(timeout 10 hcitool -i "$adapter" name "$mac" 2>/dev/null || echo "Unknown")
                echo -e "$mac\t$name"
                ((devices_found++))
                
                # Salvar em arquivo se especificado
                if [[ -n "$output_file" ]]; then
                    echo -e "$mac\t$name" >> "$output_file"
                fi
            fi
        done < "$temp_file"
    fi
    
    # Método 2: bluetoothctl scan (Bluetooth LE)
    echo "Método 2: bluetoothctl scan..."
    {
        echo "scan on"
        sleep "$duration"
        echo "scan off"
        echo "devices"
        echo "quit"
    } | timeout $((duration + 10)) bluetoothctl 2>/dev/null | while read -r line; do
        if [[ "$line" =~ Device[[:space:]]+([0-9A-F:]{17})[[:space:]]+(.*)$ ]]; then
            local mac="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]:-Unknown}"
            
            # Evitar duplicatas
            if ! grep -q "$mac" "$temp_file" 2>/dev/null; then
                echo -e "$mac\t$name"
                ((devices_found++))
                
                if [[ -n "$output_file" ]]; then
                    echo -e "$mac\t$name" >> "$output_file"
                fi
            fi
        fi
    done
    
    rm -f "$temp_file"
    
    echo "✅ Scanning concluído: $devices_found dispositivos encontrados"
    return 0
}

# Reconnaissance avançado de dispositivo
device_reconnaissance() {
    local target="$1"
    local output_file="${2:-/tmp/recon_${target//:/_}_$$.txt}"
    
    validate_mac_address "$target" || return 1
    
    echo "🕵️ Iniciando reconnaissance de $target..."
    
    # Criar arquivo de saída
    cat > "$output_file" << EOF
=== RECONNAISSANCE REPORT ===
Target: $target
Timestamp: $(date)
Analyst: $(whoami)@$(hostname)

EOF
    
    # 1. Teste de conectividade básica
    echo "1. Testando conectividade..." | tee -a "$output_file"
    if l2ping -c 3 -t 5 "$target" >/dev/null 2>&1; then
        echo "✅ Dispositivo responde a L2CAP ping" | tee -a "$output_file"
        
        # Medir latência
        local latency=$(l2ping -c 5 "$target" 2>/dev/null | grep "ping time" | awk '{print $4}' | tail -1)
        echo "📶 Latência: ${latency:-N/A}" | tee -a "$output_file"
    else
        echo "❌ Dispositivo não responde a L2CAP ping" | tee -a "$output_file"
    fi
    echo "" >> "$output_file"
    
    # 2. Informações básicas do dispositivo
    echo "2. Coletando informações básicas..." | tee -a "$output_file"
    
    # Nome do dispositivo
    local device_name=$(timeout 10 hcitool name "$target" 2>/dev/null || echo "Unknown")
    echo "📱 Nome: $device_name" | tee -a "$output_file"
    
    # Informações de classe
    if command -v hcitool >/dev/null 2>&1; then
        local device_info=$(timeout 10 hcitool info "$target" 2>/dev/null)
        if [[ -n "$device_info" ]]; then
            echo "📋 Informações de classe:" | tee -a "$output_file"
            echo "$device_info" | tee -a "$output_file"
        fi
    fi
    echo "" >> "$output_file"
    
    # 3. Enumeração de serviços
    echo "3. Enumerando serviços..." | tee -a "$output_file"
    if timeout 30 sdptool browse "$target" >> "$output_file" 2>&1; then
        local service_count=$(grep -c "Service Name:" "$output_file" || echo "0")
        echo "✅ Enumeração SDP concluída: $service_count serviços" | tee -a "$output_file"
    else
        echo "❌ Falha na enumeração SDP" | tee -a "$output_file"
    fi
    echo "" >> "$output_file"
    
    # 4. Análise de segurança
    echo "4. Análise de segurança..." | tee -a "$output_file"
    
    # Verificar pairing methods
    if grep -q "Bluetooth 4" "$output_file" 2>/dev/null; then
        echo "🔐 Suporte a SSP (Secure Simple Pairing)" | tee -a "$output_file"
    else
        echo "⚠️ Possivelmente usa Legacy Pairing" | tee -a "$output_file"
    fi
    
    # Verificar serviços sensíveis
    if grep -qi "Serial Port\|SPP" "$output_file"; then
        echo "🚨 ATENÇÃO: Serial Port Profile detectado" | tee -a "$output_file"
    fi
    
    if grep -qi "OBEX\|Object Push" "$output_file"; then
        echo "📁 OBEX disponível - verificar autenticação" | tee -a "$output_file"
    fi
    
    if grep -qi "HID\|Human Interface" "$output_file"; then
        echo "⌨️ HID disponível - risco de injeção" | tee -a "$output_file"
    fi
    
    echo "" >> "$output_file"
    
    # 5. Fingerprinting
    echo "5. Device fingerprinting..." | tee -a "$output_file"
    
    local device_class=$(echo "$device_info" | grep "Device Class:" | cut -d: -f2- | xargs)
    if [[ -n "$device_class" ]]; then
        echo "🏷️ Classe do dispositivo: $device_class" | tee -a "$output_file"
        
        # Determinar tipo baseado na classe
        case "$device_class" in
            *"0x200"*) echo "📱 Tipo detectado: Smartphone" | tee -a "$output_file" ;;
            *"0x240"*) echo "🎧 Tipo detectado: Headset/Audio" | tee -a "$output_file" ;;
            *"0x500"*) echo "⌨️ Tipo detectado: Keyboard/HID" | tee -a "$output_file" ;;
            *"0x2540"*) echo "🖱️ Tipo detectado: Mouse/Pointing" | tee -a "$output_file" ;;
            *) echo "❓ Tipo: Genérico/Desconhecido" | tee -a "$output_file" ;;
        esac
    fi
    
    echo "" >> "$output_file"
    echo "=== FIM DO RECONNAISSANCE ===" >> "$output_file"
    
    echo "✅ Reconnaissance concluído: $output_file"
    log_message "INFO" "Reconnaissance de $target concluído"
    
    return 0
}

# Captura de tráfego Bluetooth
start_packet_capture() {
    local output_file="$1"
    local adapter="${2:-$DEFAULT_ADAPTER}"
    
    echo "📡 Iniciando captura de tráfego Bluetooth..."
    
    # Verificar se hcidump está disponível
    if command -v hcidump >/dev/null 2>&1; then
        # Usar hcidump
        echo "Usando hcidump para captura..."
        sudo hcidump -i "$adapter" -w "$output_file" &
        echo $! > "$HCIDUMP_PID_FILE"
        
    elif command -v tshark >/dev/null 2>&1; then
        # Usar tshark como alternativa
        echo "Usando tshark para captura..."
        sudo tshark -i bluetooth0 -w "$output_file" &
        echo $! > "$HCIDUMP_PID_FILE"
        
    else
        echo "❌ Nenhuma ferramenta de captura disponível"
        echo "Instale: sudo apt-get install bluez-hcidump wireshark"
        return 1
    fi
    
    sleep 2
    echo "✅ Captura iniciada (PID: $(cat "$HCIDUMP_PID_FILE" 2>/dev/null || echo "unknown"))"
    echo "📁 Arquivo: $output_file"
    
    return 0
}

# Parar captura de tráfego
stop_packet_capture() {
    if [[ -f "$HCIDUMP_PID_FILE" ]]; then
        local pid=$(cat "$HCIDUMP_PID_FILE")
        echo "🛑 Parando captura (PID: $pid)..."
        
        if kill "$pid" 2>/dev/null; then
            echo "✅ Captura finalizada"
        else
            echo "⚠️ Processo já finalizado"
        fi
        
        rm -f "$HCIDUMP_PID_FILE"
    else
        echo "ℹ️ Nenhuma captura ativa"
    fi
}

# Análise de tráfego capturado
analyze_captured_traffic() {
    local pcap_file="$1"
    local output_file="${2:-${pcap_file%.pcap}_analysis.txt}"
    
    if [[ ! -f "$pcap_file" ]]; then
        echo "❌ Arquivo de captura não encontrado: $pcap_file"
        return 1
    fi
    
    echo "🔍 Analisando tráfego capturado..."
    
    # Análise básica com tshark se disponível
    if command -v tshark >/dev/null 2>&1; then
        echo "=== ANÁLISE DE TRÁFEGO BLUETOOTH ===" > "$output_file"
        echo "Arquivo: $pcap_file" >> "$output_file"
        echo "Timestamp: $(date)" >> "$output_file"
        echo "" >> "$output_file"
        
        # Estatísticas gerais
        echo "=== ESTATÍSTICAS GERAIS ===" >> "$output_file"
        tshark -r "$pcap_file" -q -z io,stat,0 >> "$output_file" 2>/dev/null || echo "Erro na análise" >> "$output_file"
        echo "" >> "$output_file"
        
        # Protocolos detectados
        echo "=== PROTOCOLOS DETECTADOS ===" >> "$output_file"
        tshark -r "$pcap_file" -q -z phs >> "$output_file" 2>/dev/null || echo "Erro na análise de protocolos" >> "$output_file"
        echo "" >> "$output_file"
        
        # Conversações
        echo "=== CONVERSAÇÕES ===" >> "$output_file"
        tshark -r "$pcap_file" -q -z conv,eth >> "$output_file" 2>/dev/null || echo "Erro na análise de conversações" >> "$output_file"
        
        echo "✅ Análise salva em: $output_file"
    else
        # Análise básica com hexdump
        echo "Usando análise básica (hexdump)..."
        echo "=== ANÁLISE BÁSICA ===" > "$output_file"
        echo "Arquivo: $pcap_file" >> "$output_file"
        echo "Tamanho: $(stat -c%s "$pcap_file" 2>/dev/null || echo "unknown") bytes" >> "$output_file"
        echo "Primeira análise hexadecimal:" >> "$output_file"
        hexdump -C "$pcap_file" | head -20 >> "$output_file" 2>/dev/null || echo "Erro na análise" >> "$output_file"
    fi
    
    return 0
}

# Verificar se dispositivo está alcançável
is_device_reachable() {
    local target="$1"
    local timeout="${2:-5}"
    
    validate_mac_address "$target" || return 1
    
    l2ping -c 1 -t "$timeout" "$target" >/dev/null 2>&1
}

# Obter informações detalhadas do dispositivo
get_device_info() {
    local target="$1"
    
    validate_mac_address "$target" || return 1
    
    echo "=== Device Information for $target ==="
    
    # Nome
    local name=$(timeout 10 hcitool name "$target" 2>/dev/null || echo "Unknown")
    echo "Name: $name"
    
    # Informações de classe
    local info=$(timeout 10 hcitool info "$target" 2>/dev/null)
    if [[ -n "$info" ]]; then
        echo "$info"
    else
        echo "Extended info not available"
    fi
    
    # Clock offset
    local clock=$(timeout 10 hcitool clock "$target" 2>/dev/null || echo "Unknown")
    echo "Clock: $clock"
    
    return 0
}

# Monitoramento contínuo de dispositivos
monitor_bluetooth_activity() {
    local duration="${1:-60}"
    local output_file="${2:-/tmp/bt_monitor_$$.log}"
    
    echo "👁️ Iniciando monitoramento Bluetooth por ${duration}s..."
    
    # Combinar múltiplas técnicas de monitoramento
    {
        echo "=== BLUETOOTH ACTIVITY MONITOR ==="
        echo "Started: $(date)"
        echo "Duration: ${duration}s"
        echo ""
        
        # Monitor 1: Scanning contínuo
        while true; do
            echo "[$(date '+%H:%M:%S')] Scanning..."
            timeout 10 hcitool inq 2>/dev/null | while read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([0-9A-F:]{17}) ]]; then
                    local mac="${BASH_REMATCH[1]}"
                    local name=$(timeout 5 hcitool name "$mac" 2>/dev/null || echo "Unknown")
                    echo "[$(date '+%H:%M:%S')] Device detected: $mac ($name)"
                fi
            done
            sleep 10
        done &
        
        local monitor_pid=$!
        
        # Aguardar duração especificada
        sleep "$duration"
        
        # Finalizar monitoramento
        kill $monitor_pid 2>/dev/null || true
        echo ""
        echo "=== MONITORING COMPLETED ==="
        echo "Finished: $(date)"
        
    } | tee "$output_file"
    
    echo "✅ Monitoramento concluído: $output_file"
    return 0
}

# Teste de força de sinal
signal_strength_test() {
    local target="$1"
    local samples="${2:-10}"
    
    validate_mac_address "$target" || return 1
    
    echo "📶 Testando força de sinal para $target..."
    
    local total_rssi=0
    local successful_pings=0
    
    for ((i=1; i<=samples; i++)); do
        echo -n "Sample $i/$samples: "
        
        # Usar l2ping para testar conectividade e medir tempo
        if local ping_result=$(l2ping -c 1 -t 5 "$target" 2>/dev/null); then
            local ping_time=$(echo "$ping_result" | grep "ping time" | awk '{print $4}')
            echo "✅ ${ping_time}ms"
            ((successful_pings++))
        else
            echo "❌ No response"
        fi
        
        sleep 1
    done
    
    echo ""
    echo "📊 Resultados:"
    echo "  Amostras: $samples"
    echo "  Sucessos: $successful_pings"
    echo "  Taxa de sucesso: $((successful_pings * 100 / samples))%"
    
    if [[ $successful_pings -gt 0 ]]; then
        echo "  🟢 Sinal: BOM"
    elif [[ $successful_pings -gt $((samples / 2)) ]]; then
        echo "  🟡 Sinal: MÉDIO"
    else
        echo "  🔴 Sinal: FRACO"
    fi
    
    return 0
} 