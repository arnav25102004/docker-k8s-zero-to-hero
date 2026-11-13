{{/* The name every object shares: the release name, unless it already contains the chart name. */}}
{{- define "canteen.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Labels put on every object. */}}
{{- define "canteen.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Labels a Service uses to find the app's Pods. Keep these few and stable. */}}
{{- define "canteen.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* The Secret that holds the admin token: yours, or the one this chart creates. */}}
{{- define "canteen.secretName" -}}
{{- default (printf "%s-admin" (include "canteen.fullname" .)) .Values.existingSecret -}}
{{- end -}}

{{/* The image to run: the tag you set, or the chart's appVersion. */}}
{{- define "canteen.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}
