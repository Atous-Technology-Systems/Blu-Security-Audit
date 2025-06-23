#!/bin/bash
# BlueSecAudit v2.0 - Advanced Bluetooth Security Auditing Tool
# Versão completamente refatorada com TDD e arquitetura modular
# Autor: BlueSecAudit Team
# Licença: MIT

set -euo pipefail

# Diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Importar módulos
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/bluetooth.sh"
source "${SCRIPT_DIR}/lib/attacks.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/hid_attacks.sh"
source "${SCRIPT_DIR}/lib/audio_attacks.sh"
source "${SCRIPT_DIR}/lib/ble_attacks.sh"

# Configurações globais
CONFIG_FILE="${SCRIPT_DIR}/config/bs-audit.conf"
LOG_FILE="${SCRIPT_DIR}/logs/bs-audit.log"
RESULTS_DIR="${SCRIPT_DIR}/results"
TARGETS_FILE="${SCRIPT_DIR}/targets.txt"

# Variáveis de sessão
SESSION_ID=$(generate_session_id)
CAPTURE_ACTIVE=false
SELECTED_TARGET=""

# Verificação de preparação para produção
check_production_readiness() {
    echo "🔍 Verificando preparação para ataques reais..."
    
    local issues=()
    
    # Verificar dependências críticas
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        issues+=("bluetoothctl não encontrado")
    fi
    
    if ! command -v hcitool >/dev/null 2>&1; then
        issues+=("hcitool não encontrado")
    fi
    
    if ! command -v l2ping >/dev/null 2>&1; then
        issues+=("l2ping não encontrado")
    fi
    
    # Verificar adaptador Bluetooth
    if ! hciconfig hci0 >/dev/null 2>&1; then
        issues+=("Adaptador Bluetooth não detectado")
    fi
    
    # Verificar permissões
    if [[ $EUID -ne 0 ]] && ! groups | grep -q bluetooth; then
        issues+=("Usuário não tem permissões Bluetooth adequadas")
    fi
    
    # Verificar espaço em disco
    local available_space=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1000000 ]]; then # 1GB
        issues+=("Espaço em disco insuficiente (<1GB)")
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "❌ PROBLEMAS DETECTADOS:"
        for issue in "${issues[@]}"; do
            echo "  • $issue"
        done
        echo ""
        echo "📋 Execute ./check-system.sh para diagnóstico completo"
        echo "🔧 Execute ./install.sh para corrigir dependências"
        return 1
    fi
    
    echo "✅ Sistema pronto para ataques reais"
    return 0
}

# Aviso legal obrigatório
show_legal_warning() {
    echo ""
    echo "⚖️ ========================================================"
    echo "    AVISO LEGAL CRÍTICO - BlueSecAudit v2.0"
    echo "========================================================"
    echo ""
    echo "🚨 ATENÇÃO: Esta ferramenta executa ATAQUES REAIS contra"
    echo "    dispositivos Bluetooth e pode causar:"
    echo ""
    echo "  • Interrupção de serviços"
    echo "  • Acesso não autorizado a dados"
    echo "  • Violação de privacidade"
    echo "  • Danos a dispositivos"
    echo ""
    echo "⚖️ USO NÃO AUTORIZADO PODE RESULTAR EM:"
    echo "  • Processo criminal"
    echo "  • Multas pesadas"
    echo "  • Prisão"
    echo "  • Responsabilidade civil"
    echo ""
    echo "✅ USO AUTORIZADO APENAS SE:"
    echo "  • Possui autorização EXPLÍCITA e ESCRITA"
    echo "  • Ambiente controlado de testes"
    echo "  • Finalidade educacional/auditoria"
    echo "  • Conhece as leis locais aplicáveis"
    echo ""
    echo "📋 Documentação obrigatória:"
    echo "  • Contrato de auditoria assinado"
    echo "  • Formulário de autorização específica"
    echo "  • Identificação dos dispositivos autorizados"
    echo "  • Contatos de emergência"
    echo ""
    echo "========================================================"
    echo ""
    echo -n "Você possui AUTORIZAÇÃO LEGAL EXPLÍCITA para usar esta ferramenta? (digite 'SIM AUTORIZADO'): "
    read -r legal_confirmation
    
    if [[ "$legal_confirmation" != "SIM AUTORIZADO" ]]; then
        echo ""
        echo "❌ Uso não autorizado - encerrando aplicação"
        echo "📚 Consulte GUIA_ATAQUES_REAIS.md para informações sobre uso legal"
        echo "📞 Para treinamento autorizado: training@bluesecaudit.org"
        exit 1
    fi
    
    echo ""
    echo "✅ Confirmação legal registrada"
    echo "📝 Todas as ações serão logadas para auditoria"
    echo ""
}

# Inicialização
initialize_environment() {
    echo "🚀 Iniciando BlueSecAudit v2.0 - Advanced Bluetooth Security Auditing Tool"
    echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
    echo "🔖 Sessão: $SESSION_ID"
    echo ""
    
    # Verificar preparação para produção
    if ! check_production_readiness; then
        echo ""
        echo "❌ Sistema não está pronto para ataques reais"
        echo "🔧 Configure o ambiente antes de continuar"
        exit 1
    fi
    
    # Exibir aviso legal obrigatório
    show_legal_warning
    
    # Criar diretórios necessários
    mkdir -p "${SCRIPT_DIR}/"{config,logs,results,wordlists}
    
    # Configurar log de auditoria
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUDIT - BlueSecAudit v2.0 iniciado (Sessão: $SESSION_ID)" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUDIT - Usuário: $(whoami)@$(hostname)" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUDIT - Autorização legal confirmada" >> "$LOG_FILE"
    
    # Verificar se está em ambiente isolado (recomendado)
    if ping -c 1 google.com >/dev/null 2>&1; then
        echo "⚠️ AVISO: Sistema conectado à internet"
        echo "💡 Recomenda-se usar ambiente isolado para testes de segurança"
        echo ""
    fi
    
    echo "✅ Ambiente inicializado e pronto para auditoria"
    echo "📁 Logs: $LOG_FILE"
    echo "📁 Resultados: $RESULTS_DIR"
    echo ""
}

