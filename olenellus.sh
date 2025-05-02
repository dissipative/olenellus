#!/usr/bin/env bash
# olenellus.sh
# Usage:   ./olenellus.sh <new_username> [ssh_port]
# Example: ./olenellus.sh alice 111
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "Run me as root." >&2
  exit 1
fi

NEW_USER="$1"
SSH_PORT="${2:-111}"

echo "==> Updating packages"
apt update -qq
DEBIAN_FRONTEND=noninteractive apt -y upgrade

echo "==> Creating user $NEW_USER"
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"

echo "==> Preparing SSH keys directory"
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
if [[ -f /root/.ssh/authorized_keys ]]; then
  cp /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/"
  chown "$NEW_USER":"$NEW_USER" "/home/$NEW_USER/.ssh/authorized_keys"
  chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
fi

echo "==> Hardening sshd_config"
sshd_cfg=/etc/ssh/sshd_config
cp "$sshd_cfg" "${sshd_cfg}.bak.$(date +%F_%T)"

apply() {
  sed -Ei "s/^#?\s*$1.*/$1 $2/" "$sshd_cfg"
}
apply Port "$SSH_PORT"
apply PermitRootLogin no
apply PasswordAuthentication no

echo "==> Restarting SSH daemon"
systemctl restart sshd

cat <<EOF

=== FINAL STEPS (run **from your laptop/workstation**) ===
1. Generate an SSH key if you haven’t:
   \$ ssh-keygen -t ed25519 -C "$USER@$(hostname)"

2. Copy the key to the server:
   \$ ssh-copy-id -p $SSH_PORT $NEW_USER@<server‑ip>

3. (Optional) Add a convenient alias in ~/.ssh/config:

Host myserver
    HostName <server‑ip>
    User $NEW_USER
    Port $SSH_PORT

You can now log in with:
   \$ ssh myserver
EOF
