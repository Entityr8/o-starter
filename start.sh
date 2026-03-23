#!/bin/bash

# 1. Khởi động SSH Server ngầm
/usr/sbin/sshd

echo "🚀 SSH Server đã khởi động cục bộ trên cổng 22..."
echo "Đang thiết lập đường hầm Cloudflare..."

# 2. Khởi chạy Cloudflare Quick Tunnel và lưu log
nohup cloudflared tunnel --url ssh://localhost:22 > /tmp/cloudflared.log 2>&1 &

# Đợi 10 giây để Cloudflare cấp URL
sleep 10

# 3. Trích xuất và in thông tin kết nối ra Log của Railway
if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
    URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1 | sed 's/https:\/\///')
    
    echo "=========================================================="
    echo " 🚀 MÁY CHỦ RAILWAY ĐÃ SẴN SÀNG!"
    echo " 🌐 Hostname: $URL"
    echo " 🔑 Mật khẩu: 123456"
    echo ""
    echo " 💻 Lệnh kết nối:"
    echo " ssh root@$URL -o ProxyCommand=\"cloudflared access ssh --hostname %h\" -o StrictHostKeyChecking=no"
    echo "=========================================================="
else
    echo "❌ Lỗi kết nối Cloudflare (có thể bị chặn), log chi tiết:"
    cat /tmp/cloudflared.log
fi

# 4. Giữ cho container sống liên tục bằng cách đọc log
tail -f /tmp/cloudflared.log