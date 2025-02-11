#!/bin/bash

# Load Docker image name from .config file
if [ -f .config ]; then
    DOCKER_IMAGE=$(grep '^kv_service_tools=' .config | cut -d '=' -f2)
fi

# Check if correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <kv_delta_file_path> <udf_delta_file_path> <input_arguments>"
    exit 1
fi

KV_DELTA_FILE_PATH=$1
UDF_DELTA_FILE_PATH=$2
INPUT_ARGUMENTS=$3

# Run the Docker container with the provided arguments
docker run -it --rm \
  --volume="$(dirname "$KV_DELTA_FILE_PATH")":"$(dirname "$KV_DELTA_FILE_PATH")" \
  --volume="$(dirname "$UDF_DELTA_FILE_PATH")":"$(dirname "$UDF_DELTA_FILE_PATH")" \
  --user $(id -u ${USER}):$(id -g ${USER}) \
  --entrypoint=/tools/udf/udf_delta_file_tester \
  "$DOCKER_IMAGE" \
  --kv_delta_file_path="$KV_DELTA_FILE_PATH" \
  --udf_delta_file_path="$UDF_DELTA_FILE_PATH" \
  --input_arguments="$INPUT_ARGUMENTS"