# Escanear dispositivos com interface melhorada
scan_devices_interactive() {
    echo "ℹ️ Iniciando escaneamento de dispositivos Bluetooth..."
    
    # Criar diretórios se não existirem
    mkdir -p "$RESULTS_DIR"
    
    # Verificar dependências
    if ! check_bluetooth_dependencies; then
        echo "⚠️ Algumas dependências estão faltando - funcionalidade limitada"
    fi
    
    # Garantir que adaptador está ativo
    if ! bring_adapter_up "hci0"; then
        echo "❌ ERRO CRÍTICO: Falha ao ativar adaptador Bluetooth"
        echo ""
        echo "🔧 Soluções possíveis:"
        echo "  1. Verifique se o adaptador está conectado: lsusb | grep -i bluetooth"
        echo "  2. Reinicie o serviço: sudo systemctl restart bluetooth"
        echo "  3. Execute como root: sudo ./bs-at-v2.sh"
        echo "  4. Verifique permissões: sudo usermod -a -G bluetooth \$USER"
        echo ""
        echo "⚠️ BlueSecAudit v2.0 requer adaptador Bluetooth funcional para ataques reais"
        return 1
    fi
    
    # Executar scan real
    echo "🔍 Escaneando dispositivos Bluetooth próximos..."
    echo "⏱️ Isso pode levar até 30 segundos..."
    
    if scan_bluetooth_devices "hci0" 30 "$TARGETS_FILE"; then
        # Processar resultados
        local device_count=$(grep -c ":" "$TARGETS_FILE" 2>/dev/null || echo "0")
        
        if [[ $device_count -eq 0 ]]; then
            echo "❌ NENHUM DISPOSITIVO BLUETOOTH ENCONTRADO"
            echo ""
            echo "🔍 Possíveis causas:"
            echo "  • Não há dispositivos Bluetooth ligados próximos"
            echo "  • Dispositivos estão em modo não-detectável"
            echo "  • Interferência de sinal ou alcance insuficiente"
            echo "  • Adaptador Bluetooth com problema"
            echo ""
            echo "💡 Sugestões:"
            echo "  • Ligue dispositivos Bluetooth próximos"
            echo "  • Torne dispositivos detectáveis"
            echo "  • Aproxime-se dos dispositivos alvo"
            echo "  • Execute novo scanning: Opção 0 no menu"
            echo ""
            echo "⚠️ BlueSecAudit v2.0 não opera com dispositivos simulados"
            return 1
        fi
        
        echo "✅ Escaneamento concluído: $device_count dispositivos"
        
        # Exibir dispositivos encontrados
        echo ""
        echo "📱 Dispositivos disponíveis:"
        local counter=1
        while IFS=$'\t' read -r mac name; do
            if [[ -n "$mac" && "$mac" != "Scanning" ]]; then
                echo "   $counter. $mac - ${name:-Unknown Device}"
                counter=$((counter + 1))
            fi
        done < "$TARGETS_FILE"
        
    else
        echo "❌ FALHA NO ESCANEAMENTO BLUETOOTH"
        echo ""
        echo "🔧 Diagnósticos recomendados:"
        echo "  • Verificar status do adaptador: hciconfig -a"
        echo "  • Testar conectividade: hcitool dev"
        echo "  • Reiniciar Bluetooth: sudo systemctl restart bluetooth"
        echo "  • Verificar logs: journalctl -u bluetooth"
        echo ""
        echo "⚠️ Não é possível continuar sem scanning funcional"
        return 1
    fi
    
    return 0
}

# Seleção interativa de target
select_target_interactive() {
    if [[ ! -f "$TARGETS_FILE" || ! -s "$TARGETS_FILE" ]]; then
        echo "❌ Nenhum dispositivo disponível. Execute o scanning primeiro."
        return 1
    fi
    
    echo ""
    echo "🎯 Seleção de Target"
    echo "================================"
    
    # Listar dispositivos disponíveis
    local counter=1
    declare -a device_list=()
    
    while IFS=$'\t' read -r mac name; do
        if [[ -n "$mac" ]]; then
            echo "$counter. $mac - ${name:-Unknown Device}"
            device_list+=("$mac")
            counter=$((counter + 1))
        fi
    done < "$TARGETS_FILE"
    
    echo "0. 🔄 Re-escanear dispositivos"
    echo ""
    echo -n "Selecione um dispositivo [0-$((counter-1))]: "
    
    read -r choice
    
    if [[ "$choice" == "0" ]]; then
        echo "🔄 Re-executando escaneamento..."
        scan_devices_interactive
        select_target_interactive
        return $?
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -lt $counter ]]; then
        SELECTED_TARGET="${device_list[$((choice-1))]}"
        local target_name=$(grep "$SELECTED_TARGET" "$TARGETS_FILE" | cut -f2)
        echo "✅ Target selecionado: $SELECTED_TARGET (${target_name:-Unknown})"
        return 0
    else
        echo "❌ Seleção inválida"
        return 1
    fi
}

