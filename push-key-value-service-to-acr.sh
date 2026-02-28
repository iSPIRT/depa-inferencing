#!/usr/bin/env bash
set -euo pipefail

BUILD_FLAVOR="${BUILD_FLAVOR:-prod}"
RELEASE_VERSION="${RELEASE_VERSION:-bazel-7-test}"

KV_SERVICE_IMAGE="key-value-service:${BUILD_FLAVOR}-${RELEASE_VERSION}"
echo "key_value_service_image=$KV_SERVICE_IMAGE"

LOAD_OUTPUT=$(docker load -i ./dist/key_value_service_image.tar)
LOADED_IMAGE=$(echo "$LOAD_OUTPUT" | grep "Loaded image:" | sed 's/Loaded image: //')
echo "Loaded image: $LOADED_IMAGE"

docker create --name kv-squash-temp $LOADED_IMAGE
docker export kv-squash-temp -o kv-squashed.tar
SQUASHED_BASE=$(docker import kv-squashed.tar kv-squashed-base:temp)
echo "Created squashed base image: $SQUASHED_BASE"

# step 4: extract original image metadata
ENTRYPOINT_JSON=$(docker inspect $LOADED_IMAGE --format '{{json .Config.Entrypoint}}')
ENV_VARS=$(docker inspect $LOADED_IMAGE --format '{{range .Config.Env}}ENV {{.}}{{"\n"}}{{end}}')
WORKDIR=$(docker inspect $LOADED_IMAGE --format '{{.Config.WorkingDir}}')
echo "Original ENTRYPOINT: $ENTRYPOINT_JSON"
echo "Original ENV vars: $ENV_VARS"

# step 5: create Dockerfile to restore metadata
echo "FROM kv-squashed-base:temp" > Dockerfile.squashed
echo "$ENV_VARS" >> Dockerfile.squashed
echo "WORKDIR ${WORKDIR:-/}" >> Dockerfile.squashed
echo "ENTRYPOINT $ENTRYPOINT_JSON" >> Dockerfile.squashed
echo "Generated Dockerfile.squashed:"
cat Dockerfile.squashed

docker build -f Dockerfile.squashed -t kv-squashed-final:temp .
LAYER_COUNT=$(docker inspect kv-squashed-final:temp | jq '.[0].RootFS.Layers | length')
echo "Squashed image has $LAYER_COUNT layers"

docker rm kv-squash-temp
docker rmi kv-squashed-base:temp || true
rm -f kv-squashed.tar Dockerfile.squashed
FINAL_IMAGE="kv-squashed-final:temp"

docker tag $FINAL_IMAGE ispirt.azurecr.io/depainferencing/azure/test/key-value-service:${BUILD_FLAVOR}-${RELEASE_VERSION}
docker push ispirt.azurecr.io/depainferencing/azure/test/key-value-service:${BUILD_FLAVOR}-${RELEASE_VERSION}

docker rmi $FINAL_IMAGE
docker rmi $LOADED_IMAGE

echo "Done. Pushed ispirt.azurecr.io/depainferencing/azure/test/key-value-service:${BUILD_FLAVOR}-${RELEASE_VERSION}"
