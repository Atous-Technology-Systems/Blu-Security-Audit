#!/usr/bin/env bats
# Testes unitários para lib/bluetooth.sh

load '../test_helper'

# Setup específico para este arquivo de teste
setup() {
    # Criar mocks para comandos Bluetooth
    mock_bluetooth_cmd "hciconfig"
    mock_bluetooth_cmd "hcitool"
    mock_bluetooth_cmd "sdptool"
    mock_bluetooth_cmd "l2ping"
    mock_bluetooth_cmd "bluetoothctl"
    mock_bluetooth_cmd "hcidump"
    
    # Carrega funções de Bluetooth
    source lib/bluetooth.sh
}

@test "get_bluetooth_adapters: deve listar adaptadores disponíveis" {
    # Mock do hciconfig
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
echo "hci0:	Type: Primary  Bus: USB"
echo "	BD Address: 00:1A:7D:DA:71:13  ACL MTU: 310:10  SCO MTU: 64:8"
echo "	UP RUNNING PSCAN"
echo "hci1:	Type: Primary  Bus: USB" 
echo "	BD Address: 00:1A:7D:DA:71:14  ACL MTU: 310:10  SCO MTU: 64:8"
echo "	DOWN"
EOF
    chmod +x tests/mocks/hciconfig
    
    run get_bluetooth_adapters
    assert_success
    assert_output --partial "hci0"
    assert_output --partial "hci1"
}

@test "is_adapter_up: deve verificar status do adaptador" {
    # Mock para adaptador UP
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
if [[ "$1" == "hci0" ]]; then
    echo "hci0:	Type: Primary  Bus: USB"
    echo "	UP RUNNING PSCAN"
else
    echo "hci1:	Type: Primary  Bus: USB"
    echo "	DOWN"
fi
EOF
    chmod +x tests/mocks/hciconfig
    
    run is_adapter_up "hci0"
    assert_success
    
    run is_adapter_up "hci1"
    assert_failure
}

@test "bring_adapter_up: deve ativar adaptador" {
    # Mock para hciconfig up
    cat > tests/mocks/hciconfig << 'EOF'
#!/bin/bash
if [[ "$2" == "up" ]]; then
    echo "Bringing up adapter $1"
    exit 0
fi
EOF
    chmod +x tests/mocks/hciconfig
    
    run bring_adapter_up "hci0"
    assert_success
}

@test "scan_bluetooth_devices: deve escanear dispositivos próximos" {
    # Mock para hcitool scan
    cat > tests/mocks/hcitool << 'EOF'
#!/bin/bash
if [[ "$1" == "scan" ]]; then
    echo "Scanning ..."
    echo "	00:11:22:33:44:55	Device1"
    echo "	AA:BB:CC:DD:EE:FF	Device2"
    echo "	12:34:56:78:9A:BC	Device3"
fi
EOF
    chmod +x tests/mocks/hcitool
    
    run scan_bluetooth_devices
    assert_success
    assert_output --partial "00:11:22:33:44:55"
    assert_output --partial "Device1"
}

@test "get_device_info: deve obter informações detalhadas do dispositivo" {
    # Mock para hcitool info
    cat > tests/mocks/hcitool << 'EOF'
#!/bin/bash
if [[ "$1" == "info" ]]; then
    echo "Requesting information ..."
    echo "	BD Address:  $2"
    echo "	Device Name: Test Device"
    echo "	LMP Version: 4.0 (0x6) LMP Subversion: 0x220e"
    echo "	Manufacturer: Broadcom Corporation (15)"
fi
EOF
    chmod +x tests/mocks/hcitool
    
    run get_device_info "00:11:22:33:44:55"
    assert_success
    assert_output --partial "BD Address:  00:11:22:33:44:55"
    assert_output --partial "Test Device"
}

@test "get_device_services: deve enumerar serviços SDP" {
    # Mock para sdptool browse
    cat > tests/mocks/sdptool << 'EOF'
#!/bin/bash
if [[ "$1" == "browse" ]]; then
    echo "Browsing $2 ..."
    echo "Service Name: Audio Gateway"
    echo "Service RecHandle: 0x10001"
    echo "Service Class ID List:"
    echo '  "Handfree Audio Gateway" (0x111f)'
    echo ""
    echo "Service Name: Headset Audio Gateway"
    echo "Service RecHandle: 0x10002"
fi
EOF
    chmod +x tests/mocks/sdptool
    
    run get_device_services "00:11:22:33:44:55"
    assert_success
    assert_output --partial "Audio Gateway"
    assert_output --partial "0x111f"
}

@test "test_l2ping: deve testar conectividade L2CAP" {
    # Mock para l2ping
    cat > tests/mocks/l2ping << 'EOF'
#!/bin/bash
if [[ "$1" == "-c" && "$2" == "3" ]]; then
    echo "PING $3:"
    echo "44 bytes from $3 id 0 time 18.59ms"
    echo "44 bytes from $3 id 1 time 9.39ms"
    echo "44 bytes from $3 id 2 time 7.93ms"
    echo "3 sent, 3 received, 0% loss"
fi
EOF
    chmod +x tests/mocks/l2ping
    
    run test_l2ping "00:11:22:33:44:55"
    assert_success
    assert_output --partial "3 sent, 3 received, 0% loss"
}

@test "is_device_reachable: deve verificar se dispositivo está alcançável" {
    # Mock para l2ping com sucesso
    cat > tests/mocks/l2ping << 'EOF'
#!/bin/bash
if [[ "$1" == "-c" && "$2" == "1" ]]; then
    echo "44 bytes from $3 id 0 time 18.59ms"
    echo "1 sent, 1 received, 0% loss"
    exit 0
fi
EOF
    chmod +x tests/mocks/l2ping
    
    run is_device_reachable "00:11:22:33:44:55"
    assert_success
}

@test "start_packet_capture: deve iniciar captura de pacotes" {
    # Mock para hcidump
    cat > tests/mocks/hcidump << 'EOF'
#!/bin/bash
if [[ "$1" == "-w" ]]; then
    echo "Starting packet capture: $2"
    # Simula processo em background
    sleep 30 &
    echo $! > /tmp/hcidump.pid
fi
EOF
    chmod +x tests/mocks/hcidump
    
    run start_packet_capture "$TEST_TEMP_DIR/test.pcap"
    assert_success
}

@test "stop_packet_capture: deve parar captura de pacotes" {
    # Criar arquivo de PID fake
    echo "12345" > /tmp/hcidump.pid
    
    # Mock para kill
    cat > tests/mocks/kill << 'EOF'
#!/bin/bash
echo "Stopping process $2"
EOF
    chmod +x tests/mocks/kill
    
    run stop_packet_capture
    assert_success
}

@test "get_device_class: deve determinar classe do dispositivo" {
    run get_device_class "0x200404"
    assert_output "Audio/Video Device"
    
    run get_device_class "0x100104"
    assert_output "Computer"
    
    run get_device_class "0x200408"
    assert_output "Phone"
}

@test "estimate_bluetooth_version: deve estimar versão do Bluetooth" {
    run estimate_bluetooth_version "4.0"
    assert_output "4.0 (Bluetooth Low Energy Support)"
    
    run estimate_bluetooth_version "2.1"
    assert_output "2.1 (Secure Simple Pairing)"
    
    run estimate_bluetooth_version "1.2"
    assert_output "1.2 (Enhanced Data Rate)"
} 