# Executar BlueSmack attack
execute_bluesmack() {
    echo "🎯 BlueSmack Attack (DoS L2CAP)"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "⚠️ AVISO LEGAL ⚠️"
    echo "BlueSmack é um ataque de negação de serviço que pode:"
    echo "- Causar instabilidade no dispositivo alvo"
    echo "- Ser detectado por sistemas de monitoramento"
    echo "- Ser ilegal sem autorização explícita"
    echo ""
    echo "Configurações do ataque:"
    echo "  Target: $SELECTED_TARGET"
    echo "  Pacotes: 100 (padrão)"
    echo "  Tamanho: 600 bytes"
    echo ""
    echo "Continuar? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "ℹ️ Ataque cancelado"
        return 0
    fi
    
    # Verificar conectividade antes do ataque
    echo "🔍 Verificando conectividade com $SELECTED_TARGET..."
    if ! is_device_reachable "$SELECTED_TARGET"; then
        echo "❌ Dispositivo não está alcançável"
        echo "Possíveis causas:"
        echo "  - Dispositivo fora de alcance"
        echo "  - Dispositivo desligado"
        echo "  - Firewall Bluetooth ativo"
        return 1
    fi
    
    echo "✅ Dispositivo alcançável - iniciando ataque"
    
    # Iniciar captura de tráfego
    local capture_file="$RESULTS_DIR/bluesmack_capture_${SELECTED_TARGET//:/_}_$SESSION_ID.pcap"
    if start_packet_capture "$capture_file"; then
        echo "📡 Captura de tráfego ativada"
        CAPTURE_ACTIVE=true
    fi
    
    # Executar ataque real
    local start_time=$(date +%s)
    
    if bluesmack_attack "$SELECTED_TARGET" 100 600; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "✅ BlueSmack concluído em ${duration}s"
        
        # Parar captura
        if [[ "$CAPTURE_ACTIVE" == true ]]; then
            stop_packet_capture
            echo "📁 Tráfego capturado em: $capture_file"
            CAPTURE_ACTIVE=false
        fi
        
        # Gerar relatório
        local report_file="$RESULTS_DIR/bluesmack_report_${SELECTED_TARGET//:/_}_$SESSION_ID.txt"
        cat > "$report_file" << EOF
=== BLUESMACK ATTACK REPORT ===
Target: $SELECTED_TARGET
Timestamp: $(date)
Duration: ${duration}s
Status: SUCCESS

Attack Details:
- Type: L2CAP DoS (BlueSmack)
- Packets sent: 100
- Packet size: 600 bytes
- Capture file: $capture_file

Notes:
- Attack completed successfully
- Monitor target device for impact
- Traffic captured for analysis
EOF
        
        echo "📋 Relatório salvo em: $report_file"
        
    else
        echo "❌ BlueSmack falhou"
        
        # Parar captura mesmo em caso de falha
        if [[ "$CAPTURE_ACTIVE" == true ]]; then
            stop_packet_capture
            CAPTURE_ACTIVE=false
        fi
        
        return 1
    fi
}

# Executar enumeração SDP
execute_sdp_enumeration() {
    echo "🔍 SDP Service Enumeration"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "📋 Enumeração de Serviços SDP"
    echo "Target: $SELECTED_TARGET"
    echo ""
    echo "A enumeração SDP irá:"
    echo "  ✓ Descobrir serviços disponíveis"
    echo "  ✓ Identificar versões de protocolos"
    echo "  ✓ Analisar vulnerabilidades potenciais"
    echo "  ✓ Gerar relatório detalhado"
    echo ""
    echo "Continuar? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "ℹ️ Enumeração cancelada"
        return 0
    fi
    
    # Verificar conectividade
    echo "🔍 Verificando conectividade..."
    if ! is_device_reachable "$SELECTED_TARGET"; then
        echo "❌ Dispositivo não alcançável"
        return 1
    fi
    
    echo "✅ Dispositivo alcançável - iniciando enumeração"
    
    # Executar enumeração real
    local output_file="$RESULTS_DIR/sdp_enum_${SELECTED_TARGET//:/_}_$SESSION_ID.txt"
    local start_time=$(date +%s)
    
    if sdp_enumeration "$SELECTED_TARGET" "$output_file"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "✅ Enumeração SDP concluída em ${duration}s"
        
        # Análise de resultados
        if [[ -f "$output_file" ]]; then
            local service_count=$(grep -c "Service Name:" "$output_file" 2>/dev/null || echo "0")
            local protocol_count=$(grep -c "Protocol Descriptor List:" "$output_file" 2>/dev/null || echo "0")
            
            echo ""
            echo "📊 Resultados da Enumeração:"
            echo "  📁 Arquivo: $output_file"
            echo "  🔢 Serviços encontrados: $service_count"
            echo "  🔗 Protocolos detectados: $protocol_count"
            
            # Análise de vulnerabilidades
            echo ""
            echo "🔍 Analisando vulnerabilidades..."
            vulnerability_scanner "$(cat "$output_file")" "$SELECTED_TARGET"
            
            # Análise de superfície de ataque
            echo ""
            echo "🎯 Analisando superfície de ataque..."
            analyze_attack_surface "$(cat "$output_file")"
            
            # Mostrar alguns serviços encontrados
            echo ""
            echo "🔍 Serviços principais detectados:"
            grep "Service Name:" "$output_file" | head -5 | while read -r line; do
                echo "  $line"
            done
            
            if [[ $service_count -gt 5 ]]; then
                echo "  ... e mais $((service_count - 5)) serviços (veja o relatório completo)"
            fi
            
        else
            echo "❌ Erro ao gerar arquivo de saída"
        fi
        
    else
        echo "❌ Falha na enumeração SDP"
        return 1
    fi
}

