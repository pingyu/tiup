#!/bin/bash
set -e

# WARNING: This file was auto-generated. Do not edit!
#          All your edit might be overwritten!
DEPLOY_DIR={{.DeployDir}}
cd "${DEPLOY_DIR}" || exit 1

{{- if .NumaNode}}
exec numactl --cpunodebind={{.NumaNode}} --membind={{.NumaNode}} bin/tikv-worker \
{{- else}}
exec bin/tikv-worker \
{{- end}}
    --addr "{{.Addr}}" \
    --pd-endpoints "{{.PD}}" \
{{- if .TLSEnabled}}
    --cacert tls/ca.crt \
    --cert tls/cdc.crt \
    --key tls/cdc.pem \
{{- end}}
    --config conf/tikv_worker.toml \
    --log-file "{{.LogDir}}/tikv_worker.log" 2>> "{{.LogDir}}/tikv_worker_stderr.log"
