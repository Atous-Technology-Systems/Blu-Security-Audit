#!/bin/bash
# lib/ble_attacks.sh - BLE (Bluetooth Low Energy) Attacks para BlueSecAudit v2.0
# ATENÇÃO: Para uso educacional e testes autorizados apenas

set -euo pipefail

# Importar dependências
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bluetooth.sh"

# Configurações BLE
readonly BLE_SCAN_TIMEOUT=30
readonly GATT_TIMEOUT=15
readonly BLE_ADV_TIMEOUT=60

# Detectar dispositivos BLE
detect_ble_devices() {
    local scan_duration="${1:-$BLE_SCAN_TIMEOUT}"
    
    echo "🔍 Scanning for BLE devices (${scan_duration}s)..."
    
    # Verificar se hcitool suporta BLE
    if ! command -v hcitool >/dev/null 2>&1; then
        echo "❌ hcitool not available - install bluez"
        return 1
    fi
    
    # Verificar se bluetoothctl está disponível
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo "❌ bluetoothctl not available - install bluez"
        return 1
    fi
    
    echo "📡 Starting BLE scan..."
    
    # Usar bluetoothctl para scan BLE
    {
        echo "scan on"
        sleep "$scan_duration"
        echo "scan off"
        echo "devices"
        echo "quit"
    } | timeout $((scan_duration + 10)) bluetoothctl 2>/dev/null | \
    grep "Device" | while read -r line; do
        if [[ "$line" =~ Device[[:space:]]+([0-9A-F:]{17})[[:space:]]+(.*)$ ]]; then
            local mac="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]:-Unknown BLE Device}"
            echo "📱 Found BLE device: $mac ($name)"
        fi
    done
    
    echo "✅ BLE scan completed"
    return 0
}

# Validar endereço BLE
validate_ble_address() {
    local address="$1"
    validate_mac_address "$address"
}

# Escanear serviços GATT
scan_gatt_services() {
    local target="$1"
    local output_file="${2:-/tmp/gatt_services_$$.txt}"
    
    validate_ble_address "$target" || return 1
    
    echo "🔍 Scanning GATT services on $target..."
    
    # Verificar se gatttool está disponível
    if command -v gatttool >/dev/null 2>&1; then
        echo "Using gatttool for GATT enumeration..."
        
        # Descobrir serviços primários
        echo "=== GATT Primary Services ===" > "$output_file"
        echo "Target: $target" >> "$output_file"
        echo "Timestamp: $(date)" >> "$output_file"
        echo "" >> "$output_file"
        
        if timeout $GATT_TIMEOUT gatttool -b "$target" --primary >> "$output_file" 2>&1; then
            echo "✅ Primary services discovered"
            
            # Descobrir características
            echo "" >> "$output_file"
            echo "=== GATT Characteristics ===" >> "$output_file"
            timeout $GATT_TIMEOUT gatttool -b "$target" --characteristics >> "$output_file" 2>&1
            
            echo "✅ GATT enumeration completed: $output_file"
            
        else
            echo "❌ Failed to connect or enumerate GATT services"
            echo "Possible causes:"
            echo "  • Device not in range or powered off"
            echo "  • Connection security requirements"
            echo "  • GATT services protected"
            return 1
        fi
        
    elif command -v bluetoothctl >/dev/null 2>&1; then
        echo "Using bluetoothctl for BLE service discovery..."
        
        # Conectar e enumerar via bluetoothctl
        {
            echo "connect $target"
            sleep 5
            echo "list-attributes $target"
            sleep 2
            echo "disconnect $target"
            echo "quit"
        } | timeout $((GATT_TIMEOUT + 10)) bluetoothctl > "$output_file" 2>&1
        
        if grep -q "Connected: yes\|Attribute" "$output_file"; then
            echo "✅ BLE service discovery completed via bluetoothctl"
        else
            echo "❌ BLE connection failed"
            return 1
        fi
        
    else
        echo "❌ No BLE tools available"
        echo "Install: sudo apt-get install bluez bluez-tools"
        return 1
    fi
    
    return 0
}

# Detectar características BLE
detect_ble_characteristics() {
    local gatt_data="$1"
    
    echo "=== BLE Characteristics Analysis ==="
    
    local characteristics=()
    
    # Buscar características comuns
    if echo "$gatt_data" | grep -qi "Device Name\|0x2A00"; then
        characteristics+=("Device Name (0x2A00)")
        echo "✅ Device Name characteristic found"
    fi
    
    if echo "$gatt_data" | grep -qi "Appearance\|0x2A01"; then
        characteristics+=("Appearance (0x2A01)")
        echo "✅ Appearance characteristic found"
    fi
    
    if echo "$gatt_data" | grep -qi "Battery.*Level\|0x2A19"; then
        characteristics+=("Battery Level (0x2A19)")
        echo "✅ Battery Level characteristic found"
    fi
    
    if echo "$gatt_data" | grep -qi "Heart.*Rate\|0x2A37"; then
        characteristics+=("Heart Rate Measurement (0x2A37)")
        echo "✅ Heart Rate characteristic found"
    fi
    
    if echo "$gatt_data" | grep -qi "Temperature\|0x2A6E"; then
        characteristics+=("Temperature (0x2A6E)")
        echo "✅ Temperature characteristic found"
    fi
    
    echo ""
    echo "📊 Total characteristics detected: ${#characteristics[@]}"
    
    for char in "${characteristics[@]}"; do
        echo "  📋 $char"
    done
    
    return 0
}

