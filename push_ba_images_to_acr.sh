#!/bin/bash
# Load Docker image tars from dist/azure, squash to single layer (required for
# Azure confidential container CCE policy compatibility), tag for ACR, and push.
# Prerequisites: az login, then run this script (it runs az acr login).
set -euo pipefail

BUILD_FLAVOR="${BUILD_FLAVOR:-prod}"
RELEASE_VERSION="${RELEASE_VERSION:-bazel-7-test}"
ACR_REGISTRY="${ACR_REGISTRY:-ispirt.azurecr.io}"
ACR_REPO_PREFIX="${ACR_REPO_PREFIX:-depainferencing/azure/test}"
DIST_DIR="${DIST_DIR:-./dist/azure}"

echo "Build flavor: $BUILD_FLAVOR"
echo "Release version: $RELEASE_VERSION"
echo "ACR: $ACR_REGISTRY"
echo ""

# Squash a multi-layer image into a single layer, preserving entrypoint/env/workdir.
squash_image() {
  local loaded_image="$1"
  local final_tag="$2"
  local temp_name="squash-temp-$$"

  echo "  Squashing $loaded_image -> $final_tag ..."
  docker create --name "$temp_name" "$loaded_image"
  docker export "$temp_name" -o "${temp_name}.tar"
  docker import "${temp_name}.tar" "${temp_name}-base:temp"

  local entrypoint_json workdir env_vars
  entrypoint_json=$(docker inspect "$loaded_image" --format '{{json .Config.Entrypoint}}')
  workdir=$(docker inspect "$loaded_image" --format '{{.Config.WorkingDir}}')
  env_vars=$(docker inspect "$loaded_image" --format '{{range .Config.Env}}ENV {{.}}{{"\n"}}{{end}}')

  local dockerfile="Dockerfile.${temp_name}"
  {
    echo "FROM ${temp_name}-base:temp"
    echo "$env_vars"
    echo "WORKDIR ${workdir:-/}"
    echo "ENTRYPOINT $entrypoint_json"
  } > "$dockerfile"

  docker build -f "$dockerfile" -t "$final_tag" .
  local layer_count
  layer_count=$(docker inspect "$final_tag" | python3 -c "import sys,json; print(len(json.load(sys.stdin)[0]['RootFS']['Layers']))")
  echo "  Squashed image has $layer_count layer(s)"

  docker rm "$temp_name"
  docker rmi "${temp_name}-base:temp" || true
  rm -f "${temp_name}.tar" "$dockerfile"
  docker rmi "$loaded_image" 2>/dev/null || true
}

# Login to ACR (uses existing az login)
echo "Logging into ACR..."
az acr login --name "${ACR_REGISTRY%%.*}"

# Bidding Service
BIDDING_TAR="${DIST_DIR}/bidding_service_image.tar"
BIDDING_ACR_TAG="${ACR_REGISTRY}/${ACR_REPO_PREFIX}/bidding-service:${BUILD_FLAVOR}-${RELEASE_VERSION}"
echo "Bidding Service: $BIDDING_ACR_TAG"
if [[ ! -f "$BIDDING_TAR" ]]; then
  echo "ERROR: $BIDDING_TAR not found. Build the image tarball first." >&2
  exit 1
fi
LOAD_OUTPUT=$(docker load -i "$BIDDING_TAR")
LOADED_IMAGE=$(echo "$LOAD_OUTPUT" | grep "Loaded image:" | sed 's/Loaded image: //')
echo "  Loaded image: $LOADED_IMAGE"
squash_image "$LOADED_IMAGE" "$BIDDING_ACR_TAG"
docker push "$BIDDING_ACR_TAG"
echo ""

# Buyer Frontend Service
BUYER_TAR="${DIST_DIR}/buyer_frontend_service_image.tar"
BUYER_ACR_TAG="${ACR_REGISTRY}/${ACR_REPO_PREFIX}/buyer-frontend-service:${BUILD_FLAVOR}-${RELEASE_VERSION}"
echo "Buyer Frontend Service: $BUYER_ACR_TAG"
if [[ ! -f "$BUYER_TAR" ]]; then
  echo "ERROR: $BUYER_TAR not found. Build the image tarball first." >&2
  exit 1
fi
LOAD_OUTPUT=$(docker load -i "$BUYER_TAR")
LOADED_IMAGE=$(echo "$LOAD_OUTPUT" | grep "Loaded image:" | sed 's/Loaded image: //')
echo "  Loaded image: $LOADED_IMAGE"
squash_image "$LOADED_IMAGE" "$BUYER_ACR_TAG"
docker push "$BUYER_ACR_TAG"
echo ""

echo "Done. Pushed (squashed):"
echo "  $BIDDING_ACR_TAG"
echo "  $BUYER_ACR_TAG"
