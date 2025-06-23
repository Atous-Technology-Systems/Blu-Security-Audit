#!/usr/bin/env python3
"""
BlueSecAudit v2.0 - Final Report Generator
Gera relatórios consolidados de auditoria de segurança Bluetooth
"""

import sys
import json
import argparse
import datetime
from pathlib import Path

class BlueSecAuditReportGenerator:
    def __init__(self, session_id, results_dir="results", logs_dir="logs"):
        self.session_id = session_id
        self.results_dir = Path(results_dir)
        self.logs_dir = Path(logs_dir)
        self.report_data = {
            'session_id': session_id,
            'timestamp': datetime.datetime.now().isoformat(),
            'targets': [],
            'attacks': [],
            'vulnerabilities': [],
            'recommendations': [],
            'files_analyzed': []
        }

    def collect_session_data(self):
        """Coleta todos os dados da sessão"""
        print(f"🔍 Coletando dados da sessão {self.session_id}...")
        
        # Buscar arquivos de resultados da sessão
        session_files = list(self.results_dir.glob(f"*{self.session_id}*"))
        
        for file_path in session_files:
            if file_path.is_file():
                self._process_result_file(file_path)
        
        # Buscar auditorias completas
        audit_dirs = list(self.results_dir.glob(f"full_audit_*{self.session_id}"))
        for audit_dir in audit_dirs:
            if audit_dir.is_dir():
                self._process_audit_directory(audit_dir)
        
        print(f"✅ Coletados dados de {len(self.report_data['files_analyzed'])} arquivos")

    def _process_result_file(self, file_path):
        """Processa um arquivo de resultado individual"""
        try:
            filename = file_path.name
            file_size = file_path.stat().st_size
            
            self.report_data['files_analyzed'].append({
                'filename': filename,
                'size': file_size,
                'type': self._classify_file_type(filename)
            })
            
            # Extrair informações específicas por tipo
            if 'bluesmack' in filename:
                self._process_bluesmack_file(file_path)
            elif 'sdp' in filename:
                self._process_sdp_file(file_path)
            elif 'pin_bruteforce' in filename:
                self._process_pin_file(file_path)
            elif 'obex' in filename:
                self._process_obex_file(file_path)
                
        except Exception as e:
            print(f"⚠️ Erro processando {file_path}: {e}")

    def _process_audit_directory(self, audit_dir):
        """Processa diretório de auditoria completa"""
        try:
            # Ler relatório HTML principal se existir
            html_report = audit_dir / "audit_report.html"
            if html_report.exists():
                with open(html_report, 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Extrair informações básicas do HTML
                    target = self._extract_target_from_html(content)
                    if target:
                        self.report_data['targets'].append(target)
            
            # Processar outros arquivos da auditoria
            for file_path in audit_dir.glob("*.txt"):
                self._process_result_file(file_path)
                
        except Exception as e:
            print(f"⚠️ Erro processando auditoria {audit_dir}: {e}")

    def _classify_file_type(self, filename):
        """Classifica o tipo de arquivo de resultado"""
        if 'bluesmack' in filename:
            return 'DoS Attack'
        elif 'sdp' in filename:
            return 'Service Enumeration'
        elif 'pin' in filename:
            return 'Authentication Attack'
        elif 'obex' in filename:
            return 'File System Access'
        elif 'hid' in filename:
            return 'HID Injection'
        elif 'audio' in filename:
            return 'Audio Interception'
        elif 'ble' in filename:
            return 'BLE Attack'
        else:
            return 'Unknown'

    def _process_bluesmack_file(self, file_path):
        """Processa arquivo de resultado BlueSmack"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            attack_data = {
                'type': 'BlueSmack DoS',
                'target': self._extract_target_from_content(content),
                'timestamp': self._extract_timestamp_from_content(content),
                'success': 'SUCCESS' in content,
                'file': str(file_path)
            }
            
            self.report_data['attacks'].append(attack_data)
            
            if attack_data['success']:
                vulnerability = {
                    'type': 'DoS Vulnerability',
                    'severity': 'High',
                    'target': attack_data['target'],
                    'description': 'Device susceptible to L2CAP ping flood DoS attack',
                    'recommendation': 'Implement rate limiting or update firmware'
                }
                self.report_data['vulnerabilities'].append(vulnerability)
                
        except Exception as e:
            print(f"⚠️ Erro processando BlueSmack {file_path}: {e}")

    def _process_sdp_file(self, file_path):
        """Processa arquivo de enumeração SDP"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Contar serviços encontrados
            service_count = content.count('Service Name:')
            protocol_count = content.count('Protocol Descriptor List:')
            
            attack_data = {
                'type': 'SDP Enumeration',
                'target': self._extract_target_from_content(content),
                'timestamp': self._extract_timestamp_from_content(content),
                'services_found': service_count,
                'protocols_found': protocol_count,
                'file': str(file_path)
            }
            
            self.report_data['attacks'].append(attack_data)
            
            # Analisar serviços para vulnerabilidades
            if 'Serial Port' in content:
                vulnerability = {
                    'type': 'Insecure Service',
                    'severity': 'Medium',
                    'target': attack_data['target'],
                    'description': 'Serial Port Profile (SPP) available',
                    'recommendation': 'Disable SPP if not required'
                }
                self.report_data['vulnerabilities'].append(vulnerability)
            
            if 'OBEX' in content:
                vulnerability = {
                    'type': 'File Access',
                    'severity': 'Medium',
                    'target': attack_data['target'],
                    'description': 'OBEX file transfer available',
                    'recommendation': 'Enable authentication for OBEX'
                }
                self.report_data['vulnerabilities'].append(vulnerability)
                
        except Exception as e:
            print(f"⚠️ Erro processando SDP {file_path}: {e}")

    def _process_pin_file(self, file_path):
        """Processa arquivo de brute force PIN"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            attack_data = {
                'type': 'PIN Brute Force',
                'target': self._extract_target_from_content(content),
                'timestamp': self._extract_timestamp_from_content(content),
                'success': 'SUCCESS - PIN FOUND' in content,
                'file': str(file_path)
            }
            
            self.report_data['attacks'].append(attack_data)
            
            if attack_data['success']:
                vulnerability = {
                    'type': 'Weak Authentication',
                    'severity': 'Critical',
                    'target': attack_data['target'],
                    'description': 'Device uses weak PIN authentication',
                    'recommendation': 'Use strong PINs or upgrade to secure pairing'
                }
                self.report_data['vulnerabilities'].append(vulnerability)
                
        except Exception as e:
            print(f"⚠️ Erro processando PIN {file_path}: {e}")

    def _process_obex_file(self, file_path):
        """Processa arquivo de exploração OBEX"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            attack_data = {
                'type': 'OBEX Exploitation',
                'target': self._extract_target_from_content(content),
                'timestamp': self._extract_timestamp_from_content(content),
                'files_accessed': content.count('.vcf') + content.count('.jpg') + content.count('.png'),
                'file': str(file_path)
            }
            
            self.report_data['attacks'].append(attack_data)
            
        except Exception as e:
            print(f"⚠️ Erro processando OBEX {file_path}: {e}")

    def _extract_target_from_content(self, content):
        """Extrai endereço MAC do target do conteúdo"""
        import re
        mac_pattern = r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'
        match = re.search(mac_pattern, content)
        return match.group(0) if match else 'Unknown'

    def _extract_target_from_html(self, content):
        """Extrai target de conteúdo HTML"""
        if '<strong>Target:</strong>' in content:
            import re
            pattern = r'<strong>Target:</strong>\s*([0-9A-Fa-f:]+)'
            match = re.search(pattern, content)
            return match.group(1) if match else None
        return None

    def _extract_timestamp_from_content(self, content):
        """Extrai timestamp do conteúdo"""
        if 'Timestamp:' in content:
            lines = content.split('\n')
            for line in lines:
                if 'Timestamp:' in line:
                    return line.split('Timestamp:')[-1].strip()
        return datetime.datetime.now().isoformat()

    def generate_executive_summary(self):
        """Gera resumo executivo"""
        total_targets = len(set(attack['target'] for attack in self.report_data['attacks'] if 'target' in attack))
        total_attacks = len(self.report_data['attacks'])
        total_vulnerabilities = len(self.report_data['vulnerabilities'])
        
        critical_vulns = sum(1 for v in self.report_data['vulnerabilities'] if v.get('severity') == 'Critical')
        high_vulns = sum(1 for v in self.report_data['vulnerabilities'] if v.get('severity') == 'High')
        
        # Calcular risk score
        risk_score = min(100, critical_vulns * 25 + high_vulns * 15 + total_vulnerabilities * 5)
        
        if risk_score >= 80:
            risk_level = "🔴 CRÍTICO"
        elif risk_score >= 60:
            risk_level = "🟡 ALTO"
        elif risk_score >= 30:
            risk_level = "🟠 MÉDIO"
        else:
            risk_level = "🟢 BAIXO"
        
        return {
            'total_targets': total_targets,
            'total_attacks': total_attacks,
            'total_vulnerabilities': total_vulnerabilities,
            'critical_vulns': critical_vulns,
            'high_vulns': high_vulns,
            'risk_score': risk_score,
            'risk_level': risk_level
        }

    def generate_recommendations(self):
        """Gera recomendações baseadas nos achados"""
        recommendations = []
        
        # Recomendações baseadas em vulnerabilidades
        vuln_types = set(v.get('type') for v in self.report_data['vulnerabilities'])
        
        if 'DoS Vulnerability' in vuln_types:
            recommendations.append({
                'priority': 'High',
                'category': 'Availability',
                'recommendation': 'Implement DoS protection mechanisms and rate limiting'
            })
        
        if 'Weak Authentication' in vuln_types:
            recommendations.append({
                'priority': 'Critical',
                'category': 'Authentication',
                'recommendation': 'Upgrade to Secure Simple Pairing (SSP) or use strong PINs'
            })
        
        if 'Insecure Service' in vuln_types:
            recommendations.append({
                'priority': 'Medium',
                'category': 'Services',
                'recommendation': 'Disable unnecessary Bluetooth services and profiles'
            })
        
        if 'File Access' in vuln_types:
            recommendations.append({
                'priority': 'Medium',
                'category': 'Data Protection',
                'recommendation': 'Enable authentication for file transfer services'
            })
        
        # Recomendações gerais
        recommendations.append({
            'priority': 'Low',
            'category': 'General',
            'recommendation': 'Regular security updates and monitoring of Bluetooth communications'
        })
        
        self.report_data['recommendations'] = recommendations
        return recommendations

    def generate_html_report(self, output_file):
        """Gera relatório HTML final consolidado"""
        summary = self.generate_executive_summary()
        recommendations = self.generate_recommendations()
        
        html_content = f"""
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BlueSecAudit v2.0 - Relatório Final Consolidado</title>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background: #f8f9fa; }}
        .container {{ max-width: 1200px; margin: 40px auto; background: white; border-radius: 10px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); overflow: hidden; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }}
        .content {{ padding: 40px; }}
        h1 {{ margin: 0; font-size: 2.5em; font-weight: 300; }}
        h2 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; margin-top: 40px; }}
        h3 {{ color: #34495e; margin-top: 30px; }}
        .metric-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 30px 0; }}
        .metric-card {{ background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #3498db; }}
        .metric-value {{ font-size: 2em; font-weight: bold; color: #2c3e50; }}
        .metric-label {{ color: #7f8c8d; font-size: 0.9em; margin-top: 5px; }}
        .risk-critical {{ border-left-color: #e74c3c; }}
        .risk-high {{ border-left-color: #f39c12; }}
        .risk-medium {{ border-left-color: #f1c40f; }}
        .risk-low {{ border-left-color: #27ae60; }}
        .vulnerability {{ background: #fff5f5; border: 1px solid #feb2b2; border-radius: 5px; padding: 15px; margin: 10px 0; }}
        .vuln-critical {{ border-color: #e53e3e; background: #fed7d7; }}
        .vuln-high {{ border-color: #dd6b20; background: #feebc8; }}
        .vuln-medium {{ border-color: #d69e2e; background: #faf089; }}
        .attack-item {{ background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 5px; padding: 15px; margin: 10px 0; }}
        .recommendation {{ background: #f0fff4; border: 1px solid #9ae6b4; border-radius: 5px; padding: 15px; margin: 10px 0; }}
        .priority-critical {{ border-left: 4px solid #e53e3e; }}
        .priority-high {{ border-left: 4px solid #dd6b20; }}
        .priority-medium {{ border-left: 4px solid #d69e2e; }}
        .priority-low {{ border-left: 4px solid #38a169; }}
        .file-list {{ background: #f8f9fa; border-radius: 5px; padding: 20px; }}
        .file-item {{ display: flex; justify-content: space-between; padding: 5px 0; border-bottom: 1px solid #e9ecef; }}
        .timeline {{ position: relative; padding: 20px 0; }}
        .timeline-item {{ margin: 20px 0; padding-left: 30px; border-left: 2px solid #3498db; }}
        .timeline-marker {{ position: absolute; left: -6px; width: 12px; height: 12px; background: #3498db; border-radius: 50%; }}
        .footer {{ background: #2c3e50; color: white; padding: 30px; text-align: center; }}
        .badge {{ display: inline-block; padding: 4px 8px; border-radius: 12px; font-size: 0.8em; font-weight: bold; }}
        .badge-success {{ background: #d4edda; color: #155724; }}
        .badge-warning {{ background: #fff3cd; color: #856404; }}
        .badge-danger {{ background: #f8d7da; color: #721c24; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 BlueSecAudit v2.0</h1>
            <p>Relatório Final Consolidado de Auditoria Bluetooth</p>
            <p>Sessão: {self.session_id} | Gerado em: {datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')}</p>
        </div>
        
        <div class="content">
            <h2>📊 Resumo Executivo</h2>
            <div class="metric-grid">
                <div class="metric-card">
                    <div class="metric-value">{summary['total_targets']}</div>
                    <div class="metric-label">Dispositivos Analisados</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">{summary['total_attacks']}</div>
                    <div class="metric-label">Ataques Executados</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">{summary['total_vulnerabilities']}</div>
                    <div class="metric-label">Vulnerabilidades</div>
                </div>
                <div class="metric-card risk-{summary['risk_level'].split()[1].lower()}">
                    <div class="metric-value">{summary['risk_score']}</div>
                    <div class="metric-label">Risk Score</div>
                </div>
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
                <h3>Nível de Risco: {summary['risk_level']}</h3>
            </div>

            <h2>🎯 Ataques Executados</h2>
            <div class="timeline">
        """
        
        for i, attack in enumerate(self.report_data['attacks']):
            success_badge = "badge-success" if attack.get('success', False) else "badge-warning"
            success_text = "Sucesso" if attack.get('success', False) else "Executado"
            
            html_content += f"""
                <div class="timeline-item">
                    <div class="timeline-marker"></div>
                    <div class="attack-item">
                        <h4>{attack.get('type', 'Unknown Attack')} <span class="badge {success_badge}">{success_text}</span></h4>
                        <p><strong>Target:</strong> {attack.get('target', 'Unknown')}</p>
                        <p><strong>Timestamp:</strong> {attack.get('timestamp', 'Unknown')}</p>
                        {f"<p><strong>Serviços:</strong> {attack.get('services_found', 0)}</p>" if 'services_found' in attack else ""}
                        {f"<p><strong>Arquivos:</strong> {attack.get('files_accessed', 0)}</p>" if 'files_accessed' in attack else ""}
                    </div>
                </div>
            """
        
        html_content += """
            </div>

            <h2>🚨 Vulnerabilidades Identificadas</h2>
        """
        
        if self.report_data['vulnerabilities']:
            for vuln in self.report_data['vulnerabilities']:
                severity_class = f"vuln-{vuln.get('severity', 'medium').lower()}"
                html_content += f"""
                <div class="vulnerability {severity_class}">
                    <h4>{vuln.get('type', 'Unknown')} - {vuln.get('severity', 'Unknown')} Severity</h4>
                    <p><strong>Target:</strong> {vuln.get('target', 'Unknown')}</p>
                    <p><strong>Descrição:</strong> {vuln.get('description', 'No description')}</p>
                    <p><strong>Recomendação:</strong> {vuln.get('recommendation', 'No recommendation')}</p>
                </div>
                """
        else:
            html_content += "<p>✅ Nenhuma vulnerabilidade crítica identificada.</p>"
        
        html_content += """
            <h2>💡 Recomendações de Segurança</h2>
        """
        
        for rec in recommendations:
            priority_class = f"priority-{rec.get('priority', 'low').lower()}"
            html_content += f"""
            <div class="recommendation {priority_class}">
                <h4>{rec.get('category', 'General')} - Prioridade {rec.get('priority', 'Low')}</h4>
                <p>{rec.get('recommendation', 'No recommendation')}</p>
            </div>
            """
        
        html_content += f"""
            <h2>📁 Arquivos Analisados</h2>
            <div class="file-list">
        """
        
        for file_info in self.report_data['files_analyzed']:
            file_size_mb = round(file_info['size'] / 1024 / 1024, 2) if file_info['size'] > 1024*1024 else round(file_info['size'] / 1024, 2)
            size_unit = "MB" if file_info['size'] > 1024*1024 else "KB"
            
            html_content += f"""
                <div class="file-item">
                    <span>{file_info['filename']}</span>
                    <span>{file_info['type']} ({file_size_mb} {size_unit})</span>
                </div>
            """
        
        html_content += f"""
            </div>

            <h2>🔍 Detalhes Técnicos</h2>
            <div class="attack-item">
                <h4>Informações da Sessão</h4>
                <p><strong>ID da Sessão:</strong> {self.session_id}</p>
                <p><strong>Data de Geração:</strong> {datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')}</p>
                <p><strong>Total de Arquivos:</strong> {len(self.report_data['files_analyzed'])}</p>
                <p><strong>Metodologia:</strong> BlueSecAudit v2.0 Automated Testing</p>
            </div>
        </div>
        
        <div class="footer">
            <p>🔐 BlueSecAudit v2.0 - Advanced Bluetooth Security Auditing Tool</p>
            <p>⚠️ Este relatório contém informações confidenciais de segurança</p>
            <p>📞 Para questões técnicas: security@bluesecaudit.org</p>
        </div>
    </div>
</body>
</html>
        """
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"✅ Relatório HTML gerado: {output_file}")

    def generate_json_report(self, output_file):
        """Gera relatório JSON para processamento automatizado"""
        summary = self.generate_executive_summary()
        
        final_report = {
            'metadata': {
                'session_id': self.session_id,
                'generated_at': datetime.datetime.now().isoformat(),
                'tool_version': 'BlueSecAudit v2.0',
                'report_version': '1.0'
            },
            'summary': summary,
            'data': self.report_data
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(final_report, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Relatório JSON gerado: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='BlueSecAudit v2.0 - Final Report Generator')
    parser.add_argument('--session', required=True, help='Session ID to process')
    parser.add_argument('--output', required=True, help='Output HTML file path')
    parser.add_argument('--json', help='Output JSON file path (optional)')
    parser.add_argument('--results-dir', default='results', help='Results directory')
    parser.add_argument('--logs-dir', default='logs', help='Logs directory')
    
    args = parser.parse_args()
    
    print("🚀 BlueSecAudit v2.0 - Final Report Generator")
    print(f"📋 Processando sessão: {args.session}")
    
    try:
        generator = BlueSecAuditReportGenerator(
            session_id=args.session,
            results_dir=args.results_dir,
            logs_dir=args.logs_dir
        )
        
        generator.collect_session_data()
        generator.generate_html_report(args.output)
        
        if args.json:
            generator.generate_json_report(args.json)
        
        print("🎉 Relatório final gerado com sucesso!")
        
    except Exception as e:
        print(f"❌ Erro gerando relatório: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main() 