#!/bin/bash
# lib/ui.sh - Interface de usuário melhorada para BlueSecAudit

set -euo pipefail

# Cores para interface
declare -A COLORS=(
    ["red"]='\033[0;31m'
    ["green"]='\033[0;32m'
    ["yellow"]='\033[1;33m'
    ["blue"]='\033[0;34m'
    ["purple"]='\033[0;35m'
    ["cyan"]='\033[0;36m'
    ["white"]='\033[1;37m'
    ["nc"]='\033[0m'
)

# Function to safely get color codes
get_color() {
    local color_name="$1"
    echo -e "${COLORS[$color_name]:-}"
}

# Exibir banner principal
display_banner() {
    clear
    echo -e "$(get_color cyan)"
    cat << 'EOF'
╔══════════════════════════════════════════════════╗
║  ____  _            ____            _            ║
║ | __ )| |_   _  ___/ ___|  ___  ___| |           ║
║ |  _ \| | | | |/ _ \___ \ / _ \/ __| |           ║
║ | |_) | | |_| |  __/___) |  __/ (__| |           ║
║ |____/|_|\__,_|\___|____/ \___|\___|_|           ║
║                                                  ║
║           BlueSecAudit v2.0 - Advanced          ║
║        Bluetooth Security Auditing Tool         ║
╚══════════════════════════════════════════════════╝
EOF
    echo -e "$(get_color nc)"
    echo -e "$(get_color yellow)[!] Para uso educacional e testes autorizados apenas$(get_color nc)"
    echo ""
}

# Exibir menu principal
display_menu() {
    echo -e "$(get_color white)==== Menu Principal ====$(get_color nc)"
    echo "1. 🎯 BlueSmack Attack (DoS L2CAP)"
    echo "2. 🔍 SDP Service Enumeration"
    echo "3. 📁 OBEX Exploitation"
    echo "4. 🔑 PIN Brute Force"
    echo "5. 📊 Full Security Audit"
    echo "6. ⚙️  Configurações"
    echo "7. ℹ️  Ajuda"
    echo "8. 🚪 Sair"
    echo ""
    echo -n "Selecione uma opção [1-8]: "
}

# Barra de progresso
progress_bar() {
    local current="$1"
    local total="$2"
    local description="${3:-Processando}"
    local width=50
    
    local percentage=$(( (current * 100) / total ))
    local completed=$(( (current * width) / total ))
    local remaining=$(( width - completed ))
    
    printf "\r%s [" "$description"
    printf "%*s" "$completed" "" | tr ' ' '█'
    printf "%*s" "$remaining" "" | tr ' ' '░'
    printf "] %d%%" "$percentage"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Formatar informações do dispositivo
format_device_info() {
    local device_data="$1"
    local mac=$(echo "$device_data" | cut -d$'\t' -f1)
    local name=$(echo "$device_data" | cut -d$'\t' -f2)
    
    echo -e "$(get_color green)MAC:$(get_color nc) $mac"
    echo -e "$(get_color green)Nome:$(get_color nc) $name"
}

# Solicitar confirmação do usuário
confirm_action() {
    local message="$1"
    
    echo -e "$(get_color yellow)$message [y/N]:$(get_color nc) "
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Exibir ajuda para comandos
display_help() {
    local command="$1"
    
    case "$command" in
        "bluesmack")
            echo -e "$(get_color white)BlueSmack Attack$(get_color nc)"
            echo "Executa ataque DoS (Denial of Service) usando L2CAP"
            echo "Envia pacotes grandes para causar travamento no dispositivo alvo"
            ;;
        "sdp")
            echo -e "$(get_color white)SDP Enumeration$(get_color nc)"
            echo "Enumera serviços disponíveis no dispositivo alvo"
            echo "Identifica potenciais vetores de ataque"
            ;;
        "obex")
            echo -e "$(get_color white)OBEX Exploitation$(get_color nc)"
            echo "Testa vulnerabilidades no protocolo OBEX"
            echo "Tentativas de acesso não autorizado a arquivos"
            ;;
        "bruteforce")
            echo -e "$(get_color white)PIN Brute Force$(get_color nc)"
            echo "Ataque de força bruta contra PINs de emparelhamento"
            echo "Usa wordlists inteligentes baseadas no dispositivo"
            ;;
        *)
            echo "Comando não reconhecido: $command"
            ;;
    esac
}

