{{/*
Generate image-list annotation value from images array
*/}}
{{- define "timothyw-system.imageList" -}}
{{- $list := list -}}
{{- range . -}}
  {{- $list = append $list (printf "%s=%s" .alias .image) -}}
{{- end -}}
{{- join "," $list -}}
{{- end -}}
