#!/bin/bash
# Helper functions para testes BlueSecAudit v2.0

# Configurações globais de teste
export BATS_TEST_TIMEOUT=30
export MOCK_RESPONSES_DIR="tests/fixtures"

# Setup para cada teste
setup() {
    # Ensure TEST_TEMP_DIR is properly set and created
    export TEST_TEMP_DIR="/tmp/bs_test_${BATS_TEST_NUMBER}_$$"
    mkdir -p "$TEST_TEMP_DIR"
    export ORIGINAL_PATH="$PATH"
    export PATH="tests/mocks:$PATH"
}

# Teardown para cada teste
teardown() {
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
    fi
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    fi
}

# Funções de assert básicas (compatibilidade)
assert_success() {
    if [[ $status -ne 0 ]]; then
        echo "Expected success (exit code 0) but got exit code $status"
        echo "Output: $output"
        return 1
    fi
}

assert_failure() {
    if [[ $status -eq 0 ]]; then
        echo "Expected failure (non-zero exit code) but got success"
        echo "Output: $output"
        return 1
    fi
}

assert_output() {
    local expected="$1"
    if [[ "$1" == "--partial" ]]; then
        expected="$2"
        if [[ "$output" != *"$expected"* ]]; then
            echo "Expected output to contain '$expected' but got:"
            echo "$output"
            return 1
        fi
    elif [[ "$1" == "--regexp" ]]; then
        expected="$2"
        if [[ ! "$output" =~ $expected ]]; then
            echo "Expected output to match regex '$expected' but got:"
            echo "$output"
            return 1
        fi
    else
        if [[ "$output" != "$expected" ]]; then
            echo "Expected output '$expected' but got:"
            echo "$output"
            return 1
        fi
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file '$file' to exist but it doesn't"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "Expected file '$file' to not exist but it does"
        return 1
    fi
}

# Mock para comandos que requerem root
mock_bluetooth_cmd() {
    local cmd="$1"
    local mock_file="tests/mocks/$cmd"
    
    mkdir -p tests/mocks
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