#!/bin/bash
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

PERSISTENT_DIR="${PERSISTENT_DIR:-/data}"
SSH_USERNAME="${SSH_USERNAME:-dev}"
ALLOW_ROOT_LOGIN="${ALLOW_ROOT_LOGIN:-false}"
ALLOW_PASSWORD_AUTH="${ALLOW_PASSWORD_AUTH:-false}"
CF_USE_QUICK_TUNNEL="${CF_USE_QUICK_TUNNEL:-false}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
SSH_AUTHORIZED_KEYS="${SSH_AUTHORIZED_KEYS:-}"
SSH_PASSWORD="${SSH_PASSWORD:-}"
CF_TUNNEL_TOKEN="${CF_TUNNEL_TOKEN:-}"
CF_TUNNEL_HOSTNAME="${CF_TUNNEL_HOSTNAME:-}"
LOG_FILE="/tmp/cloudflared.log"

bool_is_true() {
    case "${1,,}" in
        true|1|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

require_ssh_auth() {
    if [ -n "$SSH_PUBLIC_KEY" ] || [ -n "$SSH_AUTHORIZED_KEYS" ]; then
        return 0
    fi

    if bool_is_true "$ALLOW_PASSWORD_AUTH" && [ -n "$SSH_PASSWORD" ]; then
        return 0
    fi

    fail "Set SSH_PUBLIC_KEY or SSH_AUTHORIZED_KEYS, or enable password auth with ALLOW_PASSWORD_AUTH=true and SSH_PASSWORD."
}

require_tunnel_config() {
    if [ -n "$CF_TUNNEL_TOKEN" ]; then
        return 0
    fi

    if bool_is_true "$CF_USE_QUICK_TUNNEL"; then
        return 0
    fi

    fail "Set CF_TUNNEL_TOKEN for a named Cloudflare tunnel, or explicitly allow CF_USE_QUICK_TUNNEL=true for dev usage."
}

setup_persistent_storage() {
    mkdir -p "$PERSISTENT_DIR/home" "$PERSISTENT_DIR/root" "$PERSISTENT_DIR/ssh"
}

setup_host_keys() {
    if compgen -G "$PERSISTENT_DIR/ssh/ssh_host_*_key" >/dev/null; then
        cp "$PERSISTENT_DIR"/ssh/ssh_host_* /etc/ssh/
    else
        ssh-keygen -A
        cp /etc/ssh/ssh_host_* "$PERSISTENT_DIR/ssh/"
    fi
}

ensure_user() {
    local user_home="$PERSISTENT_DIR/home/$SSH_USERNAME"

    if ! id -u "$SSH_USERNAME" >/dev/null 2>&1; then
        useradd -m -d "$user_home" -s /bin/bash -G sudo "$SSH_USERNAME"
    fi

    mkdir -p "$user_home/.ssh"
    chown -R "$SSH_USERNAME:$SSH_USERNAME" "$user_home"
    chmod 700 "$user_home/.ssh"

    if [ -n "$SSH_AUTHORIZED_KEYS" ]; then
        printf '%s\n' "$SSH_AUTHORIZED_KEYS" > "$user_home/.ssh/authorized_keys"
    elif [ -n "$SSH_PUBLIC_KEY" ]; then
        printf '%s\n' "$SSH_PUBLIC_KEY" > "$user_home/.ssh/authorized_keys"
    fi

    if [ -f "$user_home/.ssh/authorized_keys" ]; then
        chown "$SSH_USERNAME:$SSH_USERNAME" "$user_home/.ssh/authorized_keys"
        chmod 600 "$user_home/.ssh/authorized_keys"
    fi

    if [ -n "$SSH_PASSWORD" ]; then
        echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd
    fi
}

write_sshd_config() {
    local permit_root="no"
    local password_auth="no"

    if bool_is_true "$ALLOW_ROOT_LOGIN"; then
        permit_root="yes"
    fi

    if bool_is_true "$ALLOW_PASSWORD_AUTH"; then
        password_auth="yes"
    fi

    cat > /etc/ssh/sshd_config <<EOF
Port 22
PermitRootLogin $permit_root
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication $password_auth
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 0
AllowTcpForwarding no
PermitTTY yes
AllowUsers $SSH_USERNAME
EOF
}

start_sshd() {
    /usr/sbin/sshd
}

print_summary() {
    echo "=========================================================="
    echo "SSH server ready"
    echo "User: $SSH_USERNAME"
    echo "Persistent data: $PERSISTENT_DIR"

    if [ -n "$CF_TUNNEL_HOSTNAME" ]; then
        echo "Hostname: $CF_TUNNEL_HOSTNAME"
        echo "SSH command: ssh -i ~/.ssh/your_key $SSH_USERNAME@$CF_TUNNEL_HOSTNAME -o ProxyCommand=\"cloudflared access ssh --hostname %h\" -o IdentitiesOnly=yes"
    elif bool_is_true "$CF_USE_QUICK_TUNNEL"; then
        local url=""
        url=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" "$LOG_FILE" | head -n1 | sed 's#https://##' || true)
        if [ -n "$url" ]; then
            echo "Hostname: $url"
            echo "SSH command: ssh -i ~/.ssh/your_key $SSH_USERNAME@$url -o ProxyCommand=\"cloudflared access ssh --hostname %h\" -o IdentitiesOnly=yes"
        fi
    else
        echo "Hostname: use the hostname configured on your Cloudflare named tunnel"
    fi

    echo "=========================================================="
}

start_cloudflared() {
    rm -f "$LOG_FILE"

    if [ -n "$CF_TUNNEL_TOKEN" ]; then
        cloudflared tunnel run --token "$CF_TUNNEL_TOKEN" > "$LOG_FILE" 2>&1 &
    else
        cloudflared tunnel --url ssh://localhost:22 > "$LOG_FILE" 2>&1 &
    fi
    sleep 8

    # ====================== OPENCLAW AUTO START ======================
    if su - "$SSH_USERNAME" -c 'export PATH="/data/home/dev/.npm-global/bin:$PATH"; command -v openclaw >/dev/null 2>&1'; then
        echo "Starting OpenClaw gateway automatically..."
        su - "$SSH_USERNAME" -c '
            export PATH="/data/home/dev/.npm-global/bin:$PATH"
            openclaw gateway --port 18789 --force
        ' > /data/openclaw.log 2>&1 &
    else
        echo "OpenClaw not found in PATH. Skipping automatic startup."
    fi
    # ================================================================

    print_summary
    exec tail -f "$LOG_FILE"
}

require_ssh_auth
require_tunnel_config
setup_persistent_storage
setup_host_keys
ensure_user
write_sshd_config
start_sshd
start_cloudflared
