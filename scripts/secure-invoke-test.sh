#!/bin/bash

set -e

export REPO_ROOT=$(realpath $(dirname "${BASH_SOURCE[0]}")/..)

docker compose -f $REPO_ROOT/docker-compose.yml up secure-invoke "$@"
