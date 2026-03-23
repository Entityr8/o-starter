#!/bin/bash

/usr/sbin/sshd

echo "🚀 SSH Server started locally on port 22..."
echo "Setting up Cloudflare tunnel..."

nohup cloudflared tunnel --url ssh://localhost:22 > /tmp/cloudflared.log 2>&1 &

sleep 10

if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
    URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1 | sed 's/https:\/\///')
    
    echo "=========================================================="
    echo " 🚀 RAILWAY SERVER IS READY!"
    echo " 🌐 Hostname: $URL"
    echo " 🔑 Password: 123456"
    echo ""
    echo " 💻 Connection command:"
    echo " ssh root@$URL -o ProxyCommand=\"cloudflared access ssh --hostname %h\" -o StrictHostKeyChecking=no"
    echo "=========================================================="
else
    echo "❌ Cloudflare connection error (might be blocked), detailed log:"
    cat /tmp/cloudflared.log
fi

tail -f /tmp/cloudflared.log