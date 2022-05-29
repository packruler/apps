{{- define "traefik.plugins.setup" -}}
  {{- if .Values.pilot.enableThemePark -}}
    {{- $pluginPersistence := fromJson "{\"plugins\": {\"enabled\": true, \"mountPath\": \"/plugins-storage\"}" -}}
    {{- $_ := set .Values "persistence" $pluginPersistence -}}
  {{- end -}}
{{- end -}}
