{{- define "sonarr.theme" -}}
{{- if .Values.addons.themePark.enabled -}}

{{- $serviceName := include "common.names.fullname" . -}}
{{- if and (hasKey $values "nameOverride") $values.nameOverride -}}
  {{- $serviceName = printf "%v-%v" $serviceName $values.nameOverride -}}
{{- end -}}

{{- $middlewareName := printf "%v-theme" $serviceName -}}
{{- .Values.ingress.middlewares = append .Values.ingress.middlewares $middlewareName -}}

{{- $appName := .Chart.Name -}}
{{- $themeName := .Values.addons.themePark.themeName -}}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: {{ $middlewareName }}
spec:
  themePark:
    app: {{ $appName }}
    theme: {{ $themeName }}

{{- end -}}
{{- end -}}
