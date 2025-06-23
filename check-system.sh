#!/bin/bash
# Script de Verificação de Sistema - BlueSecAudit v2.0
# Diagnóstica rapidamente o estado do sistema

set -euo pipefail

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         BlueSecAudit v2.0 - System Check        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Detectar sistema operacional
check_os() {
    echo -e "${BLUE}🖥️  Sistema Operacional:${NC}"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "   ✅ $PRETTY_NAME"
        echo "   📋 ID: $ID"
        echo "   🔢 Versão: $VERSION_ID"
        
        # Detectar pacotes corretos para este sistema
        case "$ID" in
            "ubuntu")
                if [[ "${VERSION_ID%%.*}" -ge 18 ]]; then
                    RECOMMENDED_PACKAGES="bluez bluez-hcidump bluez-tools"
                else
                    RECOMMENDED_PACKAGES="bluez bluez-utils bluez-hcidump"
                fi
                INSTALL_CMD="sudo apt-get install"
                ;;
            "debian")
                if [[ "${VERSION_ID%%.*}" -ge 10 ]]; then
                    RECOMMENDED_PACKAGES="bluez bluez-hcidump bluez-tools"
                else
                    RECOMMENDED_PACKAGES="bluez bluez-utils bluez-hcidump"
                fi
                INSTALL_CMD="sudo apt-get install"
                ;;
            *)
                RECOMMENDED_PACKAGES="bluez bluez-hcidump"
                INSTALL_CMD="sudo apt-get install"
                ;;
        esac
        
        echo "   📦 Pacotes recomendados: $RECOMMENDED_PACKAGES"
    else
        echo "   ❌ Não foi possível detectar a distribuição"
    fi
    echo ""
}

# Verificar privilégios
check_privileges() {
    echo -e "${BLUE}🔐 Privilégios:${NC}"
    
    if [[ $EUID -eq 0 ]]; then
        echo "   ✅ Executando como root"
    else
        echo "   ⚠️  Executando como usuário: $USER"
        
        if command -v sudo >/dev/null 2>&1; then
            if sudo -n true 2>/dev/null; then
                echo "   ✅ sudo disponível (sem senha)"
            else
                echo "   🔑 sudo disponível (requer senha)"
            fi
        else
            echo "   ❌ sudo não está disponível"
        fi
    fi
    echo ""
}

# Verificar ferramentas básicas
check_basic_tools() {
    echo -e "${BLUE}🛠️  Ferramentas Básicas:${NC}"
    
    local tools=("git" "curl" "bash" "grep" "sed" "awk" "make" "gcc")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool"
        else
            echo "   ❌ $tool"
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "   📦 Para instalar: $INSTALL_CMD ${missing[*]}"
    fi
    echo ""
}

