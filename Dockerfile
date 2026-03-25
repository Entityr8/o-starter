FROM ubuntu:24.04

SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server sudo wget ca-certificates procps iputils-ping \
        bash dash curl git && \
    mkdir -p /var/run/sshd /etc/ssh /data && \
    ln -sf /usr/bin/dash /bin/sh && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x cloudflared-linux-amd64 && \
    mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

ENV PERSISTENT_DIR=/data
ENV SSH_USERNAME=dev
ENV ALLOW_ROOT_LOGIN=false
ENV ALLOW_PASSWORD_AUTH=false
ENV CF_USE_QUICK_TUNNEL=false

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 22

ENTRYPOINT ["/bin/bash", "/start.sh"]
