---
global:
{{- if .ScrapeInterval}}
  scrape_interval: {{.ScrapeInterval}}
{{- else}}
  scrape_interval: 15s # By default, scrape targets every 15 seconds.
{{- end}}
  evaluation_interval: 15s # By default, scrape targets every 15 seconds.
{{- if .ScrapeTimeout}}
  scrape_timeout: {{.ScrapeTimeout}}
{{- end}}
  external_labels:
    cluster: '{{.ClusterName}}'
    monitor: "prometheus"

# Load and evaluate rules in this file every 'evaluation_interval' seconds.
rule_files:
{{- if .LocalRules}}
{{- range .LocalRules}}
  - '{{.}}'
{{- end}}
{{- else}}
{{- if and .MonitoredServers .PDAddrs}}
  - 'node.rules.yml'
  - 'blacker.rules.yml'
  - 'bypass.rules.yml'
{{- end}}
{{- if .PDAddrs}}
  - 'pd.rules.yml'
{{- end}}
{{- if .TiDBStatusAddrs}}
  - 'tidb.rules.yml'
{{- end}}
{{- if .TiKVStatusAddrs}}
  - 'tikv.rules.yml'
{{- if .HasTiKVAccelerateRules}}
  - 'tikv.accelerate.rules.yml'
{{- end}}
{{- end}}
{{- if .TiFlashStatusAddrs}}
  - 'tiflash.rules.yml'
{{- end}}
{{- if .PumpAddrs}}
  - 'binlog.rules.yml'
{{- end}}
{{- if .CDCAddrs}}
  - 'ticdc.rules.yml'
{{- end}}
{{- if .LightningAddrs}}
  - 'lightning.rules.yml'
{{- end}}
{{- if .DMWorkerAddrs}}
  - 'dm_worker.rules.yml'
{{- end}}
{{- end}}

{{- if .AlertmanagerAddrs}}
alerting:
  alertmanagers:
  - static_configs:
    - targets:
{{- range .AlertmanagerAddrs}}
      - '{{.}}'
{{- end}}
{{- end}}

