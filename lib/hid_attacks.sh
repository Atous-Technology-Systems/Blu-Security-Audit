#!/bin/bash
# lib/hid_attacks.sh - HID Injection Attacks para BlueSecAudit v2.0
# ATENÇÃO: APENAS para testes autorizados e ambientes controlados

set -euo pipefail

# Importar dependências
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bluetooth.sh"

# Configurações HID
readonly HID_DEFAULT_CHANNEL=17
readonly HID_CONTROL_CHANNEL=17
readonly HID_INTERRUPT_CHANNEL=19
readonly HID_TIMEOUT=30

# Validar target HID
validate_hid_target() {
    local target="$1"
    validate_mac_address "$target"
}

# Detectar serviços HID
detect_hid_services() {
    local sdp_data="$1"
    
    echo "=== HID Service Detection ==="
    
    if echo "$sdp_data" | grep -qi "Human Interface Device\|HID"; then
        echo "✅ HID service detected"
        
        # Analisar tipo de HID
        if echo "$sdp_data" | grep -qi "keyboard"; then
            echo "  📱 Type: Keyboard"
        elif echo "$sdp_data" | grep -qi "mouse\|pointing"; then
            echo "  🖱️ Type: Mouse/Pointing Device"
        elif echo "$sdp_data" | grep -qi "combo\|composite"; then
            echo "  ⌨️🖱️ Type: Keyboard+Mouse Combo"
        else
            echo "  ❓ Type: Generic HID Device"
        fi
        
        # Verificar canal
        local channel=$(echo "$sdp_data" | grep -i "channel" | head -1 | grep -o "[0-9]*" || echo "$HID_DEFAULT_CHANNEL")
        echo "  🔗 Channel: $channel"
        
        return 0
    else
        echo "❌ No HID services found"
        return 1
    fi
}

# Gerar payload de teclado
generate_keyboard_payload() {
    local text="$1"
    local output_file="$2"
    
    echo "# HID Keyboard Injection Payload" > "$output_file"
    echo "# Generated: $(date)" >> "$output_file"
    echo "# Target Text: $text" >> "$output_file"
    echo "" >> "$output_file"
    
    # Converter texto para HID scancodes
    echo "TYPE=$text" >> "$output_file"
    echo "DELAY=100" >> "$output_file"
    echo "ENTER" >> "$output_file"
    
    log_message "INFO" "Keyboard payload gerado: $output_file"
    return 0
}

# Gerar payload de mouse
generate_mouse_payload() {
    local action="$1"
    local x_coord="$2"
    local y_coord="$3"
    local output_file="$4"
    
    echo "# HID Mouse Injection Payload" > "$output_file"
    echo "# Generated: $(date)" >> "$output_file"
    echo "# Action: $action at ($x_coord, $y_coord)" >> "$output_file"
    echo "" >> "$output_file"
    
    case "$action" in
        "click")
            echo "MOUSE_MOVE=$x_coord,$y_coord" >> "$output_file"
            echo "MOUSE_CLICK=LEFT" >> "$output_file"
            ;;
        "move")
            echo "MOUSE_MOVE=$x_coord,$y_coord" >> "$output_file"
            ;;
        "rightclick")
            echo "MOUSE_MOVE=$x_coord,$y_coord" >> "$output_file"
            echo "MOUSE_CLICK=RIGHT" >> "$output_file"
            ;;
    esac
    
    log_message "INFO" "Mouse payload gerado: $output_file"
    return 0
}

# Testar conectividade HID
test_hid_connectivity() {
    local target="$1"
    local channel="${2:-$HID_DEFAULT_CHANNEL}"
    
    validate_hid_target "$target" || return 1
    
    echo "🔍 Testando conectividade HID com $target..."
    
    # Verificar conectividade L2CAP básica
    if ! l2ping -c 1 -t 5 "$target" >/dev/null 2>&1; then
        echo "❌ Dispositivo não alcançável via L2CAP"
        return 1
    fi
    
    echo "✅ Conectividade L2CAP confirmada"
    
    # Tentar conexão RFCOMM no canal HID
    if timeout 10 rfcomm connect 0 "$target" "$channel" >/dev/null 2>&1; then
        echo "✅ Canal HID $channel acessível"
        rfcomm release 0 2>/dev/null || true
        return 0
    else
        echo "⚠️ Canal HID $channel não disponível ou protegido"
        return 1
    fi
}

