#!/usr/bin/env bats
# Testes unitários para lib/attacks.sh

load '../test_helper'

# Setup específico para este arquivo de teste
setup() {
    # Criar mocks para comandos de ataque
    mock_bluetooth_cmd "l2ping"
    mock_bluetooth_cmd "sdptool"
    mock_bluetooth_cmd "obexftp"
    mock_bluetooth_cmd "bluetoothctl"
    
    # Carrega módulos de ataque
    source lib/attacks.sh
    source lib/bluetooth.sh
    source lib/utils.sh
}

@test "bluesmack_attack: deve executar ataque DoS L2CAP básico" {
    # Mock para l2ping com payload grande
    cat > tests/mocks/l2ping << 'EOF'
#!/bin/bash
if [[ "$1" == "-i" && "$3" == "-s" && "$4" == "600" ]]; then
    echo "PING $6 with $4 bytes of data"
    echo "Sent $4 bytes to $6"
    exit 0
fi
EOF
    chmod +x tests/mocks/l2ping
    
    run bluesmack_attack "00:11:22:33:44:55"
    assert_success
    assert_output --partial "PING 00:11:22:33:44:55"
}

@test "bluesmack_advanced: deve executar ataque DoS avançado com múltiplas técnicas" {
    cat > tests/mocks/l2ping << 'EOF'
#!/bin/bash
echo "Advanced L2CAP flood: $@"
exit 0
EOF
    chmod +x tests/mocks/l2ping
    
    run bluesmack_advanced "00:11:22:33:44:55" "adaptive"
    assert_success
    assert_output --partial "Advanced L2CAP flood"
}

@test "sdp_enumeration: deve enumerar serviços SDP detalhadamente" {
    cat > tests/mocks/sdptool << 'EOF'
#!/bin/bash
if [[ "$1" == "browse" ]]; then
    echo "Service Name: Audio Gateway"
    echo "Service RecHandle: 0x10001"
    echo "Service Class ID List:"
    echo '  "Handfree Audio Gateway" (0x111f)'
    echo "Protocol Descriptor List:"
    echo '  "L2CAP" (0x0100)'
    echo '  "RFCOMM" (0x0003)'
    echo '    Channel: 1'
fi
EOF
    chmod +x tests/mocks/sdptool
    
    run sdp_enumeration "00:11:22:33:44:55"
    assert_success
    assert_output --partial "Audio Gateway"
    assert_output --partial "0x111f"
}

@test "vulnerability_scanner: deve identificar vulnerabilidades conhecidas" {
    # Mock para resultado com vulnerabilidade
    local vuln_result=$(cat << 'EOF'
Service Name: Headset Audio Gateway
Service Class ID List:
  "Headset Audio Gateway" (0x1112)
Protocol Descriptor List:
  "L2CAP" (0x0100)
  "RFCOMM" (0x0003)
    Channel: 2
EOF
)
    
    run vulnerability_scanner "$vuln_result"
    assert_success
    assert_output --partial "VULNERABILITY"
}

@test "obex_exploitation: deve testar vulnerabilidades OBEX" {
    cat > tests/mocks/obexftp << 'EOF'
#!/bin/bash
case "$1" in
    "-b") 
        case "$4" in
            "-p") echo "File transfer successful: $5" ;;
            "-g") echo "File retrieval: $5" ;;
            "-l") echo "Directory listing: /root /etc /home" ;;
        esac
        ;;
esac
EOF
    chmod +x tests/mocks/obexftp
    
    run obex_exploitation "00:11:22:33:44:55"
    assert_success
}

@test "pin_bruteforce_intelligent: deve executar brute force inteligente" {
    cat > tests/mocks/bluetoothctl << 'EOF'
#!/bin/bash
case "$1" in
    "pair")
        # Simular falha para primeiros PINs
        if [[ "$2" == "0000" || "$2" == "1111" ]]; then
            echo "Failed to pair: org.bluez.Error.AuthenticationFailed"
            exit 1
        elif [[ "$2" == "1234" ]]; then
            echo "Pairing successful"
            exit 0
        fi
        ;;
