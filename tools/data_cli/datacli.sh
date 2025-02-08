#!/bin/bash

# Usage function
usage() {
    echo "Usage:"
    echo "  $0 help"
    echo "  $0 format_delta <input_file_path> <output_file_path>"
    echo "  $0 snapshot <data_dir> <starting_file> <ending_file> <snapshot_file>"
    exit 1
}

# Validate input
if [ "$#" -lt 1 ]; then
    usage
fi

COMMAND=$1
IMAGE="ispirt.azurecr.io/depa-inferencing/tools/data_cli:latest"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

case "$COMMAND" in
    help)
        echo "Running data_cli --help..."
        docker run -it --rm \
            --entrypoint=/tools/data_cli/data_cli \
            "$IMAGE" \
            --help
        ;;

    format_delta)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        INPUT_FILE=$(realpath "$2")
        OUTPUT_FILE=$(realpath "$3")
        INPUT_DIR=$(dirname "$INPUT_FILE")
        OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

        echo "Running data_cli format_data..."
        docker run -it --rm \
            --volume="$INPUT_DIR":"$INPUT_DIR" \
            --volume="$OUTPUT_DIR":"$OUTPUT_DIR" \
            --user "$USER_ID":"$GROUP_ID" \
            --entrypoint=/tools/data_cli/data_cli \
            "$IMAGE" \
            format_data \
            --input_file="$INPUT_FILE" \
            --input_format=CSV \
            --output_file="$OUTPUT_FILE" \
            --output_format=DELTA
        ;;

    snapshot)
        if [ "$#" -ne 5 ]; then
            usage
        fi
        DATA_DIR=$(realpath "$2")
        STARTING_FILE="$3"
        ENDING_FILE="$4"
        SNAPSHOT_FILE="$5"

        echo "Running data_cli to generate snapshot file..."
        docker run -it --rm \
            --volume=/tmp:/tmp \
            --volume="$DATA_DIR":"$DATA_DIR" \
            --user "$USER_ID":"$GROUP_ID" \
            --entrypoint=/tools/data_cli/data_cli \
            "$IMAGE" \
            generate_snapshot \
            --data_dir="$DATA_DIR" \
            --working_dir=/tmp \
            --starting_file="$STARTING_FILE" \
            --ending_delta_file="$ENDING_FILE" \
            --snapshot_file="$SNAPSHOT_FILE" \
            --stderrthreshold=0 \
            --output_format=DELTA
        ;;

    *)
        usage
        ;;
esac