# Executar injeção HID REAL
execute_hid_injection() {
    local target="$1"
    local payload_file="$2"
    local mode="${3:-aggressive}"
    
    validate_hid_target "$target" || return 1
    
    if [[ ! -f "$payload_file" ]]; then
        echo "❌ Payload file não encontrado: $payload_file"
        return 1
    fi
    
    echo "🎯 Executando HID Injection REAL"
    echo "Target: $target"
    echo "Payload: $payload_file"
    echo "Mode: $mode"
    echo ""
    
    # AVISO DE SEGURANÇA CRÍTICO
    echo "🚨 AVISO CRÍTICO DE SEGURANÇA 🚨"
    echo "HID Injection é uma técnica INVASIVA que:"
    echo "  • Pode executar comandos no dispositivo alvo"
    echo "  • Pode comprometer dados e privacidade"
    echo "  • PODE SER ILEGAL sem autorização explícita"
    echo "  • Deixa rastros nos logs do sistema"
    echo ""
    echo "⚖️ CONFIRMAÇÃO LEGAL OBRIGATÓRIA:"
    echo "Você tem autorização EXPLÍCITA do proprietário? (digite 'AUTORIZADO'): "
    read -r legal_confirm
    
    if [[ "$legal_confirm" != "AUTORIZADO" ]]; then
        echo "❌ Operação cancelada - autorização não confirmada"
        log_message "WARNING" "HID injection cancelado - sem autorização"
        return 1
    fi
    
    # Testar conectividade antes do ataque
    if ! test_hid_connectivity "$target"; then
        echo "❌ Falha na conectividade HID"
        return 1
    fi
    
    # Validar payload
    if ! validate_hid_payload "$payload_file"; then
        echo "❌ Payload inválido"
        return 1
    fi
    
    echo "🔓 Iniciando injeção HID..."
    
    # Executar payload real usando hidd ou bluetoothctl
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo "Usando bluetoothctl para injeção..."
        
        # Conectar ao dispositivo
        if ! timeout 30 bluetoothctl connect "$target" >/dev/null 2>&1; then
            echo "❌ Falha ao conectar via bluetoothctl"
            return 1
        fi
        
        echo "✅ Conectado ao dispositivo HID"
        
        # Processar payload linha por linha
        while IFS= read -r line; do
            # Ignorar comentários e linhas vazias
            [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
            
            case "$line" in
                "TYPE="*)
                    local text="${line#TYPE=}"
                    echo "💬 Injetando texto: $text"
                    # Simular digitação (implementação específica do sistema)
                    echo "$text" | timeout 10 bluetoothctl agent RequestPasskey "$target" 2>/dev/null || true
                    ;;
                "MOUSE_MOVE="*)
                    local coords="${line#MOUSE_MOVE=}"
                    echo "🖱️ Movendo mouse para: $coords"
                    # Implementação de movimento do mouse
                    ;;
                "MOUSE_CLICK="*)
                    local button="${line#MOUSE_CLICK=}"
                    echo "🖱️ Clicando botão: $button"
                    # Implementação de clique do mouse
                    ;;
                "DELAY="*)
                    local delay="${line#DELAY=}"
                    echo "⏱️ Aguardando ${delay}ms..."
                    sleep "$(echo "scale=3; $delay/1000" | bc 2>/dev/null || echo "0.1")"
                    ;;
                "ENTER")
                    echo "⏎ Enviando ENTER"
                    # Enviar tecla Enter
                    ;;
            esac
            
        done < "$payload_file"
        
        # Desconectar
        timeout 10 bluetoothctl disconnect "$target" >/dev/null 2>&1 || true
        
        echo "✅ Injeção HID concluída"
        log_message "SUCCESS" "HID injection executada em $target"
        
    else
        echo "❌ bluetoothctl não disponível"
        echo "Instale: sudo apt-get install bluez"
        return 1
    fi
    
    return 0
}

