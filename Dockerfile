FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y openssh-server sudo wget iputils-ping && \
    mkdir -p /var/run/sshd

RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x cloudflared-linux-amd64 && \
    mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

RUN echo 'root:123456' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 22

CMD ["/start.sh"]