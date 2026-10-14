#!/usr/bin/env bash
# Make a Chainguard base usable as a Paketo run image WITHOUT a Dockerfile.
#
# `crane mutate` rewrites only the image config/manifest (to add the one CNB
# label Paketo's lifecycle checks) and reuses the original layers untouched.
# No `docker build`, no Dockerfile.
#
# Requires: crane (`brew install crane`, or run cgr.dev/chainguard/crane).
# cgr.dev/chainguard/jre already runs as the non-root "nonroot" user, so the
# only thing missing for the CNB run-image contract is the stack-id label.
set -euo pipefail

SRC="cgr.dev/chainguard/jre:latest"
TAG="hello-java-cg-run:latest"

# Option A — load straight into the local Docker daemon (fully local, no registry):
crane mutate "$SRC" \
  --label io.buildpacks.stack.id=io.buildpacks.stacks.jammy \
  --label io.buildpacks.stack.mixins='[]' \
  -t "$TAG" \
  -o /tmp/cg-run.tar
docker load < /tmp/cg-run.tar

# Option B — push to a registry you control instead (comment out Option A):
# crane mutate "$SRC" \
#   --label io.buildpacks.stack.id=io.buildpacks.stacks.jammy \
#   --label io.buildpacks.stack.mixins='[]' \
#   -t <your-registry>/hello-java-cg-run:latest

echo "Run image ready: $TAG"
