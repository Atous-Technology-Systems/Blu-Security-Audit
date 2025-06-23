#!/usr/bin/env bats

# Testes unitários para BLE (Bluetooth Low Energy) Attacks
# TDD Implementation - BlueSecAudit v2.0

setup() {
    # Carregar módulos necessários
    source "${BATS_TEST_DIRNAME}/../../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/bluetooth.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/ble_attacks.sh"
    
    # Variáveis de teste
    export TEST_BLE_TARGET="AA:BB:CC:DD:EE:FF"
    export TEST_BLE_DIR="/tmp/ble_test"
    export TEST_GATT_FILE="/tmp/ble_test/gatt_services.txt"
    
    # Criar diretório temporário
    mkdir -p "$TEST_BLE_DIR"
}

teardown() {
    # Limpeza após testes
    rm -rf "$TEST_BLE_DIR"
    pkill -f "gatttool\|bluetoothctl\|hcitool" 2>/dev/null || true
}

# Teste 1: Detectar dispositivos BLE
@test "detect_ble_devices should find BLE devices" {
    run detect_ble_devices "10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"BLE scan"* ]]
}

# Teste 2: Validar endereço BLE
@test "validate_ble_address should check BLE format" {
    run validate_ble_address "$TEST_BLE_TARGET"
    [ "$status" -eq 0 ]
    
    run validate_ble_address "invalid_ble"
    [ "$status" -eq 1 ]
}

# Teste 3: Escanear serviços GATT
@test "scan_gatt_services should discover services" {
    run scan_gatt_services "$TEST_BLE_TARGET" "$TEST_GATT_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GATT"* ]]
}

# Teste 4: Detectar características BLE
@test "detect_ble_characteristics should find characteristics" {
    local gatt_data="Service: Generic Access
Characteristic: Device Name
Service: Heart Rate
Characteristic: Heart Rate Measurement"
    
    run detect_ble_characteristics "$gatt_data"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Device Name"* ]]
    [[ "$output" == *"Heart Rate"* ]]
}

# Teste 5: Analisar vulnerabilidades BLE
@test "analyze_ble_vulnerabilities should identify risks" {
    local device_info="Services: 5
Encryption: None
Authentication: Disabled"
    
    run analyze_ble_vulnerabilities "$device_info"
    [ "$status" -eq 0 ]
    [[ "$output" == *"vulnerability"* ]] || [[ "$output" == *"RISK"* ]] || [[ "$output" == *"risk"* ]]
}

# Teste 6: Testar conectividade BLE
@test "test_ble_connectivity should check connection" {
    run test_ble_connectivity "$TEST_BLE_TARGET"
    # Deve retornar sem erro crítico mesmo que falhe
    [ "$status" -ne 2 ]
}

# Teste 7: Simular ataque BLE
@test "simulate_ble_attack should run safely" {
    run simulate_ble_attack "$TEST_BLE_TARGET" "passive" "safe"
    [ "$status" -eq 0 ]
    [[ "$output" == *"simulation"* ]]
}

# Teste 8: Detectar tipo de dispositivo BLE
@test "detect_ble_device_type should classify device" {
    local services_data="Service: Heart Rate
Service: Battery
Service: Device Information"
    
    run detect_ble_device_type "$services_data"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fitness"* ]] || [[ "$output" == *"health"* ]]
}

# Teste 9: Analisar segurança BLE
@test "analyze_ble_security should assess protection" {
    local security_data="Pairing: Just Works
Encryption: AES-128
Authentication: None"
    
    run analyze_ble_security "$security_data"
    [ "$status" -eq 0 ]
    [[ "$output" == *"security"* ]] || [[ "$output" == *"Security"* ]]
}

# Teste 10: Gerar relatório BLE
@test "generate_ble_report should create analysis" {
    local ble_data="Target: $TEST_BLE_TARGET
Services: 3
Security: Low"
    
    run generate_ble_report "$ble_data" "$TEST_BLE_DIR/report.html"
    [ "$status" -eq 0 ]
    [ -f "$TEST_BLE_DIR/report.html" ]
    
    # Verificar conteúdo HTML
    run grep -i "BLE\|Bluetooth.*Low.*Energy" "$TEST_BLE_DIR/report.html"
    [ "$status" -eq 0 ]
}

# Teste 11: Monitorar tráfego BLE
@test "monitor_ble_traffic should capture packets" {
    run monitor_ble_traffic "$TEST_BLE_TARGET" "5" "$TEST_BLE_DIR/capture.log"
    [ "$status" -eq 0 ]
    [[ "$output" == *"monitoring"* ]]
}

# Teste 12: Detectar beacons BLE
@test "detect_ble_beacons should find iBeacon/Eddystone" {
    local beacon_data="iBeacon: UUID=550e8400-e29b-41d4-a716-446655440000
Eddystone: URL=https://example.com"
    
    run detect_ble_beacons "$beacon_data"
    [ "$status" -eq 0 ]
    [[ "$output" == *"iBeacon"* ]] || [[ "$output" == *"Eddystone"* ]]
} 