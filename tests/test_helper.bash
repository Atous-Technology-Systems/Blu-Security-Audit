#!/bin/bash
# Helper functions para testes

# Carregar bibliotecas BATS
load 'bats-support/load'
load 'bats-assert/load'
load 'bats-file/load'

# Configurações globais de teste
export BATS_TEST_TIMEOUT=30
export TEST_TEMP_DIR="/tmp/bs_test_$$"
export MOCK_RESPONSES_DIR="tests/fixtures"

# Setup para cada teste
setup() {
    mkdir -p "$TEST_TEMP_DIR"
    export ORIGINAL_PATH="$PATH"
    export PATH="tests/mocks:$PATH"
}

# Teardown para cada teste
teardown() {
    export PATH="$ORIGINAL_PATH"
    rm -rf "$TEST_TEMP_DIR" || true
}

# Mock para comandos que requerem root
mock_bluetooth_cmd() {
    local cmd="$1"
    local mock_file="tests/mocks/$cmd"
    
    cat > "$mock_file" << MOCK_SCRIPT
#!/bin/bash
# Mock para $cmd
echo "MOCK: $cmd \$@" >&2
exit 0
MOCK_SCRIPT
    chmod +x "$mock_file"
}

# Função para gerar MAC address fake
generate_fake_mac() {
    printf '%02x:%02x:%02x:%02x:%02x:%02x\n' \
        $(($RANDOM % 256)) $(($RANDOM % 256)) $(($RANDOM % 256)) \
        $(($RANDOM % 256)) $(($RANDOM % 256)) $(($RANDOM % 256))
}

# Função para criar dispositivos fake
create_fake_device_list() {
    local count=${1:-3}
    for i in $(seq 1 $count); do
        echo -e "$(generate_fake_mac)\tDevice_$i"
    done
}
