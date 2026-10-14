# A Paketo-compatible *run image* built on Chainguard's minimal, CVE-patched JRE.
#
# Paketo stacks the application layers (JRE + your app) produced by the
# buildpacks on top of this image. We only need to make a Chainguard base
# satisfy the Cloud Native Buildpacks (CNB) run-image contract:
#   1. A matching stack id label.
#   2. A declared, non-root user.
FROM cgr.dev/chainguard/jre:latest

USER root

# The lifecycle requires the run image's stack id to match the builder's.
# paketobuildpacks/builder-jammy-base advertises "io.buildpacks.stacks.jammy".
LABEL io.buildpacks.stack.id="io.buildpacks.stacks.jammy"

# Advertise no extra mixins so the lifecycle's mixin check passes cleanly.
LABEL io.buildpacks.stack.mixins="[]"

# CNB forbids running as root. Chainguard's images ship a "nonroot" user
# (uid/gid 65532); re-declare it so the lifecycle sets layer ownership to it.
USER 65532:65532
