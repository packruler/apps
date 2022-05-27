{{- define "sonarr.theme" -}}
{{- if .Values.addons.themePark.enabled -}}

{{- $serviceName := include "common.names.fullname" . -}}

{{- $middlewareName := printf "%v-theme" $serviceName -}}

{{- $appName := .Chart.Name -}}
{{- $themeName := .Values.addons.themePark.themeName -}}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: sonarr
spec:
  plugin:
    themePark:
      app: {{ $appName }}
      theme: {{ $themeName }}

{{- end -}}
{{- end -}}