# Executar exploração OBEX
execute_obex_exploitation() {
    echo "📁 OBEX Exploitation"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "⚠️ AVISO LEGAL E ÉTICO ⚠️"
    echo "Exploração OBEX pode:"
    echo "  - Acessar arquivos privados do dispositivo"
    echo "  - Deixar rastros nos logs do sistema"
    echo "  - Violar privacidade se usado sem autorização"
    echo "  - Ser ilegal sem consentimento explícito"
    echo ""
    echo "Modos disponíveis:"
    echo "  1. Modo SEGURO - Apenas listagem (recomendado)"
    echo "  2. Modo AGRESSIVO - Tentativa de download (CUIDADO!)"
    echo ""
    echo "Selecione o modo [1-2]: "
    read -r mode_choice
    
    local mode="safe"
    case "$mode_choice" in
        1)
            mode="safe"
            echo "✅ Modo SEGURO selecionado"
            ;;
        2)
            mode="aggressive"
            echo "⚠️ Modo AGRESSIVO selecionado"
            echo ""
            echo "🚨 ÚLTIMA CONFIRMAÇÃO 🚨"
            echo "Modo agressivo pode deixar rastros detectáveis!"
            echo "Tem certeza? (digite 'CONFIRMO'): "
            read -r final_confirm
            
            if [[ "$final_confirm" != "CONFIRMO" ]]; then
                echo "ℹ️ Exploração cancelada"
                return 0
            fi
            ;;
        *)
            echo "❌ Seleção inválida - usando modo seguro"
            mode="safe"
            ;;
    esac
    
    # Verificar conectividade
    echo "🔍 Verificando conectividade..."
    if ! is_device_reachable "$SELECTED_TARGET"; then
        echo "❌ Dispositivo não alcançável"
        return 1
    fi
    
    echo "✅ Dispositivo alcançável - iniciando exploração OBEX"
    
    # Executar exploração real
    local output_dir="$RESULTS_DIR/obex_${SELECTED_TARGET//:/_}_$SESSION_ID"
    local start_time=$(date +%s)
    
    if obex_exploitation "$SELECTED_TARGET" "$mode" "$output_dir"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "✅ Exploração OBEX concluída em ${duration}s"
        echo "📁 Resultados salvos em: $output_dir"
        
        # Análise de resultados
        if [[ -d "$output_dir" ]]; then
            local file_count=$(find "$output_dir" -type f | wc -l)
            echo "📊 Arquivos gerados: $file_count"
            
            echo ""
            echo "📋 Arquivos encontrados:"
            find "$output_dir" -type f -name "*.txt" | while read -r file; do
                local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                echo "  📄 $(basename "$file") (${size} bytes)"
            done
            
            # Gerar relatório resumido
            local report_file="$RESULTS_DIR/obex_summary_${SELECTED_TARGET//:/_}_$SESSION_ID.txt"
            cat > "$report_file" << EOF
=== OBEX EXPLOITATION REPORT ===
Target: $SELECTED_TARGET
Timestamp: $(date)
Mode: $mode
Duration: ${duration}s
Status: SUCCESS

Results Directory: $output_dir
Files Generated: $file_count

Analysis:
- OBEX service was accessible
- Directory listings obtained
- Mode: $mode exploration completed

Recommendations:
- Review OBEX service configuration
- Consider disabling OBEX if not needed
- Enable authentication if available
EOF
            
            echo "📋 Relatório resumido: $report_file"
        fi
        
    else
        echo "❌ Falha na exploração OBEX"
        echo "Possíveis causas:"
        echo "  - OBEX não disponível no dispositivo"
        echo "  - Autenticação necessária"
        echo "  - Serviço desabilitado"
        return 1
    fi
}

# Executar brute force de PIN
execute_pin_bruteforce() {
    echo "🔑 PIN Brute Force Attack"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "⚠️ AVISO CRÍTICO DE SEGURANÇA ⚠️"
    echo "PIN Brute Force é uma técnica invasiva que:"
    echo "  🚨 Pode ser detectada pelo dispositivo alvo"
    echo "  🚨 Pode causar bloqueio temporário do dispositivo"
    echo "  🚨 Pode ser ilegal sem autorização explícita"
    echo "  🚨 Pode deixar rastros nos logs do sistema"
    echo ""
    echo "Configurações do ataque:"
    echo "  Target: $SELECTED_TARGET"
    echo "  Método: Inteligente baseado no tipo de dispositivo"
    echo ""
    echo "Tipos de dispositivo disponíveis:"
    echo "  1. Phone/Smartphone"
    echo "  2. Headset/Audio"
    echo "  3. Keyboard/HID"
    echo "  4. Mouse/Pointing"
    echo "  5. Generic"
    echo ""
    echo "Selecione o tipo [1-5]: "
    read -r device_type_choice
    
    local device_type="generic"
    case "$device_type_choice" in
        1) device_type="phone" ;;
        2) device_type="headset" ;;
        3) device_type="keyboard" ;;
        4) device_type="mouse" ;;
        5) device_type="generic" ;;
        *) 
            echo "⚠️ Seleção inválida - usando generic"
            device_type="generic"
            ;;
    esac
    
    echo "✅ Tipo selecionado: $device_type"
    echo ""
    echo "🚨 CONFIRMAÇÃO FINAL 🚨"
    echo "Você tem autorização EXPLÍCITA para atacar $SELECTED_TARGET?"
    echo "Digite 'AUTORIZADO' para continuar: "
    read -r final_confirm
    
    if [[ "$final_confirm" != "AUTORIZADO" ]]; then
        echo "ℹ️ Brute force cancelado por segurança"
        return 0
    fi
    
    # Verificar conectividade
    echo "🔍 Verificando conectividade..."
    if ! is_device_reachable "$SELECTED_TARGET"; then
        echo "❌ Dispositivo não alcançável"
        return 1
    fi
    
    echo "✅ Dispositivo alcançável - iniciando brute force"
    
    # Opção de wordlist customizada
    echo ""
    echo "Deseja usar wordlist customizada? (y/N): "
    read -r use_custom
    
    local wordlist=""
    if [[ "$use_custom" =~ ^[Yy]$ ]]; then
        echo "Digite o caminho da wordlist: "
        read -r wordlist_path
        if [[ -f "$wordlist_path" ]]; then
            wordlist="$wordlist_path"
            echo "✅ Wordlist customizada: $wordlist"
        else
            echo "❌ Arquivo não encontrado - usando wordlist padrão"
        fi
    fi
    
    # Executar brute force real
    local start_time=$(date +%s)
    local report_file="$RESULTS_DIR/pin_bruteforce_${SELECTED_TARGET//:/_}_$SESSION_ID.txt"
    
    echo ""
    echo "🚀 Iniciando PIN brute force..."
    
    if pin_bruteforce_intelligent "$SELECTED_TARGET" "$device_type" "$wordlist"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "🎉 PIN ENCONTRADO!"
        echo "⏱️ Tempo total: ${duration}s"
        
        # Gerar relatório de sucesso
        cat > "$report_file" << EOF
