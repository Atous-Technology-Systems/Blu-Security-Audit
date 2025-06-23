#!/bin/bash
# BATS Support Library - load.bash
# Funções de suporte para carregar bibliotecas de teste

bats_load_safe() {
    local library_path="$1"
    
    # Se o arquivo existir, carregue-o
    if [[ -f "$library_path" ]]; then
        source "$library_path"
        return 0
    fi
    
    # Se for um arquivo .bash, tente sem a extensão
    if [[ "$library_path" == *.bash ]]; then
        local without_extension="${library_path%.bash}"
        if [[ -f "$without_extension" ]]; then
            source "$without_extension"
            return 0
        fi
    fi
    
    # Se for sem extensão, tente com .bash
    if [[ "$library_path" != *.bash ]]; then
        local with_extension="${library_path}.bash"
        if [[ -f "$with_extension" ]]; then
            source "$with_extension"
            return 0
        fi
    fi
    
    # Não encontrou o arquivo
    return 1
}

# Função para carregar helpers
load() {
    local file="$1"
    if ! bats_load_safe "$file"; then
        echo "bats_load_safe: Could not find '$file'[.bash]" >&2
        return 1
    fi
}

# Exportar funções
export -f bats_load_safe
export -f load 