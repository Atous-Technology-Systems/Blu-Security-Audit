#!/bin/bash
# Script de instalação do BlueSecAudit v2.0
# Configura dependências, testes e ambiente

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Informações do projeto
PROJECT_NAME="BlueSecAudit v2.0"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funções de output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner de instalação
show_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════╗
║              BlueSecAudit v2.0                   ║
║                Instalador                        ║
╚══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Verificar sistema operacional
check_system() {
    log_info "Verificando sistema operacional..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "Sistema Linux detectado"
        
        # Detectar distribuição
        if command -v apt-get >/dev/null 2>&1; then
            PACKAGE_MANAGER="apt"
            log_info "Gerenciador de pacotes: APT"
        elif command -v yum >/dev/null 2>&1; then
            PACKAGE_MANAGER="yum"
            log_info "Gerenciador de pacotes: YUM"
        elif command -v pacman >/dev/null 2>&1; then
            PACKAGE_MANAGER="pacman"
            log_info "Gerenciador de pacotes: Pacman"
        else
            log_warning "Gerenciador de pacotes não detectado automaticamente"
            PACKAGE_MANAGER="manual"
        fi
    else
        log_error "Sistema não suportado. BlueSecAudit requer Linux."
        exit 1
    fi
}

# Verificar privilégios
check_privileges() {
    log_info "Verificando privilégios..."
    
    if [[ $EUID -ne 0 ]]; then
        log_warning "Não está executando como root"
        log_info "Algumas funcionalidades podem requerer sudo"
    else
        log_success "Executando como root"
    fi
}

# Detectar distribuição e versão específica
detect_distro() {
    log_info "Detectando distribuição do sistema..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_NAME="$PRETTY_NAME"
        
        log_success "Sistema detectado: $DISTRO_NAME"
        
        # Detecção específica de pacotes
        case "$DISTRO_ID" in
            "ubuntu")
                if [[ "${DISTRO_VERSION%%.*}" -ge 18 ]]; then
                    # Ubuntu 18.04+ - bluez-utils foi integrado ao bluez
                    BLUEZ_PACKAGES="bluez bluez-hcidump bluez-tools"
                else
                    # Ubuntu mais antigo
                    BLUEZ_PACKAGES="bluez bluez-utils bluez-hcidump"
                fi
                ;;
            "debian")
                if [[ "${DISTRO_VERSION%%.*}" -ge 10 ]]; then
                    # Debian 10+ (Buster)
                    BLUEZ_PACKAGES="bluez bluez-hcidump bluez-tools"
                else
                    # Debian mais antigo
                    BLUEZ_PACKAGES="bluez bluez-utils bluez-hcidump"
                fi
                ;;
            *)
                # Padrão para outras distribuições baseadas em Debian
                BLUEZ_PACKAGES="bluez bluez-hcidump"
                ;;
        esac
    else
        log_warning "Não foi possível detectar a distribuição"
        BLUEZ_PACKAGES="bluez bluez-hcidump"
    fi
    
    log_info "Pacotes Bluetooth a instalar: $BLUEZ_PACKAGES"
}

