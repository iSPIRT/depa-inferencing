#!/bin/bash

# Load Docker image name from .config file
if [ -f .config ]; then
    DOCKER_IMAGE=$(grep '^KV_TOOLS_IMAGE=' .config | cut -d '=' -f2)
fi

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output_dir> <udf_file_path>"
    exit 1
fi

OUTPUT_DIR=$1
UDF_FILE_PATH=$2
UDF_DIR=$(dirname "$UDF_FILE_PATH")
# Run the Docker container with the provided arguments
docker run --rm \
  --volume="$OUTPUT_DIR:$OUTPUT_DIR" \
  --volume="$UDF_DIR:$UDF_DIR" \
  --user $(id -u ${USER}):$(id -g ${USER}) \
  --entrypoint=/tools/udf/udf_delta_file_generator \
  "$DOCKER_IMAGE" \
  --output_dir="$OUTPUT_DIR" \
  --udf_file_path="$UDF_FILE_PATH"
