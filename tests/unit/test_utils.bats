#!/usr/bin/env bats
# Testes unitários para lib/utils.sh

load '../test_helper'

# Setup específico para este arquivo de teste
setup() {
    # Carrega funções utilitárias
    source lib/utils.sh
}

@test "is_valid_mac: deve validar endereços MAC válidos" {
    run is_valid_mac "00:11:22:33:44:55"
    assert_success
    
    run is_valid_mac "AA:BB:CC:DD:EE:FF"
    assert_success
    
    run is_valid_mac "12:34:56:78:9a:bc"
    assert_success
}

@test "is_valid_mac: deve rejeitar endereços MAC inválidos" {
    run is_valid_mac "00:11:22:33:44"  # Muito curto
    assert_failure
    
    run is_valid_mac "00:11:22:33:44:55:66"  # Muito longo
    assert_failure
    
    run is_valid_mac "GG:11:22:33:44:55"  # Caractere inválido
    assert_failure
    
    run is_valid_mac "00-11-22-33-44-55"  # Separador inválido
    assert_failure
    
    run is_valid_mac ""  # Vazio
    assert_failure
}

@test "normalize_mac: deve normalizar MACs para uppercase" {
    run normalize_mac "aa:bb:cc:dd:ee:ff"
    assert_output "AA:BB:CC:DD:EE:FF"
    
    run normalize_mac "12:34:56:78:9a:bc"
    assert_output "12:34:56:78:9A:BC"
}

@test "log_message: deve criar logs com timestamp" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local log_file="$temp_dir/test.log"
    
    log_message "INFO" "Teste de log" "$log_file"
    
    assert_file_exists "$log_file"
    run cat "$log_file"
    assert_output --partial "INFO"
    assert_output --partial "Teste de log"
    
    rm -rf "$temp_dir"
}

@test "check_root: deve verificar privilégios de root" {
    # Test with current user (should return based on actual EUID)
    run check_root
    
    # Verify function works (either passes or fails, but doesn't crash)
    # Since EUID is read-only, we test the function behavior
    if [[ $EUID -eq 0 ]]; then
        assert_success
    else
        assert_failure
    fi
}

@test "validate_timeout: deve validar valores de timeout" {
    run validate_timeout "30"
    assert_success
    
    run validate_timeout "0"
    assert_failure
    
    run validate_timeout "-5"
    assert_failure
    
    run validate_timeout "abc"
    assert_failure
}

@test "format_duration: deve formatar duração em segundos" {
    run format_duration 65
    assert_output "1m 5s"
    
    run format_duration 3661
    assert_output "1h 1m 1s"
    
    run format_duration 30
    assert_output "30s"
}

@test "generate_report_filename: deve gerar nomes únicos" {
    run generate_report_filename "test"
    assert_output --regexp "test_[0-9]{8}_[0-9]{6}\.txt"
    
    # Dois chamadas devem gerar nomes diferentes
    first_name=$(generate_report_filename "audit")
    sleep 1
    second_name=$(generate_report_filename "audit")
    
    [ "$first_name" != "$second_name" ]
}

@test "cleanup_temp_files: deve limpar arquivos temporários" {
    # Criar alguns arquivos temporários
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    touch "$temp_dir/temp1.tmp"
    touch "$temp_dir/temp2.tmp"
    
    cleanup_temp_files "$temp_dir"
    
    assert_file_not_exists "$temp_dir/temp1.tmp"
    assert_file_not_exists "$temp_dir/temp2.tmp"
    
    rm -rf "$temp_dir"
}

@test "cleanup_temp_files: deve lidar com diretório inexistente" {
    # Deve não falhar com diretório que não existe
    run cleanup_temp_files "/path/that/does/not/exist"
    assert_success
}

@test "validate_mac_address: deve ser alias para is_valid_mac" {
    run validate_mac_address "00:11:22:33:44:55"
    assert_success
    
    run validate_mac_address "invalid"
    assert_failure
}

