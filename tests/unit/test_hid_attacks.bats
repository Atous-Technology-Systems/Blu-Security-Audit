#!/usr/bin/env bats

# Testes unitários para HID Injection Attacks
# TDD Implementation - BlueSecAudit v2.0

setup() {
    # Carregar módulos necessários
    source "${BATS_TEST_DIRNAME}/../../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/bluetooth.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/hid_attacks.sh"
    
    # Variáveis de teste
    export TEST_TARGET="00:11:22:33:44:55"
    export TEST_HID_CHANNEL="17"
    export TEST_PAYLOAD_DIR="/tmp/hid_payloads_test"
    
    # Criar diretório temporário
    mkdir -p "$TEST_PAYLOAD_DIR"
}

teardown() {
    # Limpeza após testes
    rm -rf "$TEST_PAYLOAD_DIR"
    pkill -f "rfcomm\|hidd" 2>/dev/null || true
}

# Teste 1: Validação de MAC address para HID
@test "validate_hid_target should validate MAC address format" {
    run validate_hid_target "$TEST_TARGET"
    [ "$status" -eq 0 ]
    
    run validate_hid_target "invalid_mac"
    [ "$status" -eq 1 ]
}

# Teste 2: Detecção de serviços HID
@test "detect_hid_services should identify HID services" {
    # Mock SDP data com HID
    local sdp_data="Service Name: Human Interface Device
Protocol Descriptor List:
Service Class ID List: HID"
    
    run detect_hid_services "$sdp_data"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HID service detected" ]]
}

# Teste 3: Geração de payload de teclado
@test "generate_keyboard_payload should create valid payloads" {
    run generate_keyboard_payload "hello world" "$TEST_PAYLOAD_DIR/test.payload"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PAYLOAD_DIR/test.payload" ]
    
    # Verificar conteúdo do payload
    run cat "$TEST_PAYLOAD_DIR/test.payload"
    [[ "$output" =~ "hello world" ]]
}

# Teste 4: Geração de payload de mouse
@test "generate_mouse_payload should create mouse commands" {
    run generate_mouse_payload "click" "100" "200" "$TEST_PAYLOAD_DIR/mouse.payload"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PAYLOAD_DIR/mouse.payload" ]
}

# Teste 5: Teste de conectividade HID
@test "test_hid_connectivity should check HID channel" {
    # Simular teste de conectividade
    run test_hid_connectivity "$TEST_TARGET" "$TEST_HID_CHANNEL"
    # Deve falhar com target fake, mas não deve crashar
    [ "$status" -ne 2 ]  # Não deve ter erro crítico
}

# Teste 6: Análise de surface attack HID
@test "analyze_hid_attack_surface should identify vectors" {
    local device_info="Device Class: 0x2540
Service: Human Interface Device"
    
    run analyze_hid_attack_surface "$device_info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "keyboard injection" ]]
}

# Teste 7: Validação de payload
@test "validate_hid_payload should check payload format" {
    echo -e "# HID Payload\nTYPE=keyboard\nvalid_hid_command" > "$TEST_PAYLOAD_DIR/valid.payload"
    echo "malformed_command_xxx" > "$TEST_PAYLOAD_DIR/invalid.payload"
    
    run validate_hid_payload "$TEST_PAYLOAD_DIR/valid.payload"
    [ "$status" -eq 0 ]
    
    run validate_hid_payload "$TEST_PAYLOAD_DIR/invalid.payload"
    [ "$status" -eq 1 ]
}

# Teste 8: Simulação de ataque seguro
@test "simulate_hid_attack should run in safe mode" {
    run simulate_hid_attack "$TEST_TARGET" "keyboard" "test_payload" "safe"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "simulation" ]]
}

# Teste 9: Detecção de tipo de dispositivo HID
@test "detect_hid_device_type should classify devices" {
    local keyboard_info="Device Class: 0x2540"
    local mouse_info="Device Class: 0x2580"
    
    run detect_hid_device_type "$keyboard_info"
    [[ "$output" =~ "keyboard" ]]
    
    run detect_hid_device_type "$mouse_info"
    [[ "$output" =~ "mouse" ]]
}

# Teste 10: Geração de relatório HID
@test "generate_hid_report should create detailed report" {
    local attack_data="Target: $TEST_TARGET
Type: keyboard
Status: success"
    
    run generate_hid_report "$attack_data" "$TEST_PAYLOAD_DIR/report.html"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PAYLOAD_DIR/report.html" ]
    
    # Verificar conteúdo HTML
    run grep -i "hid.*injection" "$TEST_PAYLOAD_DIR/report.html"
    [ "$status" -eq 0 ]
} 