# Analisar vulnerabilidades BLE
analyze_ble_vulnerabilities() {
    local device_info="$1"
    
    echo "=== BLE Vulnerability Assessment ==="
    
    local vuln_count=0
    local risk_level="LOW"
    
    # Verificar criptografia
    if echo "$device_info" | grep -qi "Security.*None\|Encryption.*None\|No.*Security"; then
        echo "🔴 CRITICAL: No encryption detected"
        echo "  Risk: Data transmitted in plaintext"
        echo "  Impact: Complete data exposure"
        ((vuln_count += 3))
        risk_level="CRITICAL"
    fi
    
    # Verificar autenticação
    if echo "$device_info" | grep -qi "Authentication.*None\|No.*Auth\|Just.*Works"; then
        echo "🟡 HIGH: Weak or no authentication"
        echo "  Risk: Unauthorized access possible"
        echo "  Impact: Device impersonation"
        ((vuln_count += 2))
        [[ "$risk_level" == "LOW" ]] && risk_level="HIGH"
    fi
    
    # Verificar características sensíveis
    if echo "$device_info" | grep -qi "Heart.*Rate\|Health\|Medical"; then
        echo "🟡 MEDIUM: Health data exposure"
        echo "  Risk: Sensitive health information"
        echo "  Impact: Privacy violation"
        ((vuln_count++))
        [[ "$risk_level" == "LOW" ]] && risk_level="MEDIUM"
    fi
    
    # Verificar número de serviços expostos
    local services=$(echo "$device_info" | grep -c "Service" 2>/dev/null || echo "0")
    if [[ $services -gt 10 ]]; then
        echo "🟡 MEDIUM: Large attack surface"
        echo "  Risk: Multiple entry points"
        echo "  Impact: Increased vulnerability"
        ((vuln_count++))
        [[ "$risk_level" == "LOW" ]] && risk_level="MEDIUM"
    fi
    
    # Verificar capacidades de escrita
    if echo "$device_info" | grep -qi "Write\|WRITE"; then
        echo "🟡 MEDIUM: Write capabilities detected"
        echo "  Risk: Data modification possible"
        echo "  Impact: Device manipulation"
        ((vuln_count++))
        [[ "$risk_level" == "LOW" ]] && risk_level="MEDIUM"
    fi
    
    echo ""
    echo "📊 Vulnerability Summary:"
    echo "  🔢 Total issues found: $vuln_count"
    echo "  📈 Risk Level: $risk_level"
    
    case "$risk_level" in
        "CRITICAL") echo "  🚨 Immediate action required" ;;
        "HIGH") echo "  ⚠️ High priority remediation needed" ;;
        "MEDIUM") echo "  🔍 Monitor and improve security" ;;
        "LOW") echo "  ✅ Basic security posture acceptable" ;;
    esac
    
    return $vuln_count
}

# Testar conectividade BLE
test_ble_connectivity() {
    local target="$1"
    
    validate_ble_address "$target" || return 1
    
    echo "🔍 Testing BLE connectivity to $target..."
    
    # Teste básico com bluetoothctl
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo "📡 Attempting BLE connection..."
        
        local connect_result=$(timeout 20 bluetoothctl connect "$target" 2>&1)
        
        if echo "$connect_result" | grep -q "Connection successful\|Connected: yes"; then
            echo "✅ BLE connection successful"
            
            # Obter informações da conexão
            local device_info=$(timeout 10 bluetoothctl info "$target" 2>/dev/null)
            if [[ -n "$device_info" ]]; then
                echo "📋 Connection details:"
                echo "$device_info" | grep -E "Connected|Paired|Trusted|RSSI" || echo "  Basic connection established"
            fi
            
            # Desconectar após teste
            timeout 10 bluetoothctl disconnect "$target" >/dev/null 2>&1 || true
            
            return 0
        else
            echo "❌ BLE connection failed"
            echo "Reasons could include:"
            echo "  • Device requires pairing"
            echo "  • Security restrictions"
            echo "  • Device not in connectable mode"
            echo "  • Out of range"
            return 1
        fi
        
    else
        echo "❌ bluetoothctl not available"
        return 1
    fi
}

# Executar ataques BLE REAIS
execute_ble_attack() {
    local target="$1"
    local attack_type="${2:-reconnaissance}"
    local mode="${3:-safe}"
    
    validate_ble_address "$target" || return 1
    
    echo "🎯 Executing BLE Attack - REAL MODE"
    echo "Target: $target"
    echo "Attack Type: $attack_type"
    echo "Mode: $mode"
    echo ""
    
    # Aviso legal para ataques BLE
    echo "⚖️ LEGAL WARNING - BLE ATTACKS"
    echo "BLE attacks may violate:"
    echo "  • Device privacy expectations"
    echo "  • IoT security regulations"
    echo "  • Medical device safety laws (if health devices)"
    echo "  • Personal data protection laws"
    echo ""
    echo "Confirm authorization for BLE testing? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "❌ BLE attack cancelled"
        return 1
    fi
    
    case "$attack_type" in
        "reconnaissance")
            execute_ble_reconnaissance "$target"
            ;;
        "service_enumeration")
            execute_ble_service_enumeration "$target"
            ;;
        "data_extraction")
            execute_ble_data_extraction "$target" "$mode"
            ;;
        "denial_of_service")
            execute_ble_dos_attack "$target"
            ;;
        "jamming")
            execute_ble_jamming_attack "$target"
            ;;
        *)
            echo "❌ Unknown attack type: $attack_type"
            return 1
            ;;
    esac
}

