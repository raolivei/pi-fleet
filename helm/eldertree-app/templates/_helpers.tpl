{{/*
Expand the name of the chart.
*/}}
{{- define "eldertree-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name. Uses release name.
*/}}
{{- define "eldertree-app.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for a component.
*/}}
{{- define "eldertree-app.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Component labels (app + component).
*/}}
{{- define "eldertree-app.componentLabels" -}}
app: {{ .releaseName }}
component: {{ .componentName }}
{{- end }}

{{/*
Selector labels for a component.
*/}}
{{- define "eldertree-app.selectorLabels" -}}
app: {{ .releaseName }}
component: {{ .componentName }}
{{- end }}

{{/*
Resolve the namespace. Prefer explicit, then release namespace.
*/}}
{{- define "eldertree-app.namespace" -}}
{{- .Release.Namespace }}
{{- end }}

{{/*
Merge security contexts: component overrides global.
*/}}
{{- define "eldertree-app.podSecurityContext" -}}
{{- $ctx := .global.podSecurityContext | default dict }}
{{- if .component.podSecurityContext }}
{{- $ctx = .component.podSecurityContext }}
{{- end }}
{{- toYaml $ctx }}
{{- end }}

{{- define "eldertree-app.securityContext" -}}
{{- $ctx := .global.securityContext | default dict }}
{{- if .component.securityContext }}
{{- $ctx = .component.securityContext }}
{{- end }}
{{- toYaml $ctx }}
{{- end }}

{{/*
Resolve service name for ingress paths (component name = service name).
*/}}
{{- define "eldertree-app.serviceName" -}}
{{- . }}
{{- end }}
