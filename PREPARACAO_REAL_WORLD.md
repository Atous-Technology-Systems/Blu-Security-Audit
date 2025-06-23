# 🎯 PREPARAÇÃO PARA ATAQUES REAIS - BlueSecAudit v2.0
## Guia de Implementação em Ambiente de Produção

---

## 📋 CHECKLIST PRÉ-IMPLEMENTAÇÃO

### ✅ Verificações Legais Obrigatórias:

```
ANTES DE QUALQUER TESTE REAL:

□ Contrato de auditoria de segurança assinado
□ Formulário de autorização específica para Bluetooth
□ Identificação de todos os dispositivos autorizados
□ Janela de tempo explicitamente definida
□ Contatos de emergência documentados
□ Acordo de confidencialidade (NDA) assinado
□ Seguro de responsabilidade civil verificado
□ Conhecimento das leis locais sobre cibersegurança
□ Aprovação de supervisores/gerência
□ Documentação de escopo e limitações
```

### 🛠️ Configuração Técnica Obrigatória:

```bash
# 1. Verificar sistema e dependências
./check-system.sh --production

# 2. Instalar dependências completas
sudo apt update && sudo apt install -y \
    bluez bluez-tools bluez-hcidump \
    obexftp pulseaudio-utils \
    wireshark-common tshark \
    bc jq expect rfkill

# 3. Configurar adaptador Bluetooth
sudo hciconfig hci0 up
sudo hciconfig hci0 piscan

# 4. Configurar permissões de usuário
sudo usermod -a -G bluetooth,dialout $USER
sudo usermod -a -G wireshark $USER

# 5. Verificar funcionalidade básica
bluetoothctl --version
hcitool dev
hciconfig -a

# 6. Testar captura de tráfego
sudo hcidump -X -V
```

### 📊 Ambiente de Teste Isolado:

```
CONFIGURAÇÃO RECOMENDADA:

🏢 Ambiente Físico:
  • Sala isolada/blindada (Faraday cage ideal)
  • Distância de outros dispositivos Bluetooth
  • Controle de acesso físico
  • Documentação de entrada/saída

💻 Hardware Requerido:
  • Adaptador Bluetooth compatível (CSR/Intel recomendado)
  • Múltiplos adaptadores para testes MITM
  • Dispositivos alvo dedicados para testes
  • Máquina Linux com mínimo 8GB RAM

🔧 Software:
  • Ubuntu 20.04+ LTS (recomendado)
  • BlueSecAudit v2.0 atualizado
  • Wireshark com plugins Bluetooth
  • Logs centralizados configurados
```

---

## 🔧 CONFIGURAÇÃO AVANÇADA DE PRODUÇÃO

### Configuração de Logging Avançado:

```bash
# Criar estrutura de logs profissional
sudo mkdir -p /var/log/bluesecaudit
sudo chown $USER:bluetooth /var/log/bluesecaudit
sudo chmod 750 /var/log/bluesecaudit

# Configurar rotação de logs
cat << 'EOF' | sudo tee /etc/logrotate.d/bluesecaudit
/var/log/bluesecaudit/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Configurar syslog para capturar eventos Bluetooth
echo "kern.info /var/log/bluesecaudit/bluetooth-kernel.log" | sudo tee -a /etc/rsyslog.d/50-bluetooth.conf
sudo systemctl restart rsyslog
```

### Configuração de Captura Profissional:

