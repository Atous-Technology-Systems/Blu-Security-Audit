#!/usr/bin/env bats
# Testes unitários para lib/ui.sh

load '../test_helper'

# Setup específico para este arquivo de teste
setup() {
    source lib/ui.sh
}

@test "display_banner: deve exibir banner do BlueSecAudit" {
    run display_banner
    assert_success
    assert_output --partial "BlueSecAudit"
    assert_output --partial "v2.0"
}

@test "display_menu: deve exibir menu principal" {
    run display_menu
    assert_success
    assert_output --partial "Menu Principal"
    assert_output --partial "1."
    assert_output --partial "BlueSmack"
}

@test "progress_bar: deve exibir barra de progresso" {
    run progress_bar 50 100 "Escaneando"
    assert_success
    assert_output --partial "Escaneando"
    assert_output --partial "50%"
}

@test "format_device_info: deve formatar informações do dispositivo" {
    local device_data="00:11:22:33:44:55	Samsung Phone"
    
    run format_device_info "$device_data"
    assert_success
    assert_output --partial "00:11:22:33:44:55"
    assert_output --partial "Samsung Phone"
}

@test "confirm_action: deve solicitar confirmação" {
    # Mock para entrada de usuário
    echo "y" | confirm_action "Continuar com o ataque?"
    local result=$?
    [[ $result -eq 0 ]]
}

@test "display_help: deve exibir ajuda do comando" {
    run display_help "bluesmack"
    assert_success
    assert_output --partial "BlueSmack"
    assert_output --partial "DoS"
}

@test "animate_spinner: deve animar spinner" {
    run animate_spinner 1
    assert_success
}

@test "format_time: deve formatar tempo decorrido" {
    run format_time 125
    assert_output "2m 5s"
    
    run format_time 3661
    assert_output "1h 1m 1s"
}

@test "display_results_table: deve exibir tabela de resultados" {
    local results="MAC:00:11:22:33:44:55,Name:Phone,Risk:HIGH"
    
    run display_results_table "$results"
    assert_success
    assert_output --partial "00:11:22:33:44:55"
    assert_output --partial "HIGH"
}

@test "color_text: deve colorir texto" {
    run color_text "red" "Erro"
    assert_output --partial $'\033[0;31m'
    
    run color_text "green" "Sucesso"
    assert_output --partial $'\033[0;32m'
}

@test "color_text: deve tratar cor inválida" {
    run color_text "cor_inexistente" "Texto"
    assert_success
    assert_output --partial "Texto"
}

@test "show_notification: deve exibir notificações de diferentes tipos" {
    run show_notification "success" "Operação concluída"
    assert_success
    assert_output --partial "✓"
    assert_output --partial "Operação concluída"
    
    run show_notification "error" "Falha na operação"
    assert_success
    assert_output --partial "✗"
    assert_output --partial "Falha na operação"
    
    run show_notification "warning" "Aviso importante"
    assert_success
    assert_output --partial "⚠"
    assert_output --partial "Aviso importante"
    
    run show_notification "info" "Informação útil"
    assert_success
    assert_output --partial "ℹ"
    assert_output --partial "Informação útil"
}

@test "select_device: deve retornar erro se arquivo não existe" {
    run select_device "/arquivo/inexistente.txt"
    assert_failure
    assert_output --partial "Nenhum dispositivo encontrado"
}

@test "select_device: deve retornar erro se arquivo vazio" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local empty_file="$temp_dir/devices.txt"
    touch "$empty_file"
    
    run select_device "$empty_file"
    assert_failure
    assert_output --partial "Nenhum dispositivo encontrado"
    
    rm -rf "$temp_dir"
}

@test "select_device: deve listar dispositivos do arquivo" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local devices_file="$temp_dir/devices.txt"
    
    cat > "$devices_file" << EOF
00:11:22:33:44:55	Device1
AA:BB:CC:DD:EE:FF	Device2
12:34:56:78:9A:BC	Device3
EOF
    
    # Mock user input (select first device)
    echo "1" | (run select_device "$devices_file")
    local result=$?
    [[ $result -eq 0 ]]
    
    rm -rf "$temp_dir"
}

@test "display_system_status: deve verificar status do sistema" {
    # Mock commands for testing
    mkdir -p tests/mocks
    
    # Mock hciconfig to simulate bluetooth adapter
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
if [[ "$1" == "hci0" ]]; then
    echo "hci0: Type: BR/EDR  Bus: USB"
    exit 0
fi
exit 1
EOF
    chmod +x tests/mocks/hciconfig
    
    # Mock command to simulate available tools
    cat > tests/mocks/command << 'EOF'
#!/bin/bash
if [[ "$1" == "-v" ]]; then
    case "$2" in
        "hcitool"|"sdptool"|"l2ping") exit 0 ;;
        *) exit 1 ;;
    esac
fi
EOF
    chmod +x tests/mocks/command
    
    export PATH="tests/mocks:$PATH"
    
    run display_system_status
    assert_success
    assert_output --partial "Status do Sistema"
    assert_output --partial "Adaptador Bluetooth"
}

@test "display_config_menu: deve exibir menu de configurações" {
    run display_config_menu
    assert_success
    assert_output --partial "Menu de Configurações"
    assert_output --partial "1."
    assert_output --partial "adaptador padrão"
    assert_output --partial "5."
}

@test "wait_for_key: deve aguardar entrada do usuário" {
    # Test that the function accepts input and completes
    echo "" | (run wait_for_key)
    local result=$?
    [[ $result -eq 0 ]]
}

@test "progress_bar: deve tratar casos extremos" {
    # 0% progress
    run progress_bar 0 100 "Iniciando"
    assert_success
    assert_output --partial "Iniciando"
    assert_output --partial "0%"
    
    # 100% progress
    run progress_bar 100 100 "Completo"
    assert_success
    assert_output --partial "Completo"
    assert_output --partial "100%"
}

@test "confirm_action: deve tratar resposta negativa" {
    echo "n" | (run confirm_action "Deseja continuar?")
    local result=$?
    [[ $result -eq 1 ]]
    
    echo "no" | (run confirm_action "Deseja prosseguir?")
    local result=$?
    [[ $result -eq 1 ]]
}

@test "display_help: deve tratar comando não reconhecido" {
    run display_help "comando_inexistente"
    assert_success
    assert_output --partial "Comando não reconhecido"
    assert_output --partial "comando_inexistente"
}

@test "format_time: deve tratar zero segundos" {
    run format_time 0
    assert_output "0s"
} 