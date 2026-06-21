#!/usr/bin/env bash
set -euo pipefail

export LD_LIBRARY_PATH="$(
  python -c "import os, secure_request_client; print(os.path.join(os.path.dirname(secure_request_client.__file__), 'lib'))"
):${LD_LIBRARY_PATH:-}"

exec python /secure_invoke/invoke.py "$@"