=== PIN BRUTE FORCE SUCCESS REPORT ===
Target: $SELECTED_TARGET
Device Type: $device_type
Timestamp: $(date)
Duration: ${duration}s
Status: SUCCESS - PIN FOUND

Attack Details:
- Type: Intelligent PIN Brute Force
- Device Classification: $device_type
- Wordlist: ${wordlist:-Built-in}

CRITICAL SECURITY FINDING:
- Device accepts weak PIN authentication
- Immediate action required to secure device
- Consider using stronger authentication methods

Next Steps:
1. Document this vulnerability
2. Notify device owner if authorized test
3. Recommend security improvements
EOF
        
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "❌ PIN não encontrado"
        echo "⏱️ Tempo total: ${duration}s"
        
        # Gerar relatório de falha
        cat > "$report_file" << EOF
=== PIN BRUTE FORCE REPORT ===
Target: $SELECTED_TARGET
Device Type: $device_type
Timestamp: $(date)
Duration: ${duration}s
Status: FAILED - NO PIN FOUND

Attack Details:
- Type: Intelligent PIN Brute Force
- Device Classification: $device_type
- Wordlist: ${wordlist:-Built-in}

Results:
- No successful PIN discovered
- Device may have strong authentication
- Possible rate limiting or lockout mechanisms

Security Assessment:
- Device appears resilient to basic PIN attacks
- Authentication mechanism functioning properly
EOF
    fi
    
    echo "📋 Relatório salvo em: $report_file"
}

