#!/bin/bash
# real-world-setup.sh - Configuração final para ambiente real
# BlueSecAudit v2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎯 BlueSecAudit v2.0 - Real World Setup"
echo "======================================"
echo ""

# Verificar permissões
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ Este script precisa de privilégios root para configuração completa"
    echo "Execute: sudo ./real-world-setup.sh"
    exit 1
fi

echo "🔧 Configurando ambiente para produção..."

# 1. Configurar logs avançados
setup_logging() {
    echo "📝 Configurando sistema de logs..."
    
    mkdir -p /var/log/bluesecaudit/{captures,reports,audit}
    chown -R "$SUDO_USER:bluetooth" /var/log/bluesecaudit 2>/dev/null || true
    chmod -R 750 /var/log/bluesecaudit
    
    # Logrotate
    cat << 'EOF' > /etc/logrotate.d/bluesecaudit
/var/log/bluesecaudit/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
}
EOF
    
    echo "✅ Logging configurado"
}

# 2. Configurar permissões Bluetooth
setup_bluetooth_permissions() {
    echo "🔐 Configurando permissões Bluetooth..."
    
    # Adicionar usuário aos grupos necessários
    usermod -a -G bluetooth,dialout "$SUDO_USER" 2>/dev/null || true
    
    # Configurar Wireshark
    if command -v dumpcap >/dev/null 2>&1; then
        groupadd wireshark 2>/dev/null || true
        chgrp wireshark /usr/bin/dumpcap
        chmod 4755 /usr/bin/dumpcap
        usermod -a -G wireshark "$SUDO_USER" 2>/dev/null || true
    fi
    
    echo "✅ Permissões configuradas"
}

# 3. Verificar dependências críticas
verify_dependencies() {
    echo "🔍 Verificando dependências críticas..."
    
    local missing=()
    local tools=("bluetoothctl" "hcitool" "l2ping" "sdptool" "hcidump" "tshark")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ Dependências faltando: ${missing[*]}"
        echo "Execute: ./install.sh"
        return 1
    fi
    
    echo "✅ Todas as dependências estão instaladas"
}

# 4. Configurar adaptador Bluetooth
configure_bluetooth() {
    echo "📡 Configurando adaptador Bluetooth..."
    
    # Garantir que Bluetooth está ativo
    systemctl enable bluetooth
    systemctl start bluetooth
    
    # Configurar adaptador padrão
    if hciconfig hci0 >/dev/null 2>&1; then
        hciconfig hci0 up
        hciconfig hci0 piscan
        echo "✅ Adaptador hci0 configurado"
    else
        echo "⚠️ Adaptador hci0 não encontrado"
    fi
}

# 5. Criar estrutura de produção
create_production_structure() {
    echo "📁 Criando estrutura de produção..."
    
    # Criar diretórios com permissões corretas
    local dirs=("$SCRIPT_DIR/logs/production" "$SCRIPT_DIR/results/production" "$SCRIPT_DIR/config/production")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chown "$SUDO_USER:bluetooth" "$dir" 2>/dev/null || true
        chmod 750 "$dir"
    done
    
    # Criar arquivo de configuração de produção
    cat << 'EOF' > "$SCRIPT_DIR/config/production/audit.conf"
# BlueSecAudit v2.0 - Production Configuration

[general]
log_level=INFO
max_session_duration=3600
auto_cleanup=true

[bluetooth]
default_adapter=hci0
scan_timeout=30
connection_timeout=10

[security]
require_authorization=true
log_all_activities=true
encrypt_reports=false

[attacks]
enable_dos_attacks=true
enable_brute_force=true
enable_obex_access=true
max_pin_attempts=100

[reporting]
auto_generate_reports=true
report_format=html
include_technical_details=true
EOF
    
    chown "$SUDO_USER:bluetooth" "$SCRIPT_DIR/config/production/audit.conf"
    
    echo "✅ Estrutura de produção criada"
}

# 6. Configurar monitoramento
setup_monitoring() {
    echo "📊 Configurando monitoramento..."
    
    # Tornar scripts executáveis
    chmod +x "$SCRIPT_DIR"/*.sh
    chmod +x "$SCRIPT_DIR"/capture-bluetooth.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR"/production-monitor.sh 2>/dev/null || true
    
    # Criar link simbólico para fácil acesso
    ln -sf "$SCRIPT_DIR/bs-at-v2.sh" /usr/local/bin/bluesecaudit 2>/dev/null || true
    
    echo "✅ Monitoramento configurado"
}

# 7. Teste final do sistema
final_system_test() {
    echo "🧪 Executando teste final do sistema..."
    
    # Verificar adaptador
    if ! hciconfig hci0 >/dev/null 2>&1; then
        echo "❌ Adaptador Bluetooth não disponível"
        return 1
    fi
    
    # Teste de scanning básico
    echo "Testing basic scanning..."
    if timeout 10 hcitool scan >/dev/null 2>&1; then
        echo "✅ Scanning funcional"
    else
        echo "⚠️ Scanning limitado (normal sem dispositivos próximos)"
    fi
    
    # Verificar logs
    if [[ -d /var/log/bluesecaudit ]]; then
        echo "✅ Sistema de logs ativo"
    fi
    
    # Verificar permissões de usuário
    if groups "$SUDO_USER" | grep -q bluetooth; then
        echo "✅ Permissões de usuário corretas"
    fi
    
    echo "✅ Sistema pronto para produção"
}

# Função principal
main() {
    echo "Starting production setup..."
    
    setup_logging
    setup_bluetooth_permissions
    verify_dependencies
    configure_bluetooth
    create_production_structure
    setup_monitoring
    final_system_test
    
    echo ""
    echo "🎉 CONFIGURAÇÃO DE PRODUÇÃO CONCLUÍDA"
    echo "===================================="
    echo ""
    echo "📋 Próximos passos:"
    echo "  1. Logout/login para aplicar permissões de grupo"
    echo "  2. Execute: ./bs-at-v2.sh para iniciar auditoria"
    echo "  3. Execute: ./production-monitor.sh para monitoramento"
    echo ""
    echo "📁 Estrutura criada:"
    echo "  🗂️ Logs: /var/log/bluesecaudit/"
    echo "  🗂️ Config: $SCRIPT_DIR/config/production/"
    echo "  🗂️ Results: $SCRIPT_DIR/results/production/"
    echo ""
    echo "🚨 LEMBRETES IMPORTANTES:"
    echo "  ⚖️ Use apenas com autorização explícita"
    echo "  📋 Mantenha documentação de autorização"
    echo "  🔒 Respeite leis locais de cibersegurança"
    echo ""
    echo "✅ BlueSecAudit v2.0 pronto para uso em mundo real!"
}

# Executar
main "$@" 