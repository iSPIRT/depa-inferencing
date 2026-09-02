#!/usr/bin/env bash
# Regenerate the gRPC stubs from secure_invoke_envelope.proto.
#
# We deliberately pin an older grpcio-tools (protobuf 4.25 era) so the generated
# code has no hard "protobuf runtime >= 5.x" guard and works with both
# protobuf 4.x and 5.x clients. After generation the absolute import in the
# *_pb2_grpc.py file is rewritten to a package-relative import.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO_DIR="${HERE}/../src/depa_secure_invoke/proto"

python -m pip install --quiet "grpcio-tools==1.62.3"
python -m grpc_tools.protoc \
  -I "${PROTO_DIR}" \
  --python_out="${PROTO_DIR}" \
  --grpc_python_out="${PROTO_DIR}" \
  "${PROTO_DIR}/secure_invoke_envelope.proto"

# Make the generated grpc module import its pb2 sibling relatively.
sed -i \
  's/^import secure_invoke_envelope_pb2 /from . import secure_invoke_envelope_pb2 /' \
  "${PROTO_DIR}/secure_invoke_envelope_pb2_grpc.py"

echo "Regenerated stubs in ${PROTO_DIR}"
