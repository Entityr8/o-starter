# Sử dụng hệ điều hành Ubuntu 22.04
FROM ubuntu:22.04

# Cập nhật hệ thống, cài đặt OpenSSH Server, sudo và wget
RUN apt-get update && \
    apt-get install -y openssh-server sudo wget iputils-ping && \
    mkdir -p /var/run/sshd

# Tải và cài đặt cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x cloudflared-linux-amd64 && \
    mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Đặt mật khẩu cho root là 123456 và cho phép SSH bằng root
RUN echo 'root:123456' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Copy file khởi động vào container
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Mở port 22 trong mạng nội bộ của container
EXPOSE 22

# Lệnh chạy khi container khởi động
CMD ["/start.sh"]