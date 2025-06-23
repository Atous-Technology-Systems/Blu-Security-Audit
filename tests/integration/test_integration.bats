#!/usr/bin/env bats
# Testes de integração para BlueSecAudit v2.0

load '../test_helper'

setup() {
    # Setup para testes de integração
    export PATH="tests/mocks:$PATH"
    
    # Criar mocks necessários
    create_integration_mocks
}

create_integration_mocks() {
    # Mock para hciconfig
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
case "$1" in
    "hci0")
        echo "hci0:	Type: Primary  Bus: USB"
        echo "	UP RUNNING PSCAN"
        ;;
    *)
        echo "hci0:	Type: Primary  Bus: USB"
        echo "	UP RUNNING PSCAN"
        ;;
esac
EOF
    chmod +x tests/mocks/hciconfig
    
    # Mock para hcitool
    cat > tests/mocks/hcitool << 'EOF'
#!/bin/bash
if [[ "$1" == "scan" ]]; then
    echo "Scanning ..."
    echo -e "00:11:22:33:44:55\tTest Phone"
    echo -e "AA:BB:CC:DD:EE:FF\tTest Headset"
fi
EOF
    chmod +x tests/mocks/hcitool
}

@test "integração: sistema inicializa corretamente" {
    # Executar inicialização
    source lib/utils.sh
    source lib/bluetooth.sh
    source lib/ui.sh
    
    # Verificar se funções principais estão disponíveis
    type is_valid_mac
    type get_bluetooth_adapters
    type display_banner
}

@test "integração: workflow completo de escaneamento" {
    source lib/utils.sh
    source lib/bluetooth.sh
    
    # Ativar adaptador
    run bring_adapter_up "hci0"
    assert_success
    
    # Escanear dispositivos
    run scan_bluetooth_devices
    assert_success
    assert_output --partial "00:11:22:33:44:55"
}

@test "integração: workflow de ataque BlueSmack" {
    source lib/utils.sh
    source lib/bluetooth.sh
    source lib/attacks.sh
    
    # Mock para l2ping
    cat > tests/mocks/l2ping << 'EOF'
#!/bin/bash
echo "PING $3:"
echo "44 bytes from $3 id 0 time 18.59ms"
EOF
    chmod +x tests/mocks/l2ping
    
    # Executar ataque
    run bluesmack_attack "00:11:22:33:44:55"
    assert_success
}

@test "integração: geração de relatório completo" {
    source lib/utils.sh
    source lib/attacks.sh
    
    local test_data="Target: 00:11:22:33:44:55\nDevice: Test Device\nRisk: HIGH"
    local output_file="$TEST_TEMP_DIR/report.html"
    
    run generate_attack_report "$test_data" "$output_file"
    assert_success
    assert_file_exists "$output_file"
    
    # Verificar conteúdo do relatório
    run cat "$output_file"
    assert_output --partial "BlueSecAudit Report"
    assert_output --partial "Test Device"
}

@test "integração: pipeline de enumeração e análise" {
    source lib/bluetooth.sh
    source lib/attacks.sh
    
    # Mock para sdptool
    cat > tests/mocks/sdptool << 'EOF'
#!/bin/bash
echo "Service Name: Audio Gateway"
echo "Service Class ID List:"
echo '  "Handfree Audio Gateway" (0x111f)'
EOF
    chmod +x tests/mocks/sdptool
    
    # Executar enumeração
    local services=$(sdp_enumeration "00:11:22:33:44:55")
    
    # Analisar vulnerabilidades
    run vulnerability_scanner "$services"
    assert_success
    assert_output --partial "VULNERABILITY"
    
    # Analisar superfície de ataque
    run analyze_attack_surface "$services"
    assert_success
    assert_output --partial "Audio Gateway"
}

@test "integração: sistema de logging funciona" {
    source lib/utils.sh
    
    local log_file="$TEST_TEMP_DIR/test.log"
    
    log_message "INFO" "Teste de integração" "$log_file"
    log_message "ERROR" "Erro de teste" "$log_file"
    
    assert_file_exists "$log_file"
    
    run cat "$log_file"
    assert_output --partial "[INFO]"
    assert_output --partial "Teste de integração"
    assert_output --partial "[ERROR]"
    assert_output --partial "Erro de teste"
}

@test "integração: validação de entrada funciona em todos os módulos" {
    source lib/utils.sh
    source lib/bluetooth.sh
    source lib/attacks.sh
    
    # Testar MAC inválido em diferentes funções
    run is_valid_mac "invalid_mac"
    assert_failure
    
    run get_device_info "invalid_mac"
    assert_failure
    
    run bluesmack_attack "invalid_mac"
    assert_failure
}

@test "integração: recuperação de erros funciona" {
    source lib/utils.sh
    source lib/bluetooth.sh
    
    # Simular falha de adaptador
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
echo "No such device"
exit 1
EOF
    chmod +x tests/mocks/hciconfig
    
    # Verificar se sistema lida com erro graciosamente
    run is_adapter_up "hci0"
    assert_failure
}

@test "integração: sistema de cores da UI funciona" {
    source lib/ui.sh
    
    run color_text "red" "Teste"
    assert_success
    assert_output --partial $'\033[0;31m'
    
    run color_text "green" "Sucesso"
    assert_success
    assert_output --partial $'\033[0;32m'
}

@test "integração: formatação de dispositivos funciona" {
    source lib/ui.sh
    
    local device_data="00:11:22:33:44:55	Test Device"
    
    run format_device_info "$device_data"
    assert_success
    assert_output --partial "00:11:22:33:44:55"
    assert_output --partial "Test Device"
} 