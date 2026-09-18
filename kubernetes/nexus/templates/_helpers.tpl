{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of this wrapper chart.
*/}}
{{- define "nexus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Release-scoped fully qualified name for objects THIS wrapper owns — the two
ConfigMaps and the provisioning Job. Not the subchart's objects: those are
named by the subchart's own helpers, replicated below as nexus.nexus3Fullname.
Truncated at 63 chars because some Kubernetes name fields are limited to this
by the DNS naming spec.
*/}}
{{- define "nexus.fullname" -}}
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
Standard labels for this wrapper's own objects.

app.kubernetes.io/instance carries the release name verbatim: the live smoke
in scripts/nexus-live-smoke.sh selects the provisioning Job by that label, so
dropping or renaming it leaves KIND-JOB-COMPLETE waiting on an empty set.
*/}}
{{- define "nexus.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "nexus.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Faithful replica of the SUBCHART's `nexus3.fullname`, evaluated against the
parent's view of the subchart values.

WHY THIS EXISTS. The provisioning Job has to reach the Nexus Service, and the
subchart names that Service from `nexus3.fullname` (`nexus3.serviceName` is
defined as exactly that include). Both `fullnameOverride` and `nameOverride`
sit inside D-07's passthrough surface, so a consumer can move the Service with
`--set nexus3.nameOverride=...` and a hardcoded `<release>-nexus3` would then
address an object that does not exist — the Job would fail with a DNS error
after the install reported success.

The branch structure below is copied from nexus3/templates/_helpers.tpl in
charts/nexus3-5.26.0.tgz, substituting the parent's value paths and the
literal chart name `nexus3` for the subchart's `.Chart.Name`. If the pinned
subchart version changes, re-read that helper and re-check this replica.
*/}}
{{- define "nexus.nexus3Fullname" -}}
{{- if .Values.nexus3.fullnameOverride }}
{{- .Values.nexus3.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "nexus3" .Values.nexus3.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