```bash
# Instalar ferramentas avançadas de análise
sudo apt install -y \
    bluetooth btscanner btfind \
    ubertooth-firmware ubertooth-firmware-source \
    hackrf libhackrf-dev \
    gqrx-sdr

# Configurar Wireshark para captura Bluetooth
sudo groupadd wireshark 2>/dev/null || true
sudo chgrp wireshark /usr/bin/dumpcap
sudo chmod 4755 /usr/bin/dumpcap

# Criar script de captura automatizada
cat << 'EOF' > capture-bluetooth.sh
#!/bin/bash
CAPTURE_DIR="/var/log/bluesecaudit/captures"
mkdir -p "$CAPTURE_DIR"

# Iniciar captura HCI
sudo hcidump -w "${CAPTURE_DIR}/hci_$(date +%Y%m%d_%H%M%S).pcap" &
HCI_PID=$!

# Iniciar captura Wireshark
sudo tshark -i bluetooth0 -w "${CAPTURE_DIR}/tshark_$(date +%Y%m%d_%H%M%S).pcap" &
TSHARK_PID=$!

echo "Captura iniciada - HCI: $HCI_PID, Tshark: $TSHARK_PID"
echo "$HCI_PID" > /tmp/hci_capture.pid
echo "$TSHARK_PID" > /tmp/tshark_capture.pid
EOF

chmod +x capture-bluetooth.sh
```

### Configuração de Segurança:

```bash
# Configurar firewall para isolar testes
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow ssh
sudo ufw allow from 127.0.0.1

# Configurar SELinux/AppArmor (se disponível)
sudo aa-enforce /usr/bin/bluetoothctl 2>/dev/null || true

# Configurar auditoria do sistema
sudo auditctl -w /usr/bin/hcitool -p x -k bluetooth_tools
sudo auditctl -w /usr/bin/bluetoothctl -p x -k bluetooth_tools
sudo auditctl -w /usr/bin/gatttool -p x -k bluetooth_tools
```

---

## 🛡️ FRAMEWORK DE AUTORIZAÇÃO PROFISSIONAL

### Template de Contrato de Auditoria:

```
CONTRATO DE AUDITORIA DE SEGURANÇA BLUETOOTH
==========================================

ENTRE:
Cliente: ___________________________________________
Auditor: ___________________________________________
Data: ______________________________________________

ESCOPO AUTORIZADO:
□ Scanning e enumeração de serviços
□ Análise de vulnerabilidades passiva
□ Testes de conectividade básica
□ Ataques de negação de serviço (DoS)
□ Interceptação de comunicações
□ Ataques de injeção (HID)
□ Análise de protocolos BLE
□ Testes de força bruta (PIN)

DISPOSITIVOS AUTORIZADOS:
MAC Address          | Tipo de Dispositivo | Proprietário
---------------------|--------------------|--------------
                     |                    |
                     |                    |
                     |                    |

LIMITAÇÕES E EXCLUSÕES:
• Não interferir com sistemas de produção
• Não acessar dados pessoais/confidenciais
• Parar imediatamente se detectar impacto
• Documentar todas as ações realizadas
• Respeitar janela de tempo acordada

JANELA DE TESTES:
Início: ___________________________________________
Fim: ______________________________________________

CONTATOS DE EMERGÊNCIA:
Técnico: __________________________________________
Gerencial: _______________________________________
Legal: ____________________________________________

ASSINATURAS:
Cliente: __________________________________________
Auditor: __________________________________________
Testemunha: ______________________________________
Data: _____________________________________________
```

### Formulário de Autorização por Dispositivo:

```
AUTORIZAÇÃO ESPECÍFICA DE DISPOSITIVO
=====================================

DISPOSITIVO:
MAC Address: ______________________________________
Tipo: _____________________________________________
Modelo/Marca: ____________________________________
Proprietário: ____________________________________
Localização: ____________________________________

TESTES AUTORIZADOS:
□ Scanning básico (sem conexão)
□ Enumeração de serviços SDP
□ Testes de conectividade
□ Análise de vulnerabilidades
□ Ataques DoS (BlueSmack)
□ Exploração OBEX
□ Brute force de PIN
□ Injeção HID
□ Interceptação de áudio
□ Testes BLE específicos

RESTRIÇÕES ESPECIAIS:
_____________________________________________________
_____________________________________________________

RESPONSÁVEL TÉCNICO:
Nome: ____________________________________________
Cargo: ___________________________________________
Contato: _________________________________________
Assinatura: ____________________________________
Data: ____________________________________________
```

---

## 🔍 PROCEDIMENTOS OPERACIONAIS PADRÃO

### Pré-Teste (30 minutos):

