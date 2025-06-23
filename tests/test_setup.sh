#!/bin/bash
# Script de configuração de testes para BlueSecAudit
# Instala e configura BATS (Bash Automated Testing System)

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Configurando ambiente de testes...${NC}"

# Verificar se git está instalado
if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERRO] Git é necessário para instalar BATS${NC}"
    exit 1
fi

# Criar diretório de testes se não existir
mkdir -p tests/{unit,integration,mocks,fixtures}

# Baixar BATS se não estiver instalado
if ! command -v bats &> /dev/null; then
    echo -e "${YELLOW}[*] Instalando BATS...${NC}"
    
    # Instalar BATS core
    git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
    cd /tmp/bats-core
    sudo ./install.sh /usr/local
    cd - > /dev/null
    
    # Instalar bibliotecas auxiliares
    git clone https://github.com/bats-core/bats-support.git tests/bats-support
    git clone https://github.com/bats-core/bats-assert.git tests/bats-assert
    git clone https://github.com/bats-core/bats-file.git tests/bats-file
    
    echo -e "${GREEN}[+] BATS instalado com sucesso${NC}"
else
    echo -e "${GREEN}[+] BATS já está instalado${NC}"
fi

# Criar arquivo de configuração de teste
cat > tests/test_helper.bash << 'EOF'
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
EOF

echo -e "${GREEN}[+] Ambiente de testes configurado${NC}"
echo -e "${YELLOW}[*] Execute 'bats tests/' para rodar todos os testes${NC}" 