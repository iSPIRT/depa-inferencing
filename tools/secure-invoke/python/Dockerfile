FROM python:3.10-slim-bookworm

ARG SECURE_REQUEST_WHEEL_URL=https://github.com/saranggalada/bidding-auction-servers/releases/download/v0.1.0/secure_request-0.1.0-py3-none-any.whl

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /secure_invoke

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir "${SECURE_REQUEST_WHEEL_URL}"

COPY invoke.py entrypoint.sh ./
RUN chmod +x /secure_invoke/entrypoint.sh

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/secure_invoke/entrypoint.sh"]
