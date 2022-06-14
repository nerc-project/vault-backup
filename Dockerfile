# This Dockerfile uses a multi-stage build

# Builder Image
FROM python:3.9-slim-bullseye as builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential curl && \
    apt-get clean -y

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

RUN python3 -m venv /opt/venv

RUN curl -L \
  https://github.com/starkandwayne/safe/releases/download/v1.6.1/safe-linux-amd64 \
  -o /opt/venv/bin/safe && \
  chmod +x /opt/venv/bin/safe

COPY src/bin/vault-backup.sh /opt/venv/bin

# Final Image
FROM python:3.9-slim-bullseye

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      gpg dirmngr && \
    apt-get clean -y

COPY --from=builder --chown=1001:0 /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

USER 1001

CMD [ "vault-backup.sh" ]
