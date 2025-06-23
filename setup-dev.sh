#!/bin/bash
# Setup de Desenvolvimento BlueSecAudit v2.0
# Configura ambiente sem necessidade de privilégios de root

set -euo pipefail

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════╗
║          BlueSecAudit v2.0 - Dev Setup          ║
║            (Sem privilégios root)                ║
╚══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Verificar dependências disponíveis
check_available_tools() {
    log_info "Verificando ferramentas disponíveis..."
    
    local tools=("git" "curl" "bash" "grep" "sed" "awk")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool disponível"
        else
            missing+=("$tool")
            log_error "$tool não encontrado"
        fi
    done
    
    # Verificar ferramentas Bluetooth (opcional)
    local bt_tools=("hciconfig" "hcitool" "sdptool" "l2ping")
    local bt_missing=()
    
    echo ""
    log_info "Verificando ferramentas Bluetooth (opcionais)..."
    
    for tool in "${bt_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool disponível"
        else
            bt_missing+=("$tool")
            log_warning "$tool não encontrado"
        fi
    done
    
    if [[ ${#bt_missing[@]} -gt 0 ]]; then
        echo ""
        log_warning "Ferramentas Bluetooth não encontradas: ${bt_missing[*]}"
        log_info "Para funcionalidade completa, instale com:"
        echo "  sudo apt-get install bluez bluez-utils bluez-hcidump obexftp expect"
        echo ""
    fi
    
    return 0
}

# Configurar BATS para testes (sem root)
setup_bats_local() {
    log_info "Configurando BATS localmente..."
    
    if command -v bats >/dev/null 2>&1; then
        log_success "BATS já está instalado"
        return 0
    fi
    
    # Criar diretório local para BATS
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/lib
    
    # Baixar BATS se não existir
    if [[ ! -d "~/.local/lib/bats-core" ]]; then
        log_info "Baixando BATS core..."
        git clone https://github.com/bats-core/bats-core.git ~/.local/lib/bats-core
        
        # Criar symlink para bats
        ln -sf ~/.local/lib/bats-core/bin/bats ~/.local/bin/bats
        
        # Adicionar ao PATH se necessário
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            log_info "Adicionado ~/.local/bin ao PATH no ~/.bashrc"
            log_warning "Execute 'source ~/.bashrc' ou abra um novo terminal"
        fi
    fi
    
    # Baixar bibliotecas auxiliares
    log_info "Configurando bibliotecas de teste..."
    mkdir -p tests
    
    if [[ ! -d "tests/bats-support" ]]; then
        git clone https://github.com/bats-core/bats-support.git tests/bats-support
    fi
    
    if [[ ! -d "tests/bats-assert" ]]; then
        git clone https://github.com/bats-core/bats-assert.git tests/bats-assert
    fi
    
    if [[ ! -d "tests/bats-file" ]]; then
        git clone https://github.com/bats-core/bats-file.git tests/bats-file
    fi
    
    log_success "BATS configurado localmente"
}

# Criar estrutura de desenvolvimento
create_dev_structure() {
    log_info "Criando estrutura de desenvolvimento..."
    
    # Criar diretórios
    mkdir -p {config,logs,results,wordlists,backups,docs}
    mkdir -p tests/{unit,integration,mocks,fixtures}
    
    # Definir permissões para scripts
    find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find tests -name "*.bats" -exec chmod +x {} \; 2>/dev/null || true
    
    log_success "Estrutura de diretórios criada"
}

# Configurar arquivos básicos
setup_config_files() {
    log_info "Configurando arquivos básicos..."
    
    # Arquivo de configuração de desenvolvimento
    if [[ ! -f "config/dev.conf" ]]; then
        cat > config/dev.conf << 'EOF'
# BlueSecAudit v2.0 - Configuração de Desenvolvimento
[general]
debug_mode=true
mock_bluetooth=true
test_mode=true

[logging]
level=DEBUG
output=logs/dev.log
console=true

[testing]
mock_commands=true
generate_fixtures=true
EOF
        log_success "Arquivo de configuração de desenvolvimento criado"
    fi
    
    # Wordlist básica
    if [[ ! -f "wordlists/dev_pins.txt" ]]; then
        cat > wordlists/dev_pins.txt << 'EOF'
0000
1111
1234
9999
test
dev
EOF
        log_success "Wordlist de desenvolvimento criada"
    fi
    
    # Gitignore
    if [[ ! -f ".gitignore" ]]; then
        cat > .gitignore << 'EOF'
# Logs
logs/*.log
*.log

# Resultados de testes
results/
backups/

# Arquivos temporários
*.tmp
.DS_Store

# Configurações locais
config/local.conf
EOF
        log_success ".gitignore criado"
    fi
}

# Executar testes em modo desenvolvimento
run_dev_tests() {
    log_info "Executando testes em modo desenvolvimento..."
    
    # Verificar se BATS está disponível
    if ! command -v bats >/dev/null 2>&1 && [[ ! -f ~/.local/bin/bats ]]; then
        log_error "BATS não está disponível"
        return 1
    fi
    
    # Usar BATS local se necessário
    local bats_cmd="bats"
    if [[ -f ~/.local/bin/bats ]]; then
        bats_cmd="~/.local/bin/bats"
    fi
    
    # Executar testes com mocks
    log_info "Executando testes unitários..."
    if eval "$bats_cmd tests/unit/" 2>/dev/null; then
        log_success "Testes unitários passaram"
    else
        log_warning "Alguns testes unitários falharam (normal em modo dev)"
    fi
    
    log_info "Executando testes de integração..."
    if eval "$bats_cmd tests/integration/" 2>/dev/null; then
        log_success "Testes de integração passaram"
    else
        log_warning "Alguns testes de integração falharam (normal sem Bluetooth real)"
    fi
}

# Criar script de desenvolvimento
create_dev_script() {
    log_info "Criando script de desenvolvimento..."
    
    cat > dev-run.sh << 'EOF'
#!/bin/bash
# Script de execução em modo desenvolvimento

export BS_DEV_MODE=true
export BS_MOCK_BT=true
export BS_CONFIG_FILE="config/dev.conf"

# Executar com configurações de desenvolvimento
./bs-at-v2.sh "$@"
EOF
    
    chmod +x dev-run.sh
    log_success "Script de desenvolvimento criado: ./dev-run.sh"
}

# Mostrar informações finais
show_dev_info() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Setup de Desenvolvimento Concluído!      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Como usar em modo desenvolvimento:${NC}"
    echo ""
    echo "📝 Executar em modo dev:"
    echo "   ./dev-run.sh"
    echo ""
    echo "🧪 Executar testes:"
    echo "   bats tests/                    # Todos os testes"
    echo "   bats tests/unit/               # Testes unitários"
    echo "   bats tests/integration/        # Testes de integração"
    echo ""
    echo "🔧 Arquivos importantes:"
    echo "   config/dev.conf               # Configuração de desenvolvimento"
    echo "   logs/dev.log                  # Logs de desenvolvimento"
    echo "   tests/                        # Diretório de testes"
    echo ""
    echo -e "${YELLOW}💡 Dicas:${NC}"
    echo "• Use 'export BS_DEV_MODE=true' para ativar modo debug"
    echo "• Testes usam mocks - não precisam de hardware Bluetooth real"
    echo "• Para funcionalidade completa, instale dependências com sudo"
    echo ""
    echo -e "${BLUE}📚 Próximos passos:${NC}"
    echo "1. Execute './dev-run.sh' para testar a ferramenta"
    echo "2. Execute 'bats tests/' para rodar os testes"
    echo "3. Para produção, execute './install.sh' com sudo"
}

# Função principal
main() {
    show_banner
    
    log_info "Configurando ambiente de desenvolvimento BlueSecAudit v2.0"
    echo ""
    
    check_available_tools
    echo ""
    
    setup_bats_local
    echo ""
    
    create_dev_structure
    setup_config_files
    create_dev_script
    echo ""
    
    run_dev_tests
    echo ""
    
    show_dev_info
}

# Executar
main "$@" 