# Instalar dependências
install_dependencies() {
    log_info "Instalando dependências do sistema..."
    
    # Detectar distribuição primeiro
    detect_distro
    
    # Verificar se tem permissões adequadas
    if [[ $EUID -ne 0 ]] && [[ "$PACKAGE_MANAGER" != "manual" ]]; then
        log_warning "Sem privilégios de root - tentando com sudo"
        
        # Verificar se sudo está disponível
        if ! command -v sudo >/dev/null 2>&1; then
            log_error "sudo não está disponível"
            log_info "Execute como root ou instale as dependências manualmente"
            PACKAGE_MANAGER="manual"
        else
            # Testar sudo
            if ! sudo -n true 2>/dev/null; then
                log_warning "sudo requer senha"
                echo "Você precisa inserir sua senha para instalar as dependências..."
            fi
        fi
    fi
    
    case "$PACKAGE_MANAGER" in
        "apt")
            # Atualizar lista de pacotes primeiro
            log_info "Atualizando lista de pacotes..."
            if [[ $EUID -eq 0 ]]; then
                apt-get update
            else
                sudo apt-get update
            fi
            
            # Instalar pacotes básicos
            local basic_packages="git curl build-essential expect"
            
            # Tentar instalar OBEX (pode não estar disponível em todas as versões)
            local obex_packages="obexftp"
            
            log_info "Instalando pacotes básicos..."
            if [[ $EUID -eq 0 ]]; then
                apt-get install -y $basic_packages || {
                    log_error "Falha ao instalar pacotes básicos"
                    return 1
                }
            else
                sudo apt-get install -y $basic_packages || {
                    log_error "Falha ao instalar pacotes básicos"
                    return 1
                }
            fi
            
            log_info "Instalando pacotes Bluetooth..."
            if [[ $EUID -eq 0 ]]; then
                apt-get install -y $BLUEZ_PACKAGES || {
                    log_warning "Alguns pacotes Bluetooth falharam - tentando alternativas"
                    apt-get install -y bluez || log_error "Falha ao instalar bluez básico"
                }
            else
                sudo apt-get install -y $BLUEZ_PACKAGES || {
                    log_warning "Alguns pacotes Bluetooth falharam - tentando alternativas"
                    sudo apt-get install -y bluez || log_error "Falha ao instalar bluez básico"
                }
            fi
            
            log_info "Tentando instalar OBEX (opcional)..."
            if [[ $EUID -eq 0 ]]; then
                apt-get install -y $obex_packages || {
                    log_warning "OBEX não disponível - funcionalidade limitada"
                }
            else
                sudo apt-get install -y $obex_packages || {
                    log_warning "OBEX não disponível - funcionalidade limitada"
                }
            fi
            ;;
        "yum")
            if [[ $EUID -eq 0 ]]; then
                yum update -y
                yum install -y \
                    bluez \
                    bluez-libs \
                    obexftp \
                    expect \
                    git \
                    curl \
                    gcc \
                    make
            else
                sudo yum update -y
                sudo yum install -y \
                    bluez \
                    bluez-libs \
                    obexftp \
                    expect \
                    git \
                    curl \
                    gcc \
                    make
            fi
            ;;
        "pacman")
            if [[ $EUID -eq 0 ]]; then
                pacman -Syu --noconfirm
                pacman -S --noconfirm \
                    bluez \
                    bluez-utils \
                    bluez-hcidump \
                    obexftp \
                    expect \
                    git \
                    curl \
                    base-devel
            else
                sudo pacman -Syu --noconfirm
                sudo pacman -S --noconfirm \
                    bluez \
                    bluez-utils \
                    bluez-hcidump \
                    obexftp \
                    expect \
                    git \
                    curl \
                    base-devel
            fi
            ;;
        "manual")
            show_manual_install_commands
            return 0
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_success "Dependências do sistema instaladas"
        verify_bluetooth_installation
    else
        log_error "Falha na instalação de dependências"
        log_info "Tente executar os comandos manualmente ou como root"
        show_manual_install_commands
        return 1
    fi
}

# Mostrar comandos manuais adaptados ao sistema
show_manual_install_commands() {
    log_warning "Comandos para instalação manual:"
    echo ""
    
    case "$PACKAGE_MANAGER" in
        "apt"|"manual")
            echo "Para o seu sistema (${DISTRO_NAME:-Ubuntu/Debian}):"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install git curl build-essential expect"
            echo "  sudo apt-get install ${BLUEZ_PACKAGES:-bluez bluez-hcidump}"
            echo "  sudo apt-get install obexftp  # Opcional"
            ;;
        "yum")
            echo "Para CentOS/RHEL/Fedora:"
            echo "  sudo yum update"
            echo "  sudo yum install bluez bluez-libs git curl gcc make expect obexftp"
            ;;
        "pacman")
            echo "Para Arch Linux:"
            echo "  sudo pacman -Syu"
            echo "  sudo pacman -S bluez bluez-utils bluez-hcidump git curl base-devel expect obexftp"
            ;;
    esac
    
    echo ""
    echo "Depois execute: ./setup-dev.sh"
    echo ""
    read -p "Pressione Enter quando as dependências estiverem instaladas..."
}

# Verificar instalação do Bluetooth
verify_bluetooth_installation() {
    log_info "Verificando instalação do Bluetooth..."
    
    local required_tools=("bluetoothctl")
    local optional_tools=("hciconfig" "hcitool" "sdptool" "l2ping" "obexftp")
    local missing_required=()
    local missing_optional=()
    
    # Verificar ferramentas obrigatórias
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required+=("$tool")
        else
            log_success "$tool instalado"
        fi
    done
    
    # Verificar ferramentas opcionais
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        else
            log_success "$tool instalado"
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "Ferramentas obrigatórias faltando: ${missing_required[*]}"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Ferramentas opcionais faltando: ${missing_optional[*]}"
        log_info "Algumas funcionalidades podem estar limitadas"
    fi
    
    # Verificar se serviço Bluetooth está disponível
    if systemctl is-enabled bluetooth >/dev/null 2>&1; then
        log_success "Serviço Bluetooth configurado"
    else
        log_warning "Serviço Bluetooth pode não estar configurado"
        log_info "Execute: sudo systemctl enable bluetooth"
    fi
    
    return 0
}

# Configurar BATS para testes
setup_testing() {
    log_info "Configurando ambiente de testes..."
    
    # Executar script de configuração de testes
    if [[ -f "tests/test_setup.sh" ]]; then
        bash tests/test_setup.sh
        log_success "Ambiente de testes configurado"
    else
        log_warning "Script de configuração de testes não encontrado"
    fi
}