esac
EOF
    chmod +x tests/mocks/bluetoothctl
    
    run pin_bruteforce_intelligent "00:11:22:33:44:55" "phone"
    assert_success
}

@test "generate_device_wordlist: deve gerar wordlist baseada no dispositivo" {
    local device_info=$(cat << 'EOF'
Device Name: Samsung Galaxy S10
Manufacturer: Samsung (117)
Class: 0x200408 (Phone)
EOF
)
    
    run generate_device_wordlist "$device_info"
    assert_success
    assert_output --partial "samsung"
    assert_output --partial "galaxy"
}

@test "detect_pairing_method: deve detectar método de emparelhamento" {
    local device_info_ssp=$(cat << 'EOF'
LMP Version: 4.0 (0x6) LMP Subversion: 0x220e
EOF
)
    
    run detect_pairing_method "$device_info_ssp"
    assert_output "SSP"
    
    local device_info_legacy=$(cat << 'EOF'
LMP Version: 1.2 (0x2) LMP Subversion: 0x0001
EOF
)
    
    run detect_pairing_method "$device_info_legacy"
    assert_output "Legacy"
}

@test "analyze_attack_surface: deve analisar superfície de ataque" {
    local services=$(cat << 'EOF'
Service Name: Audio Gateway
Service Class ID List:
  "Handfree Audio Gateway" (0x111f)
Service Name: Object Push
Service Class ID List:
  "OBEX Object Push" (0x1105)
EOF
)
    
    run analyze_attack_surface "$services"
    assert_success
    assert_output --partial "Audio Gateway"
    assert_output --partial "Object Push"
}

@test "rate_limit_detection: deve detectar limitação de taxa" {
    # Simular tentativas rápidas de conexão
    run rate_limit_detection "00:11:22:33:44:55"
    assert_success
}

@test "adaptive_timing: deve calcular timing adaptativo" {
    run adaptive_timing "phone" "legacy"
    assert_success
    assert_output --regexp "[0-9]+"  # Deve retornar um número
}

@test "hid_injection_test: deve testar injeção HID" {
    cat > tests/mocks/bluetoothctl << 'EOF'
#!/bin/bash
echo "HID injection test for $2"
echo "Testing keyboard input injection..."
exit 0
EOF
    chmod +x tests/mocks/bluetoothctl
    
    run hid_injection_test "00:11:22:33:44:55"
    assert_success
    assert_output --partial "HID injection test"
}

@test "audio_interception_test: deve testar interceptação de áudio" {
    cat > tests/mocks/bluetoothctl << 'EOF'
#!/bin/bash
if [[ "$1" == "connect" ]]; then
    echo "Attempting A2DP connection to $2"
    echo "Audio stream analysis: 44.1kHz stereo"
    exit 0
fi
EOF
    chmod +x tests/mocks/bluetoothctl
    
    run audio_interception_test "00:11:22:33:44:55"
    assert_success
    assert_output --partial "A2DP connection"
}

@test "calculate_attack_risk: deve calcular risco do ataque" {
    run calculate_attack_risk "phone" "legacy" "audio,obex"
    assert_success
    assert_output --regexp "Risk Level: (LOW|MEDIUM|HIGH|CRITICAL)"
}

@test "generate_attack_report: deve gerar relatório de ataque" {
    local attack_data=$(cat << 'EOF'
Target: 00:11:22:33:44:55
Device: Samsung Phone
Vulnerabilities: OBEX Directory Traversal, Weak PIN
Risk: HIGH
EOF
)
    
    run generate_attack_report "$attack_data" "$TEST_TEMP_DIR/report.html"
    assert_success
    assert_file_exists "$TEST_TEMP_DIR/report.html"
} 