{{- define "sonarr.theme" -}}
{{- if .Values.addons.themePark.enabled -}}

{{- $serviceName := include "common.names.fullname" . -}}
{{- if and (hasKey $values "nameOverride") $values.nameOverride -}}
  {{- $serviceName = printf "%v-%v" $serviceName $values.nameOverride -}}
{{- end -}}

{{- $appName := .Chart.Name -}}
{{- $themeName := .Values.addons.themePark.themeName -}}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: {{ $serviceName }}-theme
spec:
  themePark:
    app: {{ $appName }}
    theme: {{ $themeName }}

{{- end -}}
{{- end -}}