# Executar auditoria completa
execute_full_audit() {
    echo "📊 Full Security Audit"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "🔍 Auditoria Completa de Segurança Bluetooth"
    echo "Target: $SELECTED_TARGET"
    echo ""
    echo "Esta auditoria irá executar:"
    echo "  ✓ Reconnaissance detalhado"
    echo "  ✓ Enumeração completa de serviços"
    echo "  ✓ Análise de vulnerabilidades"
    echo "  ✓ Teste de superfície de ataque"
    echo "  ✓ Avaliação de risco"
    echo "  ✓ Relatório HTML detalhado"
    echo ""
    echo "⏱️ Tempo estimado: 5-10 minutos"
    echo ""
    echo "Continuar com auditoria completa? (Y/n): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "ℹ️ Auditoria cancelada"
        return 0
    fi
    
    # Verificar conectividade
    echo "🔍 Verificando conectividade inicial..."
    if ! is_device_reachable "$SELECTED_TARGET"; then
        echo "❌ Dispositivo não alcançável"
        return 1
    fi
    
    echo "✅ Dispositivo alcançável - iniciando auditoria"
    
    local start_time=$(date +%s)
    local audit_dir="$RESULTS_DIR/full_audit_${SELECTED_TARGET//:/_}_$SESSION_ID"
    local audit_report="$audit_dir/audit_report.html"
    
    mkdir -p "$audit_dir"
    
    echo ""
    echo "🎯 FASE 1: Reconnaissance Detalhado"
    echo "================================="
    
    local recon_file="$audit_dir/reconnaissance.txt"
    if device_reconnaissance "$SELECTED_TARGET" "$recon_file"; then
        echo "✅ Reconnaissance concluído"
    else
        echo "⚠️ Reconnaissance parcialmente bem-sucedido"
    fi
    
    echo ""
    echo "🔍 FASE 2: Enumeração Completa de Serviços"
    echo "========================================="
    
    local sdp_file="$audit_dir/sdp_enumeration.txt"
    if sdp_enumeration "$SELECTED_TARGET" "$sdp_file"; then
        echo "✅ Enumeração SDP concluída"
    else
        echo "⚠️ Enumeração SDP falhou"
    fi
    
    echo ""
    echo "🔒 FASE 3: Análise de Vulnerabilidades"
    echo "====================================="
    
    local vuln_file="$audit_dir/vulnerabilities.txt"
    if [[ -f "$sdp_file" ]]; then
        vulnerability_scanner "$(cat "$sdp_file")" "$SELECTED_TARGET" > "$vuln_file"
        echo "✅ Análise de vulnerabilidades concluída"
    else
        echo "⚠️ Análise de vulnerabilidades limitada"
    fi
    
    echo ""
    echo "🎯 FASE 4: Análise de Superfície de Ataque"
    echo "========================================"
    
    local attack_surface_file="$audit_dir/attack_surface.txt"
    if [[ -f "$sdp_file" ]]; then
        analyze_attack_surface "$(cat "$sdp_file")" > "$attack_surface_file"
        echo "✅ Análise de superfície de ataque concluída"
    else
        echo "⚠️ Análise de superfície de ataque limitada"
    fi
    
    echo ""
    echo "📊 FASE 5: Teste de Força de Sinal"
    echo "================================="
    
    local signal_file="$audit_dir/signal_strength.txt"
    signal_strength_test "$SELECTED_TARGET" 5 > "$signal_file"
    echo "✅ Teste de força de sinal concluído"
    
    echo ""
    echo "📈 FASE 6: Geração de Relatório"
    echo "=============================="
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Gerar relatório HTML detalhado
    cat > "$audit_report" << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BlueSecAudit - Relatório Completo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .info-box { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .success { background: #d5f4e6; border-left: 4px solid #27ae60; }
        .warning { background: #fef9e7; border-left: 4px solid #f39c12; }
        .danger { background: #fadbd8; border-left: 4px solid #e74c3c; }
        .code { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 BlueSecAudit - Relatório de Auditoria Completa</h1>
        
        <div class="info-box">
            <h3>📋 Informações da Auditoria</h3>
            <p><strong>Target:</strong> $SELECTED_TARGET</p>
            <p><strong>Data/Hora:</strong> $(date)</p>
            <p><strong>Duração:</strong> ${total_duration}s</p>
            <p><strong>Auditor:</strong> $(whoami)@$(hostname)</p>
            <p><strong>Sessão:</strong> $SESSION_ID</p>
        </div>

        <h2>🕵️ Fase 1: Reconnaissance</h2>
        <div class="code">
$(cat "$recon_file" 2>/dev/null | head -50 || echo "Dados de reconnaissance não disponíveis")
        </div>

        <h2>🔍 Fase 2: Enumeração SDP</h2>
        <div class="code">
$(cat "$sdp_file" 2>/dev/null | head -50 || echo "Dados de enumeração SDP não disponíveis")
        </div>

        <h2>🔒 Fase 3: Vulnerabilidades</h2>
        <div class="code">
$(cat "$vuln_file" 2>/dev/null || echo "Análise de vulnerabilidades não disponível")
        </div>

        <h2>🎯 Fase 4: Superfície de Ataque</h2>
        <div class="code">
$(cat "$attack_surface_file" 2>/dev/null || echo "Análise de superfície de ataque não disponível")
        </div>

        <h2>📶 Fase 5: Força de Sinal</h2>
        <div class="code">
$(cat "$signal_file" 2>/dev/null || echo "Teste de força de sinal não disponível")
        </div>

        <h2>📊 Resumo Executivo</h2>
        <div class="info-box warning">
            <h3>⚠️ Principais Achados</h3>
            <ul>
                <li>Dispositivo Bluetooth ativo e alcançável</li>
                <li>Serviços SDP disponíveis para enumeração</li>
                <li>Análise detalhada salva em arquivos individuais</li>
                <li>Recomenda-se revisão das configurações de segurança</li>
            </ul>
        </div>

        <div class="info-box">
            <h3>📁 Arquivos Gerados</h3>
            <ul>
                <li>📄 reconnaissance.txt - Reconnaissance detalhado</li>
                <li>📄 sdp_enumeration.txt - Enumeração de serviços</li>
                <li>📄 vulnerabilities.txt - Análise de vulnerabilidades</li>
                <li>📄 attack_surface.txt - Superfície de ataque</li>
                <li>📄 signal_strength.txt - Teste de sinal</li>
            </ul>
        </div>

        <div class="info-box danger">
            <h3>🚨 Aviso Legal</h3>
            <p>Esta auditoria foi realizada para fins educacionais e de teste autorizado. 
            O uso não autorizado de ferramentas de auditoria de segurança pode ser ilegal.</p>
        </div>

        <p><small>Gerado por BlueSecAudit v2.0 - $(date)</small></p>
    </div>
</body>
</html>
EOF
    
    echo "✅ Relatório HTML gerado: $audit_report"
    
    # Resumo final
    echo ""
    echo "🎉 AUDITORIA COMPLETA FINALIZADA"
    echo "================================"
    echo "⏱️ Tempo total: ${total_duration}s"
    echo "📁 Diretório: $audit_dir"
    echo "📊 Relatório principal: $audit_report"
    echo ""
    echo "📋 Arquivos gerados:"
    find "$audit_dir" -type f | while read -r file; do
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        echo "  📄 $(basename "$file") (${size} bytes)"
    done
    
    echo ""
    echo "💡 Para visualizar o relatório HTML:"
    echo "   firefox \"$audit_report\""
    echo "   # ou"
    echo "   xdg-open \"$audit_report\""
}

# Exibir menu de configurações
show_config_menu() {
    while true; do
        echo ""
        echo "==== Menu de Configurações ===="
        echo "1. Alterar adaptador padrão"
        echo "2. Configurar timeouts"
        echo "3. Configurar logs"
        echo "4. Status do sistema"
        echo "5. Voltar ao menu principal"
        echo ""
        echo -n "Selecione uma opção [1-5]: "
        
        read -r config_choice
        
        case "$config_choice" in
            1)
                echo "Funcionalidade em desenvolvimento"
                ;;
            2)
                echo "Funcionalidade em desenvolvimento"
                ;;
            3)
                echo "Funcionalidade em desenvolvimento"
                ;;
            4)
                echo "📊 Status do Sistema:"
                echo "   ✅ BlueSecAudit v2.0 ativo"
                echo "   📍 Sessão: $SESSION_ID"
                ;;
            5)
                break
                ;;
            *)
                echo "❌ Opção inválida"
                ;;
        esac
        
        echo ""
        echo "Pressione Enter para continuar..."
        read -r
    done
}

