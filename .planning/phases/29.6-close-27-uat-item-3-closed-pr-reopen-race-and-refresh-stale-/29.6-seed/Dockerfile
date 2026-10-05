# Phase 29.6 throwaway scan target (sp-reopen-race-scratch); not a fixture, delete with the repo (D-06).
# Deliberately has no USER and no HEALTHCHECK: Checkov candidate finding under blocking (RESEARCH A2, ASSUMED).
FROM public.ecr.aws/docker/library/alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
RUN echo ok > /ok.txt
CMD ["cat", "/ok.txt"]
