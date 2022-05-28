{{- define "common.theme" -}}
{{- if .Values.addons.themePark.enabled -}}

{{- $serviceName := include "common.names.fullname" . -}}

{{- $appName := .Chart.Name -}}
{{- $themeName := .Values.addons.themePark.themeName -}}
{{- $_ := set .Values.addons.themePark "middlewareReference" ( printf "%s-theme@kubernetescrd" .Release.Namespace ) }}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: theme
spec:
  plugin:
    themePark:
      app: {{ $appName }}
      theme: {{ $themeName }}

{{- end -}}
{{- end -}}
