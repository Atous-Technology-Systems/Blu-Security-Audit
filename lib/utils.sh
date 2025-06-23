#!/bin/bash
# lib/utils.sh - Funções utilitárias para BlueSecAudit
# Implementadas seguindo TDD

set -euo pipefail

# Validar endereço MAC
is_valid_mac() {
    local mac="$1"
    
    # Verificar se o formato está correto: XX:XX:XX:XX:XX:XX
    if [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Alias para compatibilidade
validate_mac_address() {
    is_valid_mac "$1"
}

# Normalizar MAC para uppercase
normalize_mac() {
    local mac="$1"
    echo "${mac^^}"  # Converter para uppercase
}

# Função de logging estruturado
log_message() {
    local level="$1"
    local message="$2"
    local log_file="${3:-/dev/stdout}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] %s - %s\n" "$timestamp" "$level" "$message" >> "$log_file"
}

# Verificar se está executando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Validar valor de timeout
validate_timeout() {
    local timeout="$1"
    
    # Verificar se é um número positivo
    if [[ $timeout =~ ^[1-9][0-9]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Formatar duração em segundos para formato legível
format_duration() {
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
    
    echo "${result% }"  # Remove espaço extra no final
}

# Gerar nome único para arquivos de relatório
generate_report_filename() {
    local prefix="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    echo "${prefix}_${timestamp}.txt"
}

# Limpar arquivos temporários
cleanup_temp_files() {
    local temp_dir="$1"
    
    if [[ -d "$temp_dir" ]]; then
        find "$temp_dir" -name "*.tmp" -type f -delete 2>/dev/null || true
    fi
}

# Verificar se um comando está disponível
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Gerar ID único para sessão
generate_session_id() {
    echo "bs_$(date +%s)_$$"
}

# Verificar conectividade de rede básica
check_network() {
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Criar backup de arquivo
backup_file() {
    local file="$1"
    local backup_file="${file}.backup.$(date +%s)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file"
        echo "$backup_file"
    else
        return 1
    fi
}

# Validar range de portas
validate_port_range() {
    local start_port="$1"
    local end_port="$2"
    
    if [[ $start_port =~ ^[0-9]+$ ]] && [[ $end_port =~ ^[0-9]+$ ]]; then
        if [[ $start_port -ge 1 ]] && [[ $end_port -le 65535 ]] && [[ $start_port -le $end_port ]]; then
            return 0
        fi
    fi
    return 1
}

# Calcular hash de arquivo
calculate_file_hash() {
    local file="$1"
    local algorithm="${2:-sha256}"
    
    case "$algorithm" in
        "md5")
            md5sum "$file" | cut -d' ' -f1
            ;;
        "sha1")
            sha1sum "$file" | cut -d' ' -f1
            ;;
        "sha256")
            sha256sum "$file" | cut -d' ' -f1
            ;;
        *)
            echo "Algoritmo não suportado: $algorithm" >&2
            return 1
            ;;
    esac
} 