@test "command_exists: deve verificar se comando está disponível" {
    run command_exists "bash"
    assert_success
    
    run command_exists "comando_inexistente_xyz123"
    assert_failure
}

@test "generate_session_id: deve gerar ID único de sessão" {
    run generate_session_id
    assert_success
    assert_output --regexp "bs_[0-9]+_[0-9]+"
    
    # Duas chamadas devem gerar IDs diferentes
    first_id=$(generate_session_id)
    sleep 1
    second_id=$(generate_session_id)
    
    [ "$first_id" != "$second_id" ]
}

@test "check_network: deve verificar conectividade básica" {
    # Create a mock ping command
    mkdir -p tests/mocks
    cat > tests/mocks/ping << 'EOF'
#!/bin/bash
# Mock ping that always succeeds for 8.8.8.8
# Command: ping -c 1 -W 5 8.8.8.8
if [[ "$5" == "8.8.8.8" ]] || [[ "$*" == *"8.8.8.8"* ]]; then
    exit 0
else
    exit 1
fi
EOF
    chmod +x tests/mocks/ping
    
    # Add mocks to PATH
    export PATH="tests/mocks:$PATH"
    
    run check_network
    assert_success
}

@test "backup_file: deve criar backup com timestamp" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local test_file="$temp_dir/test.txt"
    echo "conteúdo teste" > "$test_file"
    
    run backup_file "$test_file"
    assert_success
    
    local backup_name="$output"
    assert_file_exists "$backup_name"
    
    # Verificar conteúdo do backup
    run cat "$backup_name"
    assert_output "conteúdo teste"
    
    rm -rf "$temp_dir" "$backup_name"
}

@test "backup_file: deve falhar com arquivo inexistente" {
    run backup_file "/arquivo/inexistente.txt"
    assert_failure
}

@test "validate_port_range: deve validar range de portas válido" {
    run validate_port_range "80" "8080"
    assert_success
    
    run validate_port_range "1" "65535"
    assert_success
    
    run validate_port_range "443" "443"
    assert_success
}

@test "validate_port_range: deve rejeitar range inválido" {
    run validate_port_range "8080" "80"  # start > end
    assert_failure
    
    run validate_port_range "0" "80"  # start < 1
    assert_failure
    
    run validate_port_range "80" "65536"  # end > 65535
    assert_failure
    
    run validate_port_range "abc" "80"  # não numérico
    assert_failure
}

@test "calculate_file_hash: deve calcular hash SHA256 padrão" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local test_file="$temp_dir/hash_test.txt"
    echo "teste" > "$test_file"
    
    run calculate_file_hash "$test_file"
    assert_success
    assert_output --regexp "^[a-f0-9]{64}$"  # SHA256 format
    
    rm -rf "$temp_dir"
}

@test "calculate_file_hash: deve suportar diferentes algoritmos" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local test_file="$temp_dir/hash_test.txt"
    echo "teste" > "$test_file"
    
    # Test MD5
    run calculate_file_hash "$test_file" "md5"
    assert_success
    assert_output --regexp "^[a-f0-9]{32}$"  # MD5 format
    
    # Test SHA1
    run calculate_file_hash "$test_file" "sha1"
    assert_success
    assert_output --regexp "^[a-f0-9]{40}$"  # SHA1 format
    
    rm -rf "$temp_dir"
}

@test "calculate_file_hash: deve falhar com algoritmo inválido" {
    local temp_dir="/tmp/bs_test_$$_$RANDOM"
    mkdir -p "$temp_dir"
    local test_file="$temp_dir/hash_test.txt"
    echo "teste" > "$test_file"
    
    run calculate_file_hash "$test_file" "algoritmo_inexistente"
    assert_failure
    assert_output --partial "Algoritmo não suportado"
    
    rm -rf "$temp_dir"
}

@test "format_duration: deve tratar zero segundos" {
    run format_duration "0"
    assert_output "0s"
}

@test "log_message: deve usar stdout como padrão" {
    run log_message "DEBUG" "Teste stdout"
    assert_success
    assert_output --partial "DEBUG"
    assert_output --partial "Teste stdout"
}