```bash
#!/bin/bash
# pre-test-checklist.sh

echo "=== CHECKLIST PRÉ-TESTE BLUESECAUDIT v2.0 ==="

# 1. Verificar autorização
echo "1. Verificando documentação legal..."
if [[ ! -f "authorization.signed" ]]; then
    echo "❌ ERRO: Autorização não encontrada"
    exit 1
fi
echo "✅ Autorização verificada"

# 2. Verificar ambiente
echo "2. Verificando ambiente técnico..."
./check-system.sh --verify || exit 1
echo "✅ Sistema verificado"

# 3. Configurar logs
echo "3. Configurando sistema de logs..."
mkdir -p "logs/$(date +%Y%m%d)"
export LOG_DIR="logs/$(date +%Y%m%d)"
echo "✅ Logs configurados em: $LOG_DIR"

# 4. Backup de configurações
echo "4. Fazendo backup do ambiente..."
cp /etc/bluetooth/main.conf "$LOG_DIR/bluetooth_config_backup.conf"
hciconfig -a > "$LOG_DIR/hci_config_backup.txt"
echo "✅ Backup realizado"

# 5. Iniciar monitoramento
echo "5. Iniciando monitoramento do sistema..."
./capture-bluetooth.sh
echo "✅ Monitoramento ativo"

echo ""
echo "🎯 Sistema pronto para testes de segurança"
echo "📁 Logs em: $LOG_DIR"
echo "⏰ Início autorizado: $(date)"
```

### Durante Teste (Monitoramento Contínuo):

```bash
#!/bin/bash
# monitor-test.sh

while true; do
    clear
    echo "=== MONITOR BLUESECAUDIT v2.0 ==="
    echo "Timestamp: $(date)"
    echo ""
    
    # Status do sistema
    echo "📊 STATUS DO SISTEMA:"
    echo "CPU: $(top -bn1 | grep Cpu | awk '{print $2}' | sed 's/%us,//')"
    echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
    echo ""
    
    # Processos Bluetooth ativos
    echo "🔧 PROCESSOS BLUETOOTH:"
    ps aux | grep -E "(bluetooth|hci|gatt)" | grep -v grep
    echo ""
    
    # Conexões ativas
    echo "📡 CONEXÕES ATIVAS:"
    hciconfig hci0 | grep -E "(UP|DOWN|RUNNING)"
    bluetoothctl info 2>/dev/null | head -5
    echo ""
    
    # Capturas em andamento
    echo "📹 CAPTURAS ATIVAS:"
    if [[ -f /tmp/hci_capture.pid ]]; then
        echo "HCI Capture: PID $(cat /tmp/hci_capture.pid)"
    fi
    if [[ -f /tmp/tshark_capture.pid ]]; then
        echo "Tshark Capture: PID $(cat /tmp/tshark_capture.pid)"
    fi
    echo ""
    
    # Arquivos de resultado recentes
    echo "📄 RESULTADOS RECENTES:"
    find results/ -name "*.txt" -o -name "*.html" -o -name "*.pcap" | head -5
    echo ""
    
    echo "Pressione Ctrl+C para parar o monitoramento"
    sleep 10
done
```

### Pós-Teste (Limpeza e Relatórios):