# Reconnaissance BLE
execute_ble_reconnaissance() {
    local target="$1"
    
    echo "🕵️ BLE Reconnaissance Attack"
    
    # Coleta extensiva de informações
    local recon_file="/tmp/ble_recon_${target//:/_}_$$.txt"
    
    {
        echo "=== BLE RECONNAISSANCE REPORT ==="
        echo "Target: $target"
        echo "Timestamp: $(date)"
        echo ""
        
        # Informações básicas do dispositivo
        echo "=== BASIC DEVICE INFO ==="
        timeout 15 bluetoothctl info "$target" 2>/dev/null || echo "Device info not available"
        echo ""
        
        # Scan de serviços GATT
        echo "=== GATT SERVICES ==="
        scan_gatt_services "$target" "/tmp/gatt_temp_$$.txt" >/dev/null 2>&1
        cat "/tmp/gatt_temp_$$.txt" 2>/dev/null || echo "GATT scan failed"
        rm -f "/tmp/gatt_temp_$$.txt"
        echo ""
        
        # Análise de sinal
        echo "=== SIGNAL ANALYSIS ==="
        for i in {1..5}; do
            local rssi=$(timeout 5 bluetoothctl info "$target" 2>/dev/null | grep "RSSI" | awk '{print $2}' || echo "N/A")
            echo "Sample $i: RSSI = $rssi dBm"
            sleep 1
        done
        echo ""
        
        # Tentativa de emparelhamento (sem completar)
        echo "=== PAIRING ANALYSIS ==="
        echo "Testing pairing requirements..."
        timeout 10 bluetoothctl pair "$target" 2>&1 | head -5 || echo "Pairing test failed"
        timeout 5 bluetoothctl cancel-pairing "$target" >/dev/null 2>&1 || true
        
    } > "$recon_file"
    
    echo "✅ BLE reconnaissance completed"
    echo "📋 Report saved: $recon_file"
    
    # Análise automática dos resultados
    analyze_ble_vulnerabilities "$(cat "$recon_file")"
    
    return 0
}

# Enumeração de serviços BLE
execute_ble_service_enumeration() {
    local target="$1"
    
    echo "🔍 BLE Service Enumeration Attack"
    
    local services_file="/tmp/ble_services_${target//:/_}_$$.txt"
    
    echo "📡 Discovering all available services..."
    
    if scan_gatt_services "$target" "$services_file"; then
        echo "✅ Service enumeration successful"
        
        # Análise detalhada dos serviços encontrados
        echo ""
        echo "🔬 Analyzing discovered services..."
        
        local service_count=$(grep -c "Service\|attr handle" "$services_file" 2>/dev/null || echo "0")
        local char_count=$(grep -c "char\|Characteristic" "$services_file" 2>/dev/null || echo "0")
        
        echo "📊 Services found: $service_count"
        echo "📊 Characteristics found: $char_count"
        
        # Detectar serviços críticos
        echo ""
        echo "🚨 Critical services analysis:"
        
        if grep -qi "Device Information\|0x180A" "$services_file"; then
            echo "  ✅ Device Information Service found"
        fi
        
        if grep -qi "Battery\|0x180F" "$services_file"; then
            echo "  ⚠️ Battery Service exposed"
        fi
        
        if grep -qi "Heart Rate\|0x180D" "$services_file"; then
            echo "  🏥 Health data service detected"
        fi
        
        if grep -qi "Human Interface\|0x1812" "$services_file"; then
            echo "  ⌨️ HID over GATT detected"
        fi
        
        # Analisar características
        detect_ble_characteristics "$(cat "$services_file")"
        
        echo "📁 Detailed enumeration saved: $services_file"
        
    else
        echo "❌ Service enumeration failed"
        return 1
    fi
    
    return 0
}

