#!/usr/bin/env bats

# Testes unitários para Audio Interception Attacks
# TDD Implementation - BlueSecAudit v2.0

setup() {
    # Carregar módulos necessários
    source "${BATS_TEST_DIRNAME}/../../lib/utils.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/bluetooth.sh"
    source "${BATS_TEST_DIRNAME}/../../lib/audio_attacks.sh"
    
    # Variáveis de teste
    export TEST_TARGET="00:11:22:33:44:55"
    export TEST_AUDIO_DIR="/tmp/audio_test"
    export TEST_CAPTURE_FILE="/tmp/audio_test/capture.wav"
    
    # Criar diretório temporário
    mkdir -p "$TEST_AUDIO_DIR"
}

teardown() {
    # Limpeza após testes
    rm -rf "$TEST_AUDIO_DIR"
    pkill -f "bluetoothctl\|pulseaudio\|alsa" 2>/dev/null || true
}

# Teste 1: Detectar serviços de áudio
@test "detect_audio_services should identify A2DP services" {
    local sdp_data="Service Name: Audio Source
Protocol Descriptor List: A2DP
Service Class ID List: AudioSource"
    
    run detect_audio_services "$sdp_data"
    [ "$status" -eq 0 ]
    [[ "$output" == *"A2DP"* ]]
    [[ "$output" == *"detected"* ]]
}

# Teste 2: Detectar perfis de áudio
@test "detect_audio_profiles should classify audio capabilities" {
    local device_info="Service: Audio Source
Service: Audio Sink
Protocol: A2DP"
    
    run detect_audio_profiles "$device_info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "source" ]]
    [[ "$output" =~ "sink" ]]
}

# Teste 3: Configurar captura de áudio
@test "setup_audio_capture should configure recording" {
    run setup_audio_capture "$TEST_CAPTURE_FILE" "44100" "stereo"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Audio capture configured" ]]
}

# Teste 4: Validar configurações de áudio
@test "validate_audio_config should check parameters" {
    run validate_audio_config "44100" "stereo" "16"
    [ "$status" -eq 0 ]
    
    run validate_audio_config "invalid" "mono" "8"
    [ "$status" -eq 1 ]
}

# Teste 5: Testar conectividade A2DP
@test "test_a2dp_connectivity should check audio connection" {
    run test_a2dp_connectivity "$TEST_TARGET"
    # Deve retornar sem erro crítico mesmo que falhe
    [ "$status" -ne 2 ]
}

# Teste 6: Simular interceptação de áudio
@test "simulate_audio_interception should run safely" {
    run simulate_audio_interception "$TEST_TARGET" "safe" "10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "simulation" ]]
}

# Teste 7: Analisar qualidade de áudio
@test "analyze_audio_quality should assess stream" {
    # Criar arquivo de áudio fake
    echo "fake audio data" > "$TEST_CAPTURE_FILE"
    
    run analyze_audio_quality "$TEST_CAPTURE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "analysis" ]]
}

# Teste 8: Detectar codecs de áudio
@test "detect_audio_codecs should identify encoding" {
    local sdp_data="Codec: SBC
Codec: AAC
Codec: aptX"
    
    run detect_audio_codecs "$sdp_data"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SBC" ]]
    [[ "$output" =~ "AAC" ]]
}

# Teste 9: Calcular latência de áudio
@test "calculate_audio_latency should measure delay" {
    run calculate_audio_latency "$TEST_TARGET" "3"
    [ "$status" -eq 0 ]
    [[ "$output" == *"latency"* ]] || [[ "$output" == *"ms"* ]]
}

# Teste 10: Gerar relatório de áudio
@test "generate_audio_report should create analysis" {
    local audio_data="Target: $TEST_TARGET
Codec: SBC
Quality: High"
    
    run generate_audio_report "$audio_data" "$TEST_AUDIO_DIR/report.html"
    [ "$status" -eq 0 ]
    [ -f "$TEST_AUDIO_DIR/report.html" ]
    
    # Verificar conteúdo HTML
    run grep -i "audio.*interception" "$TEST_AUDIO_DIR/report.html"
    [ "$status" -eq 0 ]
} 