```bash
#!/bin/bash
# post-test-cleanup.sh

echo "=== LIMPEZA PÓS-TESTE BLUESECAUDIT v2.0 ==="

# 1. Parar capturas
echo "1. Parando capturas ativas..."
if [[ -f /tmp/hci_capture.pid ]]; then
    kill $(cat /tmp/hci_capture.pid) 2>/dev/null
    rm -f /tmp/hci_capture.pid
fi
if [[ -f /tmp/tshark_capture.pid ]]; then
    kill $(cat /tmp/tshark_capture.pid) 2>/dev/null
    rm -f /tmp/tshark_capture.pid
fi
echo "✅ Capturas finalizadas"

# 2. Desconectar todos os dispositivos
echo "2. Desconectando dispositivos..."
bluetoothctl disconnect 2>/dev/null || true
echo "✅ Dispositivos desconectados"

# 3. Gerar relatório consolidado
echo "3. Gerando relatório consolidado..."
python3 generate_final_report.py --session "$(date +%Y%m%d)" --output "final_report_$(date +%Y%m%d_%H%M%S).html"
echo "✅ Relatório gerado"

# 4. Arquivar resultados
echo "4. Arquivando resultados..."
tar -czf "bluesecaudit_results_$(date +%Y%m%d_%H%M%S).tar.gz" results/ logs/
echo "✅ Resultados arquivados"

# 5. Limpar dados temporários sensíveis
echo "5. Limpando dados temporários..."
find /tmp -name "*bluetooth*" -type f -exec shred -u {} \; 2>/dev/null || true
find /tmp -name "*bluez*" -type f -exec shred -u {} \; 2>/dev/null || true
echo "✅ Dados temporários limpos"

# 6. Restaurar configurações
echo "6. Restaurando configurações originais..."
if [[ -f "$LOG_DIR/bluetooth_config_backup.conf" ]]; then
    sudo cp "$LOG_DIR/bluetooth_config_backup.conf" /etc/bluetooth/main.conf
    sudo systemctl restart bluetooth
fi
echo "✅ Configurações restauradas"

echo ""
echo "🎯 Limpeza pós-teste concluída"
echo "📁 Arquivo final: bluesecaudit_results_$(date +%Y%m%d_%H%M%S).tar.gz"
echo "⏰ Teste finalizado: $(date)"
```

---

## 📊 MÉTRICAS E KPIs DE SEGURANÇA

### Indicadores de Performance:

```python
# metrics.py - Sistema de métricas profissional

class BluetoothSecurityMetrics:
    def __init__(self):
        self.metrics = {
            'devices_discovered': 0,
            'services_enumerated': 0,
            'vulnerabilities_found': 0,
            'successful_attacks': 0,
            'false_positives': 0,
            'test_duration': 0,
            'data_captured': 0  # MB
        }
    
    def calculate_risk_score(self):
        """Calcula score de risco baseado nos achados"""
        score = 0
        
        # Vulnerabilidades críticas
        score += self.metrics['vulnerabilities_found'] * 10
        
        # Ataques bem-sucedidos
        score += self.metrics['successful_attacks'] * 15
        
        # Ajustar por falsos positivos
        score -= self.metrics['false_positives'] * 2
        
        return min(score, 100)  # Cap em 100
    
    def generate_executive_summary(self):
        """Gera resumo executivo para gestores"""
        risk_level = self.get_risk_level()
        
        return f"""
        === RESUMO EXECUTIVO - AUDITORIA BLUETOOTH ===
        
        📊 MÉTRICAS PRINCIPAIS:
        • Dispositivos analisados: {self.metrics['devices_discovered']}
        • Vulnerabilidades encontradas: {self.metrics['vulnerabilities_found']}
        • Nível de risco: {risk_level}
        • Duração da auditoria: {self.metrics['test_duration']} horas
        
        🎯 RECOMENDAÇÕES PRIORITÁRIAS:
        {self.get_priority_recommendations()}
        
        💰 IMPACTO POTENCIAL:
        {self.calculate_business_impact()}
        """
    
    def get_risk_level(self):
        score = self.calculate_risk_score()
        if score >= 80: return "🔴 CRÍTICO"
        elif score >= 60: return "🟡 ALTO"
        elif score >= 40: return "🟠 MÉDIO"
        else: return "🟢 BAIXO"
```

### Dashboard de Monitoramento:

```html
<!-- dashboard.html - Dashboard em tempo real -->
<!DOCTYPE html>
<html>
<head>
    <title>BlueSecAudit v2.0 - Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; background: #f5f5f5; }
        .dashboard { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; padding: 20px; }
        .widget { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { font-size: 2em; font-weight: bold; text-align: center; }
        .status-running { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-critical { color: #e74c3c; }
    </style>
</head>
<body>
    <div class="dashboard">
        <div class="widget">
            <h3>📊 Status da Auditoria</h3>
            <div id="audit-status" class="metric status-running">EM ANDAMENTO</div>
            <p>Iniciada: <span id="start-time"></span></p>
            <p>Duração: <span id="duration"></span></p>
        </div>
        
        <div class="widget">
            <h3>🎯 Dispositivos Descobertos</h3>
            <div id="devices-count" class="metric">0</div>
            <div id="devices-chart"></div>
        </div>
        
        <div class="widget">
            <h3>🚨 Vulnerabilidades</h3>
            <div id="vulns-count" class="metric status-warning">0</div>
            <div id="vulns-severity"></div>
        </div>
        
        <div class="widget">
            <h3>📈 Score de Risco</h3>
            <div id="risk-score" class="metric">0</div>
            <div id="risk-gauge"></div>
        </div>
    </div>
    
    <script>
        // Atualizar dashboard a cada 5 segundos
        setInterval(updateDashboard, 5000);
        
        function updateDashboard() {
            fetch('/api/metrics')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('devices-count').textContent = data.devices_discovered;
                    document.getElementById('vulns-count').textContent = data.vulnerabilities_found;
                    document.getElementById('risk-score').textContent = data.risk_score;
                    
                    updateCharts(data);
                });
        }
        
        function updateCharts(data) {
            // Atualizar gráficos com Plotly.js
            Plotly.newPlot('risk-gauge', [{
                type: "indicator",
                mode: "gauge+number",
                value: data.risk_score,
                domain: {x: [0, 1], y: [0, 1]},
                gauge: {
                    axis: {range: [null, 100]},
                    bar: {color: "darkblue"},
                    steps: [
                        {range: [0, 40], color: "lightgray"},
                        {range: [40, 80], color: "yellow"},
                        {range: [80, 100], color: "red"}
                    ]
                }
            }]);
        }
        
        // Inicializar dashboard
        updateDashboard();
    </script>
</body>
</html>
```

---

## 🚨 RESPOSTA A INCIDENTES

### Plano de Resposta Automatizado:

```bash
#!/bin/bash
# incident-response.sh

INCIDENT_LOG="/var/log/bluesecaudit/incidents.log"
EMERGENCY_CONTACTS="emergency-contacts.txt"

log_incident() {
    local severity="$1"
    local description="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$severity] $description" >> "$INCIDENT_LOG"
    
    # Notificar baseado na severidade
    case "$severity" in
        "CRITICAL")
            send_emergency_alert "$description"
            stop_all_tests
            preserve_evidence
            ;;
        "HIGH")
            send_alert "$description"
            ;;
        "MEDIUM")
            log_for_review "$description"
            ;;
    esac
}

stop_all_tests() {
    echo "🚨 PARANDO TODOS OS TESTES DE EMERGÊNCIA"
    
    # Parar BlueSecAudit
    pkill -f "bs-at-v2.sh" || true
    
    # Parar capturas
    pkill -f "hcidump" || true
    pkill -f "tshark" || true
    
    # Desconectar dispositivos
    bluetoothctl disconnect 2>/dev/null || true
    
    # Desativar adaptador se necessário
    sudo hciconfig hci0 down
    
    log_incident "INFO" "Todos os testes foram interrompidos por emergência"
}

preserve_evidence() {
    echo "🔒 PRESERVANDO EVIDÊNCIAS"
    
    local evidence_dir="/var/log/bluesecaudit/evidence/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$evidence_dir"
    
    # Copiar logs
    cp -r logs/* "$evidence_dir/" 2>/dev/null || true
    
    # Copiar resultados
    cp -r results/* "$evidence_dir/" 2>/dev/null || true
    
    # Estado do sistema
    ps aux > "$evidence_dir/processes.txt"
    netstat -an > "$evidence_dir/network.txt"
    hciconfig -a > "$evidence_dir/bluetooth.txt"
    
    # Criar hash para integridade
    find "$evidence_dir" -type f -exec sha256sum {} \; > "$evidence_dir/integrity.sha256"
    
    log_incident "INFO" "Evidências preservadas em: $evidence_dir"
}

send_emergency_alert() {
    local message="$1"
    
    # Notificar por email (se configurado)
    if command -v mail >/dev/null 2>&1; then
        echo "EMERGÊNCIA BlueSecAudit: $message" | mail -s "INCIDENTE CRÍTICO" admin@company.com
    fi
    
    # Notificar por SMS (se configurado)
    if [[ -f "sms-gateway.sh" ]]; then
        ./sms-gateway.sh "EMERGÊNCIA BlueSecAudit: $message"
    fi
    
    # Log local
    echo "🚨 ALERTA ENVIADO: $message" | tee -a "$INCIDENT_LOG"
}

# Monitoramento contínuo de indicadores de problema
monitor_for_incidents() {
    while true; do
        # Verificar uso excessivo de CPU
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        if (( $(echo "$cpu_usage > 90" | bc -l) )); then
            log_incident "HIGH" "Uso de CPU crítico: $cpu_usage%"
        fi
        
        # Verificar dispositivos que não respondem
        for device in $(cat authorized_devices.txt); do
            if ! timeout 5 l2ping -c 1 "$device" >/dev/null 2>&1; then
                log_incident "MEDIUM" "Dispositivo $device não responde"
            fi
        done
        
        # Verificar falhas de autenticação
        auth_failures=$(grep -c "Authentication failed" "$INCIDENT_LOG" || echo "0")
        if [[ $auth_failures -gt 5 ]]; then
            log_incident "HIGH" "Múltiplas falhas de autenticação detectadas"
        fi
        
        sleep 30
    done
}

# Iniciar monitoramento se executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_for_incidents
fi
```

