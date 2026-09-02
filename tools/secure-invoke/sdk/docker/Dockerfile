# Self-contained image with the DEPA secure-invoke SDK + CLI.
#
# Supports BOTH clouds out of the box:
#   * Azure (REST): pure-Python ctypes crypto (libsecure_invoke.so + libcddl.so).
#   * GCP  (gRPC):  the native `invoke` binary (different fork/crypto).
#
# The heavy binaries are NOT in git; they are pulled from the container registry
# (anonymous) as an OCI artifact via ORAS at build time.
#
# Build context must be the SDK root (tools/secure-invoke/sdk), e.g.:
#   docker build -f docker/Dockerfile -t depa/secure-invoke:1.0.0 .
#
# CLOUD selects which crypto backend(s) to bundle, keeping per-cloud images lean:
#   both  (default) -> Azure .so + GCP native binary
#   azure           -> Azure .so only (python/REST backend)
#   gcp             -> GCP native binary only (native/gRPC backend)
ARG SECURE_INVOKE_LIBS_REF=ispirt.azurecr.io/depainferencing/tools/secure_invoke_sdk_libs:1.0.0
ARG ORAS_VERSION=1.2.0
ARG CLOUD=both

# --- fetch stage: pull the crypto binaries from the registry ----------------
FROM python:3.10-slim-bookworm AS fetch
ARG SECURE_INVOKE_LIBS_REF
ARG ORAS_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSLo /tmp/oras.tar.gz \
        "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz" \
    && tar -xzf /tmp/oras.tar.gz -C /usr/local/bin oras \
    && rm /tmp/oras.tar.gz
WORKDIR /libs
RUN oras pull "${SECURE_INVOKE_LIBS_REF}" --output /libs

# --- runtime stage ----------------------------------------------------------
FROM python:3.10-slim-bookworm
ARG CLOUD

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Package sources (no heavy binaries in git), then overlay the fetched binaries.
COPY pyproject.toml ./
COPY src ./src
COPY --from=fetch /libs/depa_secure_invoke/lib/ /app/src/depa_secure_invoke/lib/
COPY --from=fetch /libs/depa_secure_invoke/native/ /app/src/depa_secure_invoke/native/

# Drop the other cloud's binaries so the image stays lean.
RUN case "${CLOUD:-both}" in \
      azure) rm -rf /app/src/depa_secure_invoke/native ;; \
      gcp)   rm -f /app/src/depa_secure_invoke/lib/*.so ;; \
      *)     : ;; \
    esac \
    && if [ -f /app/src/depa_secure_invoke/native/bin/invoke ]; then \
         chmod +x /app/src/depa_secure_invoke/native/bin/invoke; \
       fi \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir .

ENV PYTHONUNBUFFERED=1

# All configuration is passed as CLI flags; see `secure-invoke --help`.
ENTRYPOINT ["secure-invoke"]
CMD ["--help"]