# Criar estrutura de diretórios
create_directories() {
    log_info "Criando estrutura de diretórios..."
    
    mkdir -p {config,logs,results,wordlists,backups}
    
    # Configurar permissões
    chmod 755 lib/*.sh
    chmod 755 bs-at-v2.sh
    chmod 755 install.sh
    
    log_success "Estrutura de diretórios criada"
}

# Configurar arquivos de configuração
setup_config() {
    log_info "Configurando arquivos de configuração..."
    
    # Criar arquivo de configuração padrão
    cat > config/bs-audit.conf << 'EOF'
# BlueSecAudit v2.0 - Configuração
[general]
default_adapter=hci0
log_level=INFO
max_scan_time=30
capture_packets=true

[attacks]
bluesmack_timeout=30
bruteforce_max_attempts=20
obex_timeout=45

[reporting]
format=html
include_timestamps=true
auto_backup=true
EOF
    
    # Criar wordlists padrão
    cat > wordlists/common_pins.txt << 'EOF'
0000
1111
1234
9999
0001
1212
2580
1357
2468
1122
EOF
    
    log_success "Arquivos de configuração criados"
}

# Executar testes
run_tests() {
    log_info "Executando testes do sistema..."
    
    if command -v bats >/dev/null 2>&1; then
        # Executar testes unitários
        log_info "Executando testes unitários..."
        if bats tests/unit/; then
            log_success "Testes unitários passaram"
        else
            log_warning "Alguns testes unitários falharam"
        fi
        
        # Executar testes de integração
        log_info "Executando testes de integração..."
        if bats tests/integration/; then
            log_success "Testes de integração passaram"
        else
            log_warning "Alguns testes de integração falharam"
        fi
    else
        log_warning "BATS não está instalado - pulando testes"
    fi
}

# Verificar instalação
verify_installation() {
    log_info "Verificando instalação..."
    
    local issues=0
    
    # Verificar arquivos principais
    if [[ ! -f "bs-at-v2.sh" ]]; then
        log_error "Script principal não encontrado"
        issues=$((issues + 1))
    fi
    
    # Verificar módulos
    for module in lib/utils.sh lib/bluetooth.sh lib/attacks.sh lib/ui.sh; do
        if [[ ! -f "$module" ]]; then
            log_error "Módulo não encontrado: $module"
            issues=$((issues + 1))
        fi
    done
    
    # Verificar dependências
    local deps=("hciconfig" "hcitool" "sdptool" "l2ping")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Dependência não encontrada: $dep"
            issues=$((issues + 1))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_success "Instalação verificada com sucesso"
        return 0
    else
        log_error "Encontrados $issues problemas na instalação"
        return 1
    fi
}

# Mostrar informações pós-instalação
show_post_install_info() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            Instalação Concluída!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Como usar:${NC}"
    echo "  ./bs-at-v2.sh                 # Executar ferramenta"
    echo "  bats tests/                   # Executar todos os testes"
    echo "  bats tests/unit/              # Executar testes unitários"
    echo "  bats tests/integration/       # Executar testes de integração"
    echo ""
    echo -e "${BLUE}Diretórios importantes:${NC}"
    echo "  lib/                          # Módulos do sistema"
    echo "  config/                       # Arquivos de configuração"
    echo "  logs/                         # Arquivos de log"
    echo "  results/                      # Resultados de auditoria"
    echo "  wordlists/                    # Wordlists para ataques"
    echo ""
    echo -e "${YELLOW}Aviso Legal:${NC}"
    echo "Esta ferramenta é destinada apenas para fins educacionais"
    echo "e testes de segurança autorizados. O uso inadequado pode"
    echo "violar leis locais e regulamentações."
    echo ""
    echo -e "${BLUE}Documentação:${NC} Consulte ROADMAP.md para informações detalhadas"
}

# Função principal
main() {
    show_banner
    
    log_info "Iniciando instalação do $PROJECT_NAME"
    echo ""
    
    # Verificações pré-instalação
    check_system
    check_privileges
    
    echo ""
    
    # Instalação
    install_dependencies
    setup_testing
    create_directories
    setup_config
    
    echo ""
    
    # Testes
    run_tests
    
    echo ""
    
    # Verificação final
    if verify_installation; then
        show_post_install_info
    else
        log_error "Instalação falhou na verificação"
        exit 1
    fi
}

# Opções de linha de comando
case "${1:-install}" in
    "install")
        main
        ;;
    "test")
        run_tests
        ;;
    "verify")
        verify_installation
        ;;
    "help")
        echo "Uso: $0 [install|test|verify|help]"
        echo ""
        echo "Comandos:"
        echo "  install    Instalar BlueSecAudit (padrão)"
        echo "  test       Executar apenas os testes"
        echo "  verify     Verificar instalação existente"
        echo "  help       Mostrar esta ajuda"
        ;;
    *)
        echo "Comando desconhecido: $1"
        echo "Use '$0 help' para ver os comandos disponíveis"
        exit 1
        ;;
esac 