# Animar spinner de carregamento
animate_spinner() {
    local duration="$1"
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local end_time=$(($(date +%s) + duration))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        for (( i=0; i<${#spin_chars}; i++ )); do
            printf "\r$(get_color cyan)%s$(get_color nc) Processando..." "${spin_chars:$i:1}"
            sleep 0.1
        done
    done
    printf "\r%s\n" "✓ Concluído"
}

# Formatar tempo decorrido
format_time() {
    local total_seconds="$1"
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    
    local result=""
    
    if [[ $hours -gt 0 ]]; then
        result="${hours}h "
    fi
    
    if [[ $minutes -gt 0 ]]; then
        result="${result}${minutes}m "
    fi
    
    if [[ $seconds -gt 0 ]] || [[ -z "$result" ]]; then
        result="${result}${seconds}s"
    fi
    
    echo "${result% }"
}

# Exibir tabela de resultados
display_results_table() {
    local results="$1"
    
    echo -e "$(get_color white)┌─────────────────────┬─────────────────────┬──────────────┐$(get_color nc)"
    echo -e "$(get_color white)│ MAC Address         │ Device Name         │ Risk Level   │$(get_color nc)"
    echo -e "$(get_color white)├─────────────────────┼─────────────────────┼──────────────┤$(get_color nc)"
    
    # Parse dos resultados (formato: MAC:xxx,Name:xxx,Risk:xxx)
    local mac=$(echo "$results" | grep -o "MAC:[^,]*" | sed 's/MAC://')
    local name=$(echo "$results" | grep -o "Name:[^,]*" | sed 's/Name://')
    local risk=$(echo "$results" | grep -o "Risk:[^,]*" | sed 's/Risk://')
    
    local risk_color
    case "$risk" in
        "HIGH"|"CRITICAL") risk_color="$(get_color red)" ;;
        "MEDIUM") risk_color="$(get_color yellow)" ;;
        "LOW") risk_color="$(get_color green)" ;;
        *) risk_color="$(get_color nc)" ;;
    esac
    
    printf "│ %-19s │ %-19s │ %s%-12s%s │\n" \
        "$mac" "$name" "$risk_color" "$risk" "$(get_color nc)"
    
    echo -e "$(get_color white)└─────────────────────┴─────────────────────┴──────────────┘$(get_color nc)"
}

# Colorir texto
color_text() {
    local color="$1"
    local text="$2"
    
    echo -e "$(get_color "$color")$text$(get_color nc)"
}

# Exibir notificação
show_notification() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        "success")
            echo -e "$(get_color green)✓$(get_color nc) $message"
            ;;
        "error")
            echo -e "$(get_color red)✗$(get_color nc) $message"
            ;;
        "warning")
            echo -e "$(get_color yellow)⚠$(get_color nc) $message"
            ;;
        "info")
            echo -e "$(get_color blue)ℹ$(get_color nc) $message"
            ;;
    esac
}

# Selecionar dispositivo de uma lista
select_device() {
    local devices_file="$1"
    
    if [[ ! -f "$devices_file" ]] || [[ ! -s "$devices_file" ]]; then
        show_notification "error" "Nenhum dispositivo encontrado"
        return 1
    fi
    
    echo -e "$(get_color white)Dispositivos encontrados:$(get_color nc)"
    echo ""
    
    local counter=1
    while IFS=$'\t' read -r mac name; do
        echo "$counter. $mac - $name"
        counter=$((counter + 1))
    done < "$devices_file"
    
    echo ""
    echo -n "Selecione um dispositivo [1-$((counter-1))]: "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -lt $counter ]]; then
        sed -n "${selection}p" "$devices_file" | cut -f1
        return 0
    else
        show_notification "error" "Seleção inválida"
        return 1
    fi
}

# Exibir status do sistema
display_system_status() {
    echo -e "$(get_color white)Status do Sistema:$(get_color nc)"
    echo ""
    
    # Verificar adaptador Bluetooth
    if hciconfig hci0 >/dev/null 2>&1; then
        show_notification "success" "Adaptador Bluetooth detectado"
    else
        show_notification "error" "Adaptador Bluetooth não encontrado"
    fi
    
    # Verificar permissões
    if [[ $EUID -eq 0 ]]; then
        show_notification "success" "Executando como root"
    else
        show_notification "warning" "Não está executando como root - algumas funções podem falhar"
    fi
    
    # Verificar ferramentas
    local tools=("hcitool" "hciconfig" "sdptool" "l2ping")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            show_notification "success" "$tool disponível"
        else
            show_notification "error" "$tool não encontrado"
        fi
    done
}

# Menu de configurações
display_config_menu() {
    echo -e "$(get_color white)==== Menu de Configurações ====$(get_color nc)"
    echo "1. Alterar adaptador padrão"
    echo "2. Configurar timeouts"
    echo "3. Configurar logs"
    echo "4. Status do sistema"
    echo "5. Voltar ao menu principal"
    echo ""
    echo -n "Selecione uma opção [1-5]: "
}

# Aguardar tecla para continuar
wait_for_key() {
    echo ""
    echo -e "$(get_color yellow)Pressione qualquer tecla para continuar...$(get_color nc)"
    read -n 1 -s
} 