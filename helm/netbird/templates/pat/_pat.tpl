{{/*
Shared helpers for the Personal Access Token (PAT) bootstrap & rotation.
*/}}

{{- define "netbird.pat.name" -}}
netbird-pat-rotator
{{- end -}}

{{- define "netbird.pat.secretNamespace" -}}
{{ .Values.pat.secretNamespace | default .Release.Namespace }}
{{- end -}}

{{/* First owner email; empty value -> admin@crczp */}}
{{- define "netbird.pat.ownerEmail" -}}
{{- if .Values.pat.owner.email -}}
{{ .Values.pat.owner.email }}
{{- else -}}
admin@crczp
{{- end -}}
{{- end -}}

{{/*
Pod spec shared by the bootstrap Job and the rotation CronJob.
The same script bootstraps the first owner+PAT when none exists, otherwise it
mints a fresh PAT and revokes the previous one.
Takes (dict "root" $ "bootstrap" true|false); only the bootstrap Job applies
account settings, so a dashboard change survives until the next upgrade.
*/}}
{{- define "netbird.pat.podSpec" -}}
{{- $bootstrap := .bootstrap -}}
{{- with .root -}}
serviceAccountName: {{ .Values.pat.serviceAccountName }}
restartPolicy: Never
{{- with .Values.pat.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: rotate
    image: {{ .Values.pat.image | quote }}
    command: ["/bin/sh", "-c", "apk add --no-cache curl jq >/dev/null 2>&1 && exec sh /scripts/netbird-rotate-pat.sh"]
    env:
      - name: NB_API_URL
        value: http://{{ .Values.server.name }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.server.port }}
      - name: PAT_SECRET_NAME
        value: {{ .Values.pat.secretName | quote }}
      - name: POD_NAMESPACE
        value: {{ include "netbird.pat.secretNamespace" . | quote }}
      - name: OWNER_EMAIL
        value: {{ include "netbird.pat.ownerEmail" . | quote }}
      - name: OWNER_NAME
        value: {{ .Values.pat.owner.name | quote }}
      - name: OWNER_PASSWORD
        value: {{ .Values.pat.owner.password | quote }}
      - name: PAT_TOKEN_NAME
        value: {{ .Values.pat.tokenName | quote }}
      - name: PAT_EXPIRE_DAYS
        value: {{ .Values.pat.expireDays | quote }}
      # Server Deployment to roll after the one-time bootstrap so the
      # single-account-anchor init container re-runs against the new account.
      - name: SERVER_DEPLOYMENT
        value: {{ .Values.server.name | quote }}
      - name: SERVER_NAMESPACE
        value: {{ .Release.Namespace | quote }}
      {{- if and $bootstrap .Values.networkRange }}
      - name: NETWORK_RANGE
        value: {{ .Values.networkRange | quote }}
      {{- end }}
    volumeMounts:
      - name: script
        mountPath: /scripts
volumes:
  - name: script
    configMap:
      name: {{ include "netbird.pat.name" . }}
{{- end -}}
{{- end -}}