---

## 📚 CONCLUSÃO E PRÓXIMOS PASSOS

### Implementação Gradual Recomendada:

**Fase 1 - Preparação (Semana 1-2)**:
- ✅ Configurar ambiente de laboratório isolado
- ✅ Obter todas as autorizações legais necessárias
- ✅ Treinar equipe em procedimentos de segurança
- ✅ Configurar sistemas de monitoramento e logs

**Fase 2 - Testes Básicos (Semana 3-4)**:
- ✅ Executar apenas ataques de baixo risco (SDP enumeration)
- ✅ Validar procedimentos de resposta a incidentes
- ✅ Refinar templates de documentação
- ✅ Estabelecer métricas de baseline

**Fase 3 - Testes Intermediários (Semana 5-6)**:
- ✅ Introduzir ataques de médio risco (OBEX, conectividade)
- ✅ Implementar dashboard de monitoramento
- ✅ Estabelecer procedimentos de backup e recuperação
- ✅ Validar compliance com regulamentações

**Fase 4 - Testes Avançados (Semana 7-8)**:
- ✅ Implementar ataques de alto risco (apenas com autorização específica)
- ✅ Configurar alertas automáticos de segurança
- ✅ Finalizar documentação de processos
- ✅ Treinar equipe de resposta a incidentes

### Certificação de Competência:

Para uso profissional do BlueSecAudit v2.0 em ataques reais, recomenda-se:

1. **Certificação Técnica**: CEH, OSCP, ou equivalente
2. **Treinamento Legal**: Curso sobre legislação cibernética
3. **Experiência Prática**: Mínimo 100 horas em ambiente controlado
4. **Aprovação Organizacional**: Autorização formal da empresa/cliente

### Suporte Contínuo:

- 📧 **Suporte Técnico**: support@bluesecaudit.org
- 📚 **Documentação**: wiki.bluesecaudit.org
- 🎓 **Treinamentos**: training.bluesecaudit.org
- 🔄 **Atualizações**: github.com/bluesecaudit/v2

---

**VERSÃO**: 2.0.0  
**CLASSIFICAÇÃO**: CONFIDENCIAL - USO PROFISSIONAL AUTORIZADO  
**ÚLTIMA ATUALIZAÇÃO**: $(date)

*Este documento é parte integrante do BlueSecAudit v2.0 e deve ser seguido rigorosamente para uso em ambientes de produção.* 