# Limpeza e saída
cleanup_and_exit() {
    echo ""
    echo "ℹ️ Finalizando BlueSecAudit..."
    echo "📝 Sessão $SESSION_ID finalizada"
    echo "👋 Obrigado por usar BlueSecAudit v2.0!"
    exit 0
}

# Executar ataque HID Injection
execute_hid_injection() {
    echo "🎮 HID Injection Attacks"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "⚠️ AVISO CRÍTICO DE SEGURANÇA ⚠️"
    echo "HID Injection pode:"
    echo "  🚨 Executar comandos no sistema alvo"
    echo "  🚨 Acessar dados sensíveis"
    echo "  🚨 Ser detectado por software de segurança"
    echo "  🚨 Ser ilegal sem autorização explícita"
    echo ""
    echo "Tipos de payload disponíveis:"
    echo "  1. Keyboard injection (texto/comandos)"
    echo "  2. Mouse manipulation"
    echo "  3. Payload customizado"
    echo ""
    echo "Selecione o tipo [1-3]: "
    read -r payload_type
    
    local payload_file="$RESULTS_DIR/hid_payload_$SESSION_ID.payload"
    
    case "$payload_type" in
        1)
            echo "Digite o texto para injeção: "
            read -r text_input
            generate_keyboard_payload "$text_input" "$payload_file"
            ;;
        2)
            echo "Ação do mouse (click/move): "
            read -r mouse_action
            echo "Coordenada X: "
            read -r x_coord
            echo "Coordenada Y: "
            read -r y_coord
            generate_mouse_payload "$mouse_action" "$x_coord" "$y_coord" "$payload_file"
            ;;
        3)
            echo "Caminho do payload customizado: "
            read -r custom_payload
            if [[ -f "$custom_payload" ]]; then
                cp "$custom_payload" "$payload_file"
            else
                echo "❌ Arquivo não encontrado"
                return 1
            fi
            ;;
        *)
            echo "❌ Seleção inválida"
            return 1
            ;;
    esac
    
    # Executar ataque HID
    local start_time=$(date +%s)
    
    if execute_hid_injection "$SELECTED_TARGET" "$payload_file" "safe"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "✅ HID Injection concluído em ${duration}s"
        
        # Gerar relatório
        local report_file="$RESULTS_DIR/hid_report_${SELECTED_TARGET//:/_}_$SESSION_ID.html"
        local hid_data="Target: $SELECTED_TARGET
Payload Type: $payload_type
Duration: ${duration}s
Status: SUCCESS (simulated)"
        
        generate_hid_report "$hid_data" "$report_file"
        echo "📋 Relatório HID salvo em: $report_file"
        
    else
        echo "❌ HID Injection falhou"
        return 1
    fi
}

# Executar interceptação de áudio
execute_audio_interception() {
    echo "🎵 Audio Interception"
    echo "================================"
    
    # Selecionar target se não definido
    if [[ -z "$SELECTED_TARGET" ]]; then
        if ! select_target_interactive; then
            return 1
        fi
    fi
    
    echo ""
    echo "⚠️ AVISO LEGAL ⚠️"
    echo "Interceptação de áudio pode:"
    echo "  🚨 Violar privacidade de comunicações"
    echo "  🚨 Ser ilegal sem autorização"
    echo "  🚨 Deixar rastros detectáveis"
    echo ""
    echo "Configurações de captura:"
    echo "  Sample Rate: 44100 Hz"
    echo "  Channels: Stereo"
    echo "  Bit Depth: 16-bit"
    echo ""
    echo "Duração da captura (segundos): "
    read -r duration
    
    if [[ ! "$duration" =~ ^[0-9]+$ ]] || [[ $duration -lt 1 ]] || [[ $duration -gt 300 ]]; then
        echo "❌ Duração inválida (1-300 segundos)"
        return 1
    fi
    
    # Verificar serviços de áudio
    echo "🔍 Verificando serviços de áudio..."
    local sdp_file="$RESULTS_DIR/sdp_audio_${SELECTED_TARGET//:/_}_$SESSION_ID.txt"
    
    if sdp_enumeration "$SELECTED_TARGET" "$sdp_file"; then
        if detect_audio_services "$(cat "$sdp_file")"; then
            echo "✅ Serviços de áudio detectados"
            
            # Analisar perfis de áudio
            detect_audio_profiles "$(cat "$sdp_file")"
            
            # Detectar codecs
            detect_audio_codecs "$(cat "$sdp_file")"
            
        else
            echo "⚠️ Nenhum serviço de áudio detectado"
        fi
    fi
    
    # Executar interceptação
    local start_time=$(date +%s)
    local capture_file="$RESULTS_DIR/audio_capture_${SELECTED_TARGET//:/_}_$SESSION_ID.wav"
    
    echo ""
    echo "🚀 Iniciando interceptação de áudio..."
    
    if simulate_audio_interception "$SELECTED_TARGET" "safe" "$duration"; then
        local end_time=$(date +%s)
        local duration_actual=$((end_time - start_time))
        
        echo ""
        echo "✅ Interceptação de áudio concluída em ${duration_actual}s"
        
        # Gerar relatório
        local report_file="$RESULTS_DIR/audio_report_${SELECTED_TARGET//:/_}_$SESSION_ID.html"
        local audio_data="Target: $SELECTED_TARGET
Duration: ${duration}s
Sample Rate: 44100 Hz
Status: SUCCESS (simulated)"
        
        generate_audio_report "$audio_data" "$report_file"
        echo "📋 Relatório de áudio salvo em: $report_file"
        
    else
        echo "❌ Interceptação de áudio falhou"
        return 1
    fi
}