scrape_configs:
{{- if .PushgatewayAddrs}}
  - job_name: 'overwritten-cluster'
    scrape_interval: 15s
    honor_labels: true # don't overwrite job & instance labels
    static_configs:
    - targets:
{{- range .PushgatewayAddrs}}
      - '{{.}}'
{{- end}}
{{- end}}
{{- if .LightningAddrs}}
  - job_name: "lightning"
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
      - targets: ['{{index .LightningAddrs 0}}']
{{- end}}
  - job_name: "overwritten-nodes"
    honor_labels: true # don't overwrite job & instance labels
    static_configs:
    - targets:
{{- range .NodeExporterAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "tidb"
    honor_labels: true # don't overwrite job & instance labels
    metric_relabel_configs:
      - action: drop
        regex: tidb_tikvclient_source_request_seconds_count|tidb_tikvclient_batch_requests_sum|tidb_tikvclient_batch_requests_count|tidb_tikvclient_batch_pending_requests_sum|tidb_tikvclient_batch_pending_requests_count
        source_labels:
        - __name__
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .TiDBStatusAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "tiproxy"
    honor_labels: true # don't overwrite job & instance labels
    metrics_path: /api/metrics
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .TiProxyStatusAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "tikv"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .TiKVStatusAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "pd"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .PDAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "tso"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .TSOAddrs}}
      - '{{.}}'
{{- end}}
  - job_name: "scheduling"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .SchedulingAddrs}}
      - '{{.}}'
{{- end}}
{{- if .TiFlashStatusAddrs}}
  - job_name: "tiflash"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
    {{- range .TiFlashStatusAddrs}}
       - '{{.}}'
    {{- end}}
    {{- range .TiFlashLearnerStatusAddrs}}
       - '{{.}}'
    {{- end}}
{{- end}}
{{- if .PumpAddrs}}
  - job_name: 'pump'
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
    {{- range .PumpAddrs}}
      - '{{.}}'
    {{- end}}
  - job_name: 'drainer'
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
    {{- range .DrainerAddrs}}
      - '{{.}}'
    {{- end}}
  - job_name: "port_probe"
    scrape_interval: 30s
    metrics_path: /probe
    params:
{{- if .TLSEnabled}}
      module: [tls_connect]
{{- else}}
      module: [tcp_connect]
{{- end}}
    static_configs:
    - targets:
{{- range .PumpAddrs}}
      - '{{.}}'
{{- end}}
      labels:
        group: 'pump'
    - targets:
    {{- range .DrainerAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'drainer'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: '{{.BlackboxAddr}}'
{{- end}}
{{- if .CDCAddrs}}
  - job_name: "ticdc"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .CDCAddrs}}
      - '{{.}}'
{{- end}}
{{- end}}
{{- if .TiKVCDCAddrs}}
  - job_name: "tikv-cdc"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .TiKVCDCAddrs}}
      - '{{.}}'
{{- end}}
{{- end}}
{{- if .NGMonitoringAddrs}}
  - job_name: "ng-monitoring"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
{{- range .NGMonitoringAddrs}}
      - '{{.}}'
{{- end}}
{{- end}}
  - job_name: "tidb_port_probe"
    scrape_interval: 30s
    metrics_path: /probe
    params:
{{- if .TLSEnabled}}
      module: [tls_connect]
{{- else}}
      module: [tcp_connect]
{{- end}}
    static_configs:
    - targets:
    {{- range .TiDBStatusAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'tidb'
    - targets:
    {{- range .TiKVStatusAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'tikv'
    - targets:
    {{- range .PDAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'pd'
{{- if .TiFlashStatusAddrs}}
    - targets:
    {{- range .TiFlashStatusAddrs}}
       - '{{.}}'
    {{- end}}
      labels:
        group: 'tiflash'
{{- end}}
{{- if .CDCAddrs}}
    - targets:
    {{- range .CDCAddrs}}
       - '{{.}}'
    {{- end}}
      labels:
        group: 'ticdc'
{{- end}}
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: '{{.BlackboxAddr}}'
  - job_name: "monitor_port_probe"
    scrape_interval: 30s
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
{{- if .PushgatewayAddrs}}
    - targets:
{{- range .PushgatewayAddrs}}
      - '{{.}}'
{{- end}}
      labels:
        group: 'pushgateway'
{{- end}}
{{- if .GrafanaAddr}}
    - targets:
      - '{{.GrafanaAddr}}'
      labels:
        group: 'grafana'
{{- end}}
    - targets:
    {{- range .NodeExporterAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'node_exporter'
    - targets:
    {{- range .BlackboxExporterAddrs}}
      - '{{.}}'
    {{- end}}
      labels:
        group: 'blackbox_exporter'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      {{- if .BlackboxAddr}}
      - target_label: __address__
        replacement: '{{.BlackboxAddr}}'
      {{- end}}
{{- range $addr := .BlackboxExporterAddrs}}
  - job_name: "blackbox_exporter_{{$addr}}_icmp"
    scrape_interval: 6s
    metrics_path: /probe
    params:
      module: [icmp]
    static_configs:
    - targets:
    {{- range $.MonitoredServers}}
      - '{{.}}'
    {{- end}}
    relabel_configs:
      - source_labels: [__address__]
        regex: (.*)(:80)?
        target_label: __param_target
        replacement: ${1}
      - source_labels: [__param_target]
        regex: (.*)
        target_label: ping
        replacement: ${1}
      - source_labels: []
        regex: .*
        target_label: __address__
        replacement: '{{$addr}}'
{{- end}}

{{- if .DMMasterAddrs}}
  - job_name: "dm_master"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
    {{- range .DMMasterAddrs}}
      - '{{.}}'
    {{- end}}
{{- end}}

{{- if .DMWorkerAddrs}}
  - job_name: "dm_worker"
    honor_labels: true # don't overwrite job & instance labels
{{- if .TLSEnabled}}
    scheme: https
    tls_config:
      insecure_skip_verify: false
      ca_file: ../tls/ca.crt
      cert_file: ../tls/prometheus.crt
      key_file: ../tls/prometheus.pem
{{- end}}
    static_configs:
    - targets:
    {{- range .DMWorkerAddrs}}
      - '{{.}}'
    {{- end}}
{{- end}}

{{- if .RemoteConfig}}
{{.RemoteConfig}}
{{- end}}