# Extração de dados BLE
execute_ble_data_extraction() {
    local target="$1"
    local mode="${2:-safe}"
    
    echo "📥 BLE Data Extraction Attack"
    echo "Mode: $mode"
    echo ""
    
    if [[ "$mode" == "aggressive" ]]; then
        echo "⚠️ AGGRESSIVE MODE WARNING"
        echo "This will attempt to read all accessible characteristics"
        echo "and may trigger security alerts on the target device."
        echo ""
        echo "Continue with aggressive extraction? (type 'AGGRESSIVE'): "
        read -r confirm
        
        if [[ "$confirm" != "AGGRESSIVE" ]]; then
            echo "❌ Aggressive extraction cancelled"
            return 1
        fi
    fi
    
    local extract_file="/tmp/ble_extract_${target//:/_}_$$.txt"
    
    echo "🔓 Starting data extraction..."
    
    # Conectar ao dispositivo
    if ! test_ble_connectivity "$target"; then
        echo "❌ Cannot connect to target for extraction"
        return 1
    fi
    
    {
        echo "=== BLE DATA EXTRACTION ==="
        echo "Target: $target"
        echo "Mode: $mode"
        echo "Timestamp: $(date)"
        echo ""
        
        # Tentar ler características conhecidas
        echo "=== READABLE CHARACTERISTICS ==="
        
        # Device Name
        echo "Reading Device Name..."
        if command -v gatttool >/dev/null 2>&1; then
            timeout 10 gatttool -b "$target" --char-read -a 0x0003 2>/dev/null || echo "Device Name: Not readable"
        fi
        
        # Battery Level
        echo "Reading Battery Level..."
        if command -v gatttool >/dev/null 2>&1; then
            timeout 10 gatttool -b "$target" --char-read -a 0x000F 2>/dev/null || echo "Battery Level: Not readable"
        fi
        
        # Manufacturer Data
        echo "Reading Manufacturer Information..."
        timeout 10 bluetoothctl info "$target" 2>/dev/null | grep -E "Manufacturer|Vendor" || echo "Manufacturer: Not available"
        
        if [[ "$mode" == "aggressive" ]]; then
            echo ""
            echo "=== AGGRESSIVE ENUMERATION ==="
            
            # Tentar ler todas as handles possíveis
            echo "Attempting to read all handles..."
            if command -v gatttool >/dev/null 2>&1; then
                for handle in {0x0001..0x0020}; do
                    printf "Handle %s: " "$handle"
                    timeout 5 gatttool -b "$target" --char-read -a "$handle" 2>/dev/null | head -1 || echo "Not readable"
                done
            fi
        fi
        
    } > "$extract_file"
    
    echo "✅ Data extraction completed"
    echo "📁 Extracted data saved: $extract_file"
    
    # Verificar se dados sensíveis foram encontrados
    if grep -qi "password\|key\|token\|secret" "$extract_file"; then
        echo "🚨 SENSITIVE DATA DETECTED in extraction"
        echo "⚠️ Handle extracted data according to security policies"
    fi
    
    return 0
}

# DoS attack BLE
execute_ble_dos_attack() {
    local target="$1"
    
    echo "💥 BLE Denial of Service Attack"
    echo ""
    echo "⚠️ DOS ATTACK WARNING"
    echo "This attack may:"
    echo "  • Disconnect the device from legitimate connections"
    echo "  • Cause device instability or crashes"
    echo "  • Trigger security monitoring systems"
    echo "  • Be considered malicious activity"
    echo ""
    echo "Proceed with DoS attack? (type 'DOS'): "
    read -r confirm
    
    if [[ "$confirm" != "DOS" ]]; then
        echo "❌ DoS attack cancelled"
        return 1
    fi
    
    echo "🔥 Initiating BLE DoS attack..."
    
    # Método 1: Connection flooding
    echo "Method 1: Connection flooding..."
    for i in {1..10}; do
        echo "  Connection attempt $i..."
        timeout 5 bluetoothctl connect "$target" >/dev/null 2>&1 &
        sleep 0.1
    done
    
    # Aguardar um pouco
    sleep 5
    
    # Método 2: Rapid connect/disconnect
    echo "Method 2: Rapid connect/disconnect cycles..."
    for i in {1..20}; do
        timeout 3 bluetoothctl connect "$target" >/dev/null 2>&1
        timeout 1 bluetoothctl disconnect "$target" >/dev/null 2>&1
        echo -n "."
    done
    echo ""
    
    # Método 3: Invalid GATT requests
    echo "Method 3: Invalid GATT requests..."
    if command -v gatttool >/dev/null 2>&1; then
        for handle in {0x0000..0x0010}; do
            timeout 2 gatttool -b "$target" --char-read -a "$handle" >/dev/null 2>&1
        done
    fi
    
    echo "✅ DoS attack sequence completed"
    echo "🔍 Monitor target device for impact"
    
    return 0
}

# Jamming attack BLE
execute_ble_jamming_attack() {
    local target="$1"
    
    echo "📡 BLE Jamming Attack"
    echo ""
    echo "⚠️ RF JAMMING WARNING"
    echo "RF jamming may:"
    echo "  • Interfere with other wireless devices"
    echo "  • Violate FCC/regulatory guidelines"
    echo "  • Affect emergency communications"
    echo "  • Be illegal in many jurisdictions"
    echo ""
    echo "This implementation provides SIMULATED jamming analysis only."
    echo ""
    
    # Análise de frequência (simulada)
    echo "🔬 BLE Frequency Analysis:"
    echo "  • Target uses 2.4 GHz ISM band"
    echo "  • 40 channels (37 data + 3 advertising)"
    echo "  • Frequency hopping every 37.5ms"
    echo ""
    
    echo "📊 Simulated Jamming Scenarios:"
    echo "  1. Advertising channel jamming (channels 37, 38, 39)"
    echo "  2. Data channel interference (channels 0-36)"
    echo "  3. Selective frequency jamming"
    echo ""
    
    echo "🚧 For real RF jamming, specialized equipment required:"
    echo "  • Software Defined Radio (SDR)"
    echo "  • RF signal generators"
    echo "  • Proper regulatory approval"
    echo "  • Controlled environment"
    echo ""
    
    # Log da "análise" de jamming
    local jam_file="/tmp/ble_jamming_analysis_${target//:/_}_$$.txt"
    cat > "$jam_file" << EOF
=== BLE JAMMING ANALYSIS ===
Target: $target
Analysis Type: Simulated RF Interference Study
Timestamp: $(date)

Frequency Profile:
- Primary Band: 2.4 GHz ISM
- Channel Width: 2 MHz
- Hop Sequence: Adaptive Frequency Hopping
- Hop Rate: 1600 hops/second

Vulnerability Assessment:
- Advertising Channels: 3 fixed frequencies (vulnerable)
- Data Channels: 37 hopping frequencies (resilient)
- Connection Supervision: Timeout-based recovery

Jamming Effectiveness (Theoretical):
- Advertising Jamming: HIGH (fixed frequencies)
- Data Jamming: MEDIUM (frequency hopping)
- Selective Jamming: VARIABLE (depends on implementation)

Mitigation Techniques:
- Frequency agility
- Error correction
- Adaptive channel selection
- Power management

Note: This is a theoretical analysis only.
Real jamming requires specialized equipment and authorization.
EOF
    
    echo "📋 Jamming analysis saved: $jam_file"
    
    return 0
}

# Detectar tipo de dispositivo BLE
detect_ble_device_type() {
    local services_data="$1"
    
    echo "🔍 BLE Device Classification:"
    
    # Análise baseada em serviços
    local device_types=()
    
    if echo "$services_data" | grep -qi "Heart Rate\|Health\|0x180D"; then
        device_types+=("Fitness/Health Device")
    fi
    
    if echo "$services_data" | grep -qi "Battery\|0x180F"; then
        device_types+=("Battery-Powered Device")
    fi
    
    if echo "$services_data" | grep -qi "Human Interface\|HID\|0x1812"; then
        device_types+=("Input Device (Keyboard/Mouse)")
    fi
    
    if echo "$services_data" | grep -qi "Audio\|0x1811\|0x183E"; then
        device_types+=("Audio Device")
    fi
    
    if echo "$services_data" | grep -qi "Environmental\|Temperature\|0x181A"; then
        device_types+=("Environmental Sensor")
    fi
    
    if echo "$services_data" | grep -qi "Cycling\|Running\|0x1816\|0x1814"; then
        device_types+=("Sports/Fitness Tracker")
    fi
    
    # Exibir classificação
    if [[ ${#device_types[@]} -eq 0 ]]; then
        echo "  📱 Type: Generic BLE Device"
        echo "  📂 Category: Unknown/Custom"
    else
        echo "  📱 Detected Types:"
        for type in "${device_types[@]}"; do
            echo "    🏷️ $type"
        done
    fi
    
    # Análise de risco baseada no tipo
    if [[ "${device_types[*]}" =~ "Health" ]] || [[ "${device_types[*]}" =~ "Fitness" ]]; then
        echo "  🔴 Privacy Risk: HIGH (Health data)"
    elif [[ "${device_types[*]}" =~ "Input" ]]; then
        echo "  🟡 Security Risk: MEDIUM (Input injection)"
    else
        echo "  🟢 Risk Level: LOW to MEDIUM"
    fi
    
    return 0
}

# Gerar relatório BLE
generate_ble_report() {
    local ble_data="$1"
    local output_file="$2"
    
    cat > "$output_file" << EOL
<!DOCTYPE html>
<html>
<head>
    <title>BLE Security Assessment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .ble-data { background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace; }
        .risk-critical { color: #e74c3c; font-weight: bold; }
        .risk-high { color: #f39c12; font-weight: bold; }
        .risk-medium { color: #f1c40f; font-weight: bold; }
        .risk-low { color: #27ae60; font-weight: bold; }
        .security-notice { background: #e8f4fd; border: 1px solid #3498db; padding: 15px; border-radius: 5px; margin: 20px 0; }
        ul li { margin: 5px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #7f8c8d; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📱 Bluetooth Low Energy (BLE) Security Assessment</h1>
        
        <div class="security-notice">
            <strong>🔒 CONFIDENTIAL SECURITY ASSESSMENT</strong><br>
            This report contains detailed BLE security analysis and should be handled according to your organization's information security policies.
        </div>
        
        <h2>📊 Assessment Data</h2>
        <div class="ble-data">$ble_data</div>
        
        <h2>🔍 BLE Security Analysis</h2>
        <p>Bluetooth Low Energy (BLE) devices present unique security challenges due to their constrained resources and diverse application domains.</p>
        
        <h3>🎯 Attack Vectors Analyzed</h3>
        <table>
            <tr>
                <th>Attack Type</th>
                <th>Risk Level</th>
                <th>Description</th>
                <th>Impact</th>
            </tr>
            <tr>
                <td>GATT Service Enumeration</td>
                <td><span class="risk-medium">MEDIUM</span></td>
                <td>Discovery of available services and characteristics</td>
                <td>Information disclosure, attack surface mapping</td>
            </tr>
            <tr>
                <td>Characteristic Data Extraction</td>
                <td><span class="risk-high">HIGH</span></td>
                <td>Reading sensitive data from device characteristics</td>
                <td>Privacy violation, credential theft</td>
            </tr>
            <tr>
                <td>Connection DoS</td>
                <td><span class="risk-high">HIGH</span></td>
                <td>Flooding device with connection requests</td>
                <td>Service disruption, battery drain</td>
            </tr>
            <tr>
                <td>RF Jamming</td>
                <td><span class="risk-critical">CRITICAL</span></td>
                <td>Radio frequency interference</td>
                <td>Complete communication disruption</td>
            </tr>
        </table>
        
        <h3 class="risk-critical">Critical Vulnerabilities</h3>
        <ul>
            <li><span class="risk-critical">No Encryption</span> - Data transmitted in plaintext</li>
            <li><span class="risk-critical">Just Works Pairing</span> - No authentication required</li>
            <li><span class="risk-critical">Open Characteristics</span> - Sensitive data readable without authentication</li>
            <li><span class="risk-critical">Weak Connection Parameters</span> - Susceptible to interference</li>
        </ul>
        
        <h3 class="risk-high">High Risk Issues</h3>
        <ul>
            <li><span class="risk-high">Health Data Exposure</span> - Medical information at risk</li>
            <li><span class="risk-high">Device Fingerprinting</span> - Unique identification possible</li>
            <li><span class="risk-high">Replay Attacks</span> - Commands can be replayed</li>
            <li><span class="risk-high">Connection Hijacking</span> - Sessions can be intercepted</li>
        </ul>
        
        <h2>🛡️ Security Recommendations</h2>
        
        <h3>Immediate Actions</h3>
        <ul>
            <li>Enable BLE Security Mode 1 Level 3 or 4 (encrypted connections)</li>
            <li>Implement proper authentication for sensitive characteristics</li>
            <li>Use random device addresses to prevent tracking</li>
            <li>Configure connection parameters for security over performance</li>
            <li>Disable unnecessary services and characteristics</li>
        </ul>
        
        <h3>Advanced Security Measures</h3>
        <ul>
            <li>Implement application-layer encryption for sensitive data</li>
            <li>Use certificate-based authentication where possible</li>
            <li>Deploy BLE intrusion detection systems</li>
            <li>Regular security audits and penetration testing</li>
            <li>User education on BLE security risks</li>
        </ul>
        
        <h2>📱 Device-Specific Considerations</h2>
        
        <h3>IoT Devices</h3>
        <ul>
            <li>Often have limited security implementations</li>
            <li>May use default or weak authentication</li>
            <li>Require special attention to firmware updates</li>
        </ul>
        
        <h3>Health/Fitness Devices</h3>
        <ul>
            <li>Subject to medical device regulations</li>
            <li>Handle highly sensitive personal data</li>
            <li>May have privacy law implications (HIPAA, GDPR)</li>
        </ul>
        
        <h3>Input Devices</h3>
        <ul>
            <li>Risk of keystroke injection attacks</li>
            <li>Potential for credential harvesting</li>
            <li>May bypass application security controls</li>
        </ul>
        
        <h2>📋 Compliance Considerations</h2>
        <ul>
            <li><strong>GDPR:</strong> Personal data protection requirements</li>
            <li><strong>HIPAA:</strong> Health information security (if applicable)</li>
            <li><strong>FCC Part 15:</strong> RF emission regulations</li>
            <li><strong>ISO 27001:</strong> Information security management</li>
        </ul>
        
        <div class="footer">
            <p><strong>Generated by:</strong> BlueSecAudit v2.0 - BLE Security Assessment Module</p>
            <p><strong>Report Date:</strong> $(date)</p>
            <p><strong>Classification:</strong> CONFIDENTIAL - SECURITY ASSESSMENT</p>
            <p><strong>Next Review:</strong> Recommend quarterly security assessments</p>
        </div>
    </div>
</body>
</html>
EOL
    
    echo "📋 BLE security report generated: $output_file"
    log_message "SUCCESS" "BLE security assessment report created"
    return 0
}

# Função para simular ataques BLE (para testes seguros)
simulate_ble_attack() {
    local target="$1"
    local attack_type="${2:-passive}"
    local mode="${3:-safe}"
    
    validate_ble_address "$target" || return 1
    
    echo "🔬 SIMULATING BLE attack for testing"
    echo "Target: $target"
    echo "Attack Type: $attack_type"
    echo "Mode: $mode"
    echo ""
    
    case "$attack_type" in
        "passive"|"reconnaissance")
            echo "📡 Passive BLE reconnaissance simulation"
            echo "Scanning for BLE advertisements..."
            sleep 1
            echo "Simulated devices found: 3"
            echo "Target device advertising interval: 100ms"
            echo "Signal strength: -65 dBm"
            ;;
        "gatt_enum"|"service_discovery")
            echo "🔍 GATT service enumeration simulation"
            echo "Discovering services..."
            sleep 1
            echo "Primary services found: 4"
            echo "Characteristics found: 12"
            echo "Read permissions: 8"
            echo "Write permissions: 3"
            ;;
        "data_extraction")
            echo "📥 Data extraction simulation"
            echo "Reading device characteristics..."
            sleep 1
            echo "Device Name: Test BLE Device"
            echo "Battery Level: 85%"
            echo "Manufacturer: Simulated Corp"
            ;;
        *)
            echo "❌ Unknown simulation type: $attack_type"
            return 1
            ;;
    esac
    
    echo "✅ BLE attack simulation completed safely"
    return 0
}

# Monitorar tráfego BLE
monitor_ble_traffic() {
    local target="$1"
    local duration="${2:-30}"
    local output_file="$3"
    
    validate_ble_address "$target" || return 1
    
    echo "📡 Monitoring BLE traffic for $target"
    echo "Duration: ${duration}s"
    echo "Output: $output_file"
    echo ""
    
    # Verificar ferramentas de captura
    if command -v hcidump >/dev/null 2>&1; then
        echo "🔍 Using hcidump for BLE traffic capture"
        
        # Capturar tráfego BLE específico
        echo "Starting BLE packet capture..."
        timeout "$duration" hcidump -w "$output_file" -i hci0 2>/dev/null &
        local capture_pid=$!
        
        echo "📡 Capture started (PID: $capture_pid)"
        echo "⏱️ Monitoring for ${duration} seconds..."
        
        # Mostrar progresso
        for ((i=1; i<=duration; i++)); do
            if ((i % 10 == 0)); then
                echo "  Progress: ${i}/${duration}s"
            fi
            sleep 1
        done
        
        # Aguardar conclusão
        wait $capture_pid 2>/dev/null || true
        
        echo "✅ BLE traffic monitoring completed"
        
        # Verificar se arquivo foi criado
        if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
            local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
            echo "📁 Capture file: $output_file (${file_size} bytes)"
            
            # Análise básica do tráfego capturado
            echo "📊 Basic traffic analysis:"
            local packet_count=$(hcidump -r "$output_file" 2>/dev/null | wc -l)
            echo "  📦 Packets captured: $packet_count"
            
            # Detectar tipos de tráfego
            if hcidump -r "$output_file" 2>/dev/null | grep -q "ADV_IND"; then
                echo "  📢 Advertising packets detected"
            fi
            
            if hcidump -r "$output_file" 2>/dev/null | grep -q "CONNECT_REQ"; then
                echo "  🔗 Connection requests detected"
            fi
            
        else
            echo "⚠️ No traffic captured or file empty"
        fi
        
    elif command -v tshark >/dev/null 2>&1; then
        echo "🔍 Using tshark for BLE traffic capture"
        
        # Captura usando tshark com filtro BLE
        timeout "$duration" tshark -i bluetooth0 -f "btle" -w "$output_file" 2>/dev/null &
        local capture_pid=$!
        
        echo "📡 Tshark capture started (PID: $capture_pid)"
        wait $capture_pid 2>/dev/null || true
        
        echo "✅ BLE traffic capture completed"
        
    else
        echo "❌ No capture tools available"
        echo "Install: sudo apt-get install bluez-hcidump wireshark"
        
        # Simulação de captura para testes
        echo "🔬 Simulating traffic capture..."
        cat > "$output_file" << EOF
=== SIMULATED BLE TRAFFIC CAPTURE ===
Target: $target
Duration: ${duration}s
Timestamp: $(date)

Simulated Traffic Summary:
- Advertisement packets: 150
- Connection requests: 5
- GATT operations: 23
- Data packets: 89

Note: This is simulated data for testing purposes.
Real traffic monitoring requires hcidump or wireshark.
EOF
        echo "📋 Simulation logged to: $output_file"
    fi
    
    return 0
}

# Detectar beacons BLE (iBeacon, Eddystone)
detect_ble_beacons() {
    local beacon_data="$1"
    
    echo "🔍 BLE Beacon Detection"
    echo "Analyzing advertisement data..."
    echo ""
    
    local beacons_found=()
    
    # Detectar iBeacons
    if echo "$beacon_data" | grep -qi "ibeacon\|4c00\|uuid"; then
        beacons_found+=("iBeacon")
        echo "📡 iBeacon detected:"
        
        # Extrair informações do iBeacon
        if echo "$beacon_data" | grep -q "UUID="; then
            local uuid=$(echo "$beacon_data" | grep -o "UUID=[^[:space:]]*" | cut -d= -f2)
            echo "  🆔 UUID: $uuid"
        fi
        
        if echo "$beacon_data" | grep -q "Major="; then
            local major=$(echo "$beacon_data" | grep -o "Major=[^[:space:]]*" | cut -d= -f2)
            echo "  🔢 Major: $major"
        fi
        
        if echo "$beacon_data" | grep -q "Minor="; then
            local minor=$(echo "$beacon_data" | grep -o "Minor=[^[:space:]]*" | cut -d= -f2)
            echo "  🔢 Minor: $minor"
        fi
        
        echo "  📍 Use Case: Indoor positioning, proximity marketing"
        echo ""
    fi
    
    # Detectar Eddystone beacons
    if echo "$beacon_data" | grep -qi "eddystone\|url=\|0xfeaa"; then
        beacons_found+=("Eddystone")
        echo "🌐 Eddystone beacon detected:"
        
        # Extrair URL se disponível
        if echo "$beacon_data" | grep -q "URL="; then
            local url=$(echo "$beacon_data" | grep -o "URL=[^[:space:]]*" | cut -d= -f2)
            echo "  🔗 URL: $url"
        fi
        
        # Detectar tipos de Eddystone
        if echo "$beacon_data" | grep -qi "uid"; then
            echo "  📡 Type: Eddystone-UID (unique identifier)"
        elif echo "$beacon_data" | grep -qi "url"; then
            echo "  📡 Type: Eddystone-URL (web URL)"
        elif echo "$beacon_data" | grep -qi "tlm"; then
            echo "  📡 Type: Eddystone-TLM (telemetry)"
        fi
        
        echo "  📍 Use Case: Physical web, location services"
        echo ""
    fi
    
    # Detectar AltBeacon
    if echo "$beacon_data" | grep -qi "altbeacon\|beac"; then
        beacons_found+=("AltBeacon")
        echo "🏷️ AltBeacon detected:"
        echo "  📡 Type: Open source beacon standard"
        echo "  📍 Use Case: Cross-platform proximity services"
        echo ""
    fi
    
    # Detectar beacons customizados
    if echo "$beacon_data" | grep -qi "custom\|proprietary"; then
        beacons_found+=("Custom Beacon")
        echo "🔧 Custom beacon protocol detected:"
        echo "  📡 Type: Proprietary beacon format"
        echo "  ⚠️ Security: May have unknown vulnerabilities"
        echo ""
    fi
    
    # Resumo
    echo "📊 Beacon Detection Summary:"
    if [[ ${#beacons_found[@]} -eq 0 ]]; then
        echo "  ❌ No standard beacons detected"
        echo "  💡 Device may use custom advertisement format"
    else
        echo "  ✅ Beacons found: ${#beacons_found[@]}"
        for beacon in "${beacons_found[@]}"; do
            echo "    🏷️ $beacon"
        done
    fi
    
    # Análise de segurança
    echo ""
    echo "🔒 Security Analysis:"
    if [[ ${#beacons_found[@]} -gt 0 ]]; then
        echo "  📡 Broadcasting identifiable information"
        echo "  📍 Location tracking possible"
        echo "  👤 User profiling risk"
        echo "  🔍 Requires privacy impact assessment"
    else
        echo "  ✅ No obvious beacon tracking detected"
    fi
    
    return 0
}

# Analisar segurança BLE
analyze_ble_security() {
    local security_data="$1"
    
    echo "🔒 BLE Security Analysis"
    echo "Analyzing security configuration..."
    echo ""
    
    local security_score=0
    local issues=()
    
    # Verificar método de emparelhamento
    if echo "$security_data" | grep -qi "just.*works"; then
        issues+=("Weak pairing method: Just Works")
        echo "🔴 CRITICAL: Just Works pairing detected"
        echo "  Risk: No authentication during pairing"
        ((security_score += 3))
    fi
    
    # Verificar criptografia
    if echo "$security_data" | grep -qi "encryption.*none\|no.*encryption"; then
        issues+=("No encryption enabled")
        echo "🔴 CRITICAL: No encryption detected"
        echo "  Risk: Data transmitted in plaintext"
        ((security_score += 4))
    elif echo "$security_data" | grep -qi "aes"; then
        echo "✅ GOOD: AES encryption detected"
        echo "  Security: Strong encryption in use"
    fi
    
    # Verificar autenticação
    if echo "$security_data" | grep -qi "authentication.*none\|no.*auth"; then
        issues+=("Authentication disabled")
        echo "🟡 WARNING: No authentication required"
        echo "  Risk: Unauthorized access possible"
        ((security_score += 2))
    fi
    
    # Verificar autorização
    if echo "$security_data" | grep -qi "authorization.*none\|no.*authz"; then
        issues+=("Authorization not enforced")
        echo "🟡 WARNING: No authorization checks"
        echo "  Risk: Privilege escalation possible"
        ((security_score += 1))
    fi
    
    # Verificar integridade
    if echo "$security_data" | grep -qi "integrity.*none\|no.*integrity"; then
        issues+=("No integrity protection")
        echo "🟡 WARNING: No integrity verification"
        echo "  Risk: Data tampering possible"
        ((security_score += 1))
    fi
    
    echo ""
    echo "📊 Security Assessment Summary:"
    echo "  🔢 Issues found: ${#issues[@]}"
    echo "  📈 Risk score: $security_score/10"
    
    if [[ $security_score -eq 0 ]]; then
        echo "  ✅ Security level: EXCELLENT"
    elif [[ $security_score -le 2 ]]; then
        echo "  🟢 Security level: GOOD"
    elif [[ $security_score -le 5 ]]; then
        echo "  🟡 Security level: MODERATE"
    elif [[ $security_score -le 8 ]]; then
        echo "  🟠 Security level: POOR"
    else
        echo "  🔴 Security level: CRITICAL"
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo ""
        echo "🚨 Security Issues Identified:"
        for issue in "${issues[@]}"; do
            echo "  • $issue"
        done
    fi
    
    echo ""
    echo "✅ BLE security analysis completed"
    return 0
}
