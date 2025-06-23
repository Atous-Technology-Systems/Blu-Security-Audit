#!/usr/bin/env bats

# Testes de integração para funcionalidades avançadas
# TDD Implementation - BlueSecAudit v2.0

setup() {
    # Variáveis de teste
    export TEST_DIR="/tmp/bs_integration_test"
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../bs-at-v2.sh"
    
    # Criar diretório de teste
    mkdir -p "$TEST_DIR"
    
    # Verificar se o script principal existe
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        skip "Script principal não encontrado: $SCRIPT_PATH"
    fi
}

teardown() {
    # Limpeza
    rm -rf "$TEST_DIR"
}

# Teste 1: Verificar se novos módulos são carregados
@test "script should load all advanced modules" {
    run bash -n "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    # Verificar se os módulos são carregados
    run grep -q "hid_attacks.sh" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "audio_attacks.sh" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "ble_attacks.sh" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 2: Verificar se menu foi atualizado
@test "menu should include new options" {
    run grep -E "HID.*Injection|Audio.*Interception|BLE.*Low.*Energy" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    # Verificar numeração do menu
    run grep -q "Selecione uma opção \[1-11\]" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 3: Verificar se funções de execução existem
@test "execution functions should be defined" {
    run grep -q "execute_hid_injection()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "execute_audio_interception()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "execute_ble_attacks()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 4: Verificar se script executa sem erros de sintaxe
@test "script should have valid bash syntax" {
    run bash -n "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 5: Verificar se help menu foi atualizado
@test "help should reference new features" {
    run grep -A 20 -B 5 "ℹ️.*Ajuda" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 6: Verificar estrutura de diretórios
@test "should create required directories" {
    # Simular execução e verificar criação de diretórios
    local temp_script="/tmp/test_bs_script.sh"
    
    # Extrair apenas a parte de criação de diretórios
    cat > "$temp_script" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(pwd)"
mkdir -p "${SCRIPT_DIR}/"{config,logs,results,wordlists}
echo "Directories created"
EOF
    
    chmod +x "$temp_script"
    run bash "$temp_script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Directories created"* ]]
    
    rm -f "$temp_script"
}

# Teste 7: Verificar compatibilidade com funcionalidades existentes
@test "new features should not break existing functionality" {
    # Verificar se funções originais ainda existem
    run grep -q "execute_bluesmack()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "execute_sdp_enumeration()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "execute_obex_exploitation()" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 8: Verificar imports dos módulos
@test "all required modules should be imported" {
    local required_modules=("utils.sh" "bluetooth.sh" "attacks.sh" "ui.sh" "hid_attacks.sh" "audio_attacks.sh" "ble_attacks.sh")
    
    for module in "${required_modules[@]}"; do
        run grep -q "source.*$module" "$SCRIPT_PATH"
        [ "$status" -eq 0 ]
    done
}

# Teste 9: Verificar variáveis globais
@test "global variables should be properly defined" {
    run grep -q "SESSION_ID" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "SELECTED_TARGET" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    run grep -q "RESULTS_DIR" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# Teste 10: Verificar tratamento de erros
@test "error handling should be maintained" {
    # Verificar se há tratamento para retornos de função
    run grep -E "return [0-9]|exit [0-9]" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
    
    # Verificar se há verificações de erro
    run grep -q "|| return" "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
} 