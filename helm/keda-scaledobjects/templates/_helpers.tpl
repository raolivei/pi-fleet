{{/*
Expand the name of the chart.
*/}}
{{- define "keda-scaledobjects.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "keda-scaledobjects.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "keda-scaledobjects.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "keda-scaledobjects.labels" -}}
helm.sh/chart: {{ include "keda-scaledobjects.chart" . }}
{{ include "keda-scaledobjects.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "keda-scaledobjects.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keda-scaledobjects.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get service name for Prometheus query
*/}}
{{- define "keda-scaledobjects.serviceName" -}}
{{- if .serviceName }}
{{- .serviceName }}
{{- else if .scaleTargetRef }}
{{- .scaleTargetRef.name }}
{{- else }}
{{- printf "%s-%s" .namespace .component }}
{{- end }}
{{- end }}