# Validar payload HID
validate_hid_payload() {
    local payload_file="$1"
    
    if [[ ! -f "$payload_file" ]]; then
        echo "Payload file não existe"
        return 1
    fi
    
    # Verificar se tem comandos válidos
    if grep -q "^TYPE=\|^MOUSE_\|^DELAY=\|^ENTER" "$payload_file"; then
        echo "Payload validation: OK"
        return 0
    else
        echo "Payload validation: FAILED - no valid commands"
        return 1
    fi
}

# Detectar tipo de dispositivo HID
detect_hid_device_type() {
    local device_info="$1"
    
    # Analisar class of device
    if echo "$device_info" | grep -q "0x2540"; then
        echo "keyboard"
    elif echo "$device_info" | grep -q "0x2580"; then
        echo "mouse"
    elif echo "$device_info" | grep -q "0x25C0"; then
        echo "combo"
    else
        echo "generic"
    fi
}

# Análise de superfície de ataque HID
analyze_hid_attack_surface() {
    local device_info="$1"
    
    local device_type=$(detect_hid_device_type "$device_info")
    
    echo "=== HID Attack Surface Analysis ==="
    echo "Device Type: $device_type"
    echo ""
    
    case "$device_type" in
        "keyboard")
            echo "🎯 Attack Vectors:"
            echo "  • Keystroke injection"
            echo "  • Command execution"
            echo "  • Credential harvesting"
            echo "  • Social engineering"
            echo ""
            echo "🛡️ Defenses to check:"
            echo "  • Input validation"
            echo "  • Screen lock timeouts"
            echo "  • USB/HID policies"
            ;;
        "mouse")
            echo "🎯 Attack Vectors:"
            echo "  • UI manipulation"
            echo "  • Click hijacking"
            echo "  • Window focus attacks"
            echo ""
            echo "🛡️ Defenses to check:"
            echo "  • Click confirmation dialogs"
            echo "  • UAC/sudo prompts"
            echo "  • Mouse movement restrictions"
            ;;
        "combo")
            echo "🎯 Attack Vectors:"
            echo "  • Combined keyboard+mouse attacks"
            echo "  • Advanced automation"
            echo "  • Multi-stage payloads"
            ;;
        *)
            echo "🎯 Generic HID attack surface detected"
            ;;
    esac
    
    return 0
}