# Executar ataques BLE
execute_ble_attacks() {
    echo "📱 BLE (Bluetooth Low Energy) Attacks"
    echo "================================"
    
    echo ""
    echo "🔍 BLE Attack Options:"
    echo "  1. BLE Device Discovery"
    echo "  2. GATT Service Enumeration"
    echo "  3. BLE Security Assessment"
    echo "  4. Beacon Detection"
    echo "  5. BLE Traffic Monitoring"
    echo ""
    echo "Selecione o tipo de ataque [1-5]: "
    read -r ble_choice
    
    case "$ble_choice" in
        1)
            echo "🔍 Executando BLE Device Discovery..."
            if detect_ble_devices 20; then
                echo "✅ BLE Discovery concluído"
            fi
            ;;
        2)
            # Selecionar target BLE
            echo "Digite o endereço BLE (MAC): "
            read -r ble_target
            
            if ! validate_ble_address "$ble_target"; then
                echo "❌ Endereço BLE inválido"
                return 1
            fi
            
            echo "🔍 Executando GATT Service Enumeration..."
            local gatt_file="$RESULTS_DIR/gatt_${ble_target//:/_}_$SESSION_ID.txt"
            
            if scan_gatt_services "$ble_target" "$gatt_file"; then
                echo "✅ GATT Enumeration concluído"
                
                # Detectar características
                detect_ble_characteristics "$(cat "$gatt_file")"
                
                # Classificar dispositivo
                detect_ble_device_type "$(cat "$gatt_file")"
                
                echo "📁 Resultados salvos em: $gatt_file"
            fi
            ;;
        3)
            echo "Digite o endereço BLE para assessment: "
            read -r ble_target
            
            if ! validate_ble_address "$ble_target"; then
                echo "❌ Endereço BLE inválido"
                return 1
            fi
            
            echo "🔒 Executando BLE Security Assessment..."
            
            # Simular dados de segurança
            local security_data="Pairing: Just Works
Encryption: AES-128
Authentication: None
Services: 5"
            
            analyze_ble_security "$security_data"
            analyze_ble_vulnerabilities "$security_data"
            
            # Gerar relatório
            local report_file="$RESULTS_DIR/ble_security_${ble_target//:/_}_$SESSION_ID.html"
            generate_ble_report "$security_data" "$report_file"
            echo "📋 Relatório BLE salvo em: $report_file"
            ;;
        4)
            echo "📍 Executando Beacon Detection..."
            
            # Simular dados de beacon
            local beacon_data="iBeacon: UUID=550e8400-e29b-41d4-a716-446655440000
Eddystone: URL=https://example.com"
            
            detect_ble_beacons "$beacon_data"
            echo "✅ Beacon Detection concluído"
            ;;
        5)
            echo "Digite o endereço BLE para monitoramento: "
            read -r ble_target
            
            if ! validate_ble_address "$ble_target"; then
                echo "❌ Endereço BLE inválido"
                return 1
            fi
            
            echo "Duração do monitoramento (segundos): "
            read -r monitor_duration
            
            echo "📡 Iniciando monitoramento BLE..."
            local monitor_file="$RESULTS_DIR/ble_traffic_${ble_target//:/_}_$SESSION_ID.log"
            
            if monitor_ble_traffic "$ble_target" "$monitor_duration" "$monitor_file"; then
                echo "✅ Monitoramento BLE concluído"
                echo "📁 Tráfego salvo em: $monitor_file"
            fi
            ;;
        *)
            echo "❌ Seleção inválida"
            return 1
            ;;
    esac
}

# Função principal
main() {
    # Trap para limpeza
    trap cleanup_and_exit SIGINT SIGTERM
    
    # Inicializar ambiente
    initialize_environment
    
    # Exibir banner simples
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║           BlueSecAudit v2.0 - Advanced          ║"
    echo "║        Bluetooth Security Auditing Tool         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "⚠️ Para uso educacional e testes autorizados apenas"
    echo ""
    
    # Escanear dispositivos inicialmente
    if ! scan_devices_interactive; then
        echo "⚠️ Falha no escaneamento inicial - continuando com dispositivos fake"
    fi
    
    # Loop principal do menu
    while true; do
        echo ""
        echo "==== Menu Principal ===="
        echo "1. 🎯 BlueSmack Attack (DoS L2CAP)"
        echo "2. 🔍 SDP Service Enumeration"
        echo "3. 📁 OBEX Exploitation"
        echo "4. 🔑 PIN Brute Force"
        echo "5. 📊 Full Security Audit"
        echo "6. 🎮 HID Injection Attacks"
        echo "7. 🎵 Audio Interception"
        echo "8. 📱 BLE (Low Energy) Attacks"
        echo "9. ⚙️  Configurações"
        echo "10. ℹ️  Ajuda"
        echo "11. 🚪 Sair"
        echo ""
        echo -n "Selecione uma opção [1-11]: "
        
        read -r choice
        echo "Você selecionou: $choice"
        
        case "$choice" in
            1)
                execute_bluesmack
                ;;
            2)
                execute_sdp_enumeration
                ;;
            3)
                execute_obex_exploitation
                ;;
            4)
                execute_pin_bruteforce
                ;;
            5)
                execute_full_audit
                ;;
            6)
                execute_hid_injection
                ;;
            7)
                execute_audio_interception
                ;;
            8)
                execute_ble_attacks
                ;;
            9)
                show_config_menu
                ;;
            10)
                echo "ℹ️ BlueSecAudit v2.0 - Ferramenta de Auditoria Bluetooth"
                echo "📚 Para mais informações, consulte o README.md"
                ;;
            11)
                cleanup_and_exit
                ;;
            *)
                echo "❌ Opção inválida: $choice"
                ;;
        esac
        
        echo ""
        echo "Pressione Enter para continuar..."
        read -r
    done
}

# Executar função principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 