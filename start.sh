#!/bin/bash

/usr/sbin/sshd

echo "🚀 SSH Server started locally on port 22..."
echo "Setting up Cloudflare tunnel..."

nohup cloudflared tunnel --url ssh://localhost:22 > /tmp/cloudflared.log 2>&1 &

sleep 10

if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
    URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1 | sed 's/https:\/\///')
    
    echo "=========================================================="
    echo " 🚀 RAILWAY / ANY PROVIDER SERVER IS READY!"
    echo " 🌐 Hostname: $URL"
    echo " 🔑 Password: 123456"
    echo ""
    echo " 💻 Connection command:"
    echo " ssh root@$URL -o ProxyCommand=\"cloudflared access ssh --hostname %h\" -o StrictHostKeyChecking=no"
    echo ""
    echo " 💾 PERSISTENT STORAGE:"
    echo "    → Data is saved in: $PERSISTENT_DIR"
    echo "    → Will not be lost upon container restart/redeploy/shutdown"
    echo "    → If using Cloud Shell or bare-metal VPS, use ~/persistent instead of /data"
    echo "=========================================================="
else
    echo "❌ Cloudflare connection error (might be blocked), detailed log:"
    cat /tmp/cloudflared.log
fi

# Create persistent directory (automatically based on env variable)
mkdir -p "$PERSISTENT_DIR"

# Create a README guide file (only creates once)
if [ ! -f "$PERSISTENT_DIR/README.txt" ]; then
    cat > "$PERSISTENT_DIR/README.txt" << EOF
=== PERSISTENT STORAGE - DATA WILL NOT BE LOST ===

All data you put in this directory:
$PERSISTENT_DIR

will be kept permanently across platforms (Railway, Render, Fly.io, VPS, ...).

Usage example:
cd $PERSISTENT_DIR
mkdir my_project
echo "Hello persistent world" > my_project/test.txt

Happy coding!
EOF
fi

echo "📁 Persistent directory is ready: $PERSISTENT_DIR"

tail -f /tmp/cloudflared.log