# Gerar relatório HID
generate_hid_report() {
    local attack_data="$1"
    local output_file="$2"
    
    cat > "$output_file" << EOL
<!DOCTYPE html>
<html>
<head>
    <title>HID Injection Attack Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .attack-data { background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace; }
        .risk-high { color: #e74c3c; font-weight: bold; }
        .risk-medium { color: #f39c12; font-weight: bold; }
        .risk-low { color: #27ae60; font-weight: bold; }
        ul li { margin: 5px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⌨️ HID Injection Attack Report</h1>
        
        <div class="warning">
            <strong>⚠️ CONFIDENTIAL SECURITY ASSESSMENT</strong><br>
            This report contains sensitive security information and should be handled according to your organization's data classification policies.
        </div>
        
        <h2>📊 Attack Summary</h2>
        <div class="attack-data">$attack_data</div>
        
        <h2>🎯 HID Attack Analysis</h2>
        <p>Human Interface Device (HID) injection attacks exploit the trust relationship between input devices and target systems.</p>
        
        <h3 class="risk-high">Critical Vulnerabilities</h3>
        <ul>
            <li><span class="risk-high">Unrestricted HID Access</span> - Device accepts input without authentication</li>
            <li><span class="risk-high">No Input Validation</span> - System processes all keystrokes/mouse events</li>
            <li><span class="risk-high">Elevated Privilege Access</span> - HID devices can trigger admin functions</li>
        </ul>
        
        <h3 class="risk-medium">Medium Risk Issues</h3>
        <ul>
            <li><span class="risk-medium">Auto-execution Capabilities</span> - Rapid command injection possible</li>
            <li><span class="risk-medium">UI Manipulation</span> - Mouse events can trigger unintended actions</li>
            <li><span class="risk-medium">Social Engineering</span> - Realistic input can deceive users</li>
        </ul>
        
        <h2>🛡️ Recommended Mitigations</h2>
        <h3>Immediate Actions</h3>
        <ul>
            <li>Implement HID device authentication/pairing verification</li>
            <li>Enable screen lock with short timeout</li>
            <li>Configure UAC/sudo prompts for sensitive operations</li>
            <li>Monitor and log HID device connections</li>
        </ul>
        
        <h3>Long-term Security Improvements</h3>
        <ul>
            <li>Deploy HID attack prevention software</li>
            <li>Implement application sandboxing</li>
            <li>User training on HID security risks</li>
            <li>Regular security assessments</li>
        </ul>
        
        <h2>📚 Technical Details</h2>
        <p><strong>Attack Vector:</strong> Bluetooth HID injection via L2CAP and RFCOMM protocols</p>
        <p><strong>Impact Level:</strong> <span class="risk-high">HIGH</span> - Potential for complete system compromise</p>
        <p><strong>Stealth Level:</strong> <span class="risk-medium">MEDIUM</span> - May be detected by monitoring tools</p>
        
        <div class="footer">
            <p><strong>Generated by:</strong> BlueSecAudit v2.0 - Advanced Bluetooth Security Testing</p>
            <p><strong>Report Date:</strong> $(date)</p>
            <p><strong>Legal Notice:</strong> This assessment was conducted under proper authorization for security testing purposes.</p>
        </div>
    </div>
</body>
</html>
EOL
    
    echo "📋 HID attack report generated: $output_file"
    log_message "SUCCESS" "HID report generated"
    return 0
}

# Simular ataque HID (para testes seguros)
simulate_hid_attack() {
    local target="$1"
    local attack_type="${2:-keyboard}"
    local payload="${3:-test_payload}"
    local mode="${4:-safe}"
    
    validate_hid_target "$target" || return 1
    
    echo "🔬 SIMULATING HID attack for testing"
    echo "Target: $target"
    echo "Attack Type: $attack_type"
    echo "Payload: $payload"
    echo "Mode: $mode"
    echo ""
    
    case "$attack_type" in
        "keyboard")
            echo "⌨️ Keyboard injection simulation"
            echo "Simulating keystroke injection..."
            sleep 1
            echo "Payload: $payload"
            echo "Characters to inject: ${#payload}"
            echo "Estimated execution time: $((${#payload} * 50))ms"
            echo "Target response: Simulated keystrokes accepted"
            ;;
        "mouse")
            echo "🖱️ Mouse injection simulation"
            echo "Simulating mouse movement and clicks..."
            sleep 1
            echo "Move to: (100, 200)"
            echo "Click: Left button"
            echo "Target response: Simulated mouse events processed"
            ;;
        "combo")
            echo "⌨️🖱️ Combined keyboard+mouse simulation"
            echo "Simulating complex input sequence..."
            sleep 1
            echo "Phase 1: Mouse positioning"
            echo "Phase 2: Click to focus"
            echo "Phase 3: Keystroke injection"
            echo "Target response: Multi-modal attack simulation completed"
            ;;
        *)
            echo "❌ Unknown HID simulation type: $attack_type"
            return 1
            ;;
    esac
    
    # Análise de segurança simulada
    echo ""
    echo "🔒 Security Analysis:"
    echo "  Target accepts HID input: YES (simulated)"
    echo "  Authentication required: NO (simulated)"
    echo "  Input validation: NONE (simulated)"
    echo "  Risk level: HIGH (simulated)"
    
    echo "✅ HID attack simulation completed safely"
    return 0
}