# Verificar ferramentas Bluetooth
check_bluetooth_tools() {
    echo -e "${BLUE}📡 Ferramentas Bluetooth:${NC}"
    
    # Ferramentas essenciais
    local essential=("bluetoothctl")
    local essential_missing=()
    
    for tool in "${essential[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool (essencial)"
        else
            echo "   ❌ $tool (essencial)"
            essential_missing+=("$tool")
        fi
    done
    
    # Ferramentas opcionais
    local optional=("hciconfig" "hcitool" "sdptool" "l2ping" "obexftp" "expect")
    local optional_missing=()
    
    for tool in "${optional[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool"
        else
            echo "   ⚠️  $tool (opcional)"
            optional_missing+=("$tool")
        fi
    done
    
    if [[ ${#essential_missing[@]} -gt 0 ]]; then
        echo ""
        echo "   🚨 CRÍTICO: Instale as ferramentas essenciais:"
        echo "   📦 $INSTALL_CMD $RECOMMENDED_PACKAGES"
    fi
    
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        echo ""
        echo "   💡 OPCIONAL: Para funcionalidade completa:"
        echo "   📦 $INSTALL_CMD ${optional_missing[*]}"
    fi
    echo ""
}

# Verificar serviço Bluetooth
check_bluetooth_service() {
    echo -e "${BLUE}🔵 Serviço Bluetooth:${NC}"
    
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active bluetooth >/dev/null 2>&1; then
            echo "   ✅ Serviço ativo"
        else
            echo "   ⚠️  Serviço inativo"
            echo "   🔧 Para ativar: sudo systemctl start bluetooth"
        fi
        
        if systemctl is-enabled bluetooth >/dev/null 2>&1; then
            echo "   ✅ Serviço habilitado"
        else
            echo "   ⚠️  Serviço não habilitado"
            echo "   🔧 Para habilitar: sudo systemctl enable bluetooth"
        fi
    else
        echo "   ❓ systemctl não disponível - verificação manual necessária"
    fi
    echo ""
}

# Verificar adaptador Bluetooth
check_bluetooth_adapter() {
    echo -e "${BLUE}📶 Adaptador Bluetooth:${NC}"
    
    if command -v hciconfig >/dev/null 2>&1; then
        local adapters=$(hciconfig 2>/dev/null | grep -E "^hci[0-9]+" | cut -d: -f1)
        
        if [[ -n "$adapters" ]]; then
            for adapter in $adapters; do
                local status=$(hciconfig "$adapter" 2>/dev/null | grep -E "(UP|DOWN)")
                if echo "$status" | grep -q UP; then
                    echo "   ✅ $adapter (UP)"
                else
                    echo "   ⚠️  $adapter (DOWN)"
                    echo "   🔧 Para ativar: sudo hciconfig $adapter up"
                fi
            done
        else
            echo "   ❌ Nenhum adaptador detectado"
        fi
    elif command -v bluetoothctl >/dev/null 2>&1; then
        if bluetoothctl show >/dev/null 2>&1; then
            echo "   ✅ Adaptador detectado via bluetoothctl"
        else
            echo "   ❌ Nenhum adaptador detectado"
        fi
    else
        echo "   ❓ Não foi possível verificar adaptadores"
    fi
    echo ""
}

# Verificar estrutura do projeto
check_project_structure() {
    echo -e "${BLUE}📁 Estrutura do Projeto:${NC}"
    
    local required_files=("bs-at-v2.sh" "install.sh" "setup-dev.sh")
    local required_dirs=("lib" "tests")
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            if [[ -x "$file" ]]; then
                echo "   ✅ $file (executável)"
            else
                echo "   ⚠️  $file (não executável)"
                echo "   🔧 chmod +x $file"
            fi
        else
            echo "   ❌ $file (arquivo faltando)"
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local file_count=$(find "$dir" -name "*.sh" -o -name "*.bats" | wc -l)
            echo "   ✅ $dir/ ($file_count arquivos)"
        else
            echo "   ❌ $dir/ (diretório faltando)"
        fi
    done
    echo ""
}

# Verificar BATS
check_bats() {
    echo -e "${BLUE}🧪 Sistema de Testes (BATS):${NC}"
    
    if command -v bats >/dev/null 2>&1; then
        local bats_version=$(bats --version 2>/dev/null | head -1)
        echo "   ✅ BATS instalado: $bats_version"
    elif [[ -f ~/.local/bin/bats ]]; then
        echo "   ✅ BATS local disponível: ~/.local/bin/bats"
    else
        echo "   ❌ BATS não encontrado"
        echo "   🔧 Execute: ./setup-dev.sh"
    fi
    
    # Verificar bibliotecas de teste
    local bats_libs=("tests/bats-support" "tests/bats-assert" "tests/bats-file")
    for lib in "${bats_libs[@]}"; do
        if [[ -d "$lib" ]]; then
            echo "   ✅ $(basename $lib)"
        else
            echo "   ❌ $(basename $lib)"
        fi
    done
    echo ""
}

# Mostrar recomendações
show_recommendations() {
    echo -e "${BLUE}💡 Recomendações:${NC}"
    echo ""
    
    # Verificar o que está faltando e dar sugestões
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo "   🚨 CRÍTICO: Instalar Bluetooth:"
        echo "      sudo ./install.sh"
        echo ""
    fi
    
    if ! command -v bats >/dev/null 2>&1 && [[ ! -f ~/.local/bin/bats ]]; then
        echo "   🛠️  Para desenvolvimento e testes:"
        echo "      ./setup-dev.sh"
        echo ""
    fi
    
    if command -v bluetoothctl >/dev/null 2>&1; then
        echo "   ✅ Para usar a ferramenta:"
        echo "      ./bs-at-v2.sh"
        echo ""
        
        echo "   🧪 Para executar testes:"
        echo "      bats tests/"
        echo ""
    fi
    
    echo "   📚 Para mais informações:"
    echo "      cat GUIA_RÁPIDO.md"
}

# Função principal
main() {
    show_header
    check_os
    check_privileges
    check_basic_tools
    check_bluetooth_tools
    check_bluetooth_service
    check_bluetooth_adapter
    check_project_structure
    check_bats
    show_recommendations
}

# Executar
main "$@" 