#!/usr/bin/env bash
# olenellus.sh  — secure‑bootstrap with staged password shutdown
#
# Usage: sudo ./olenellus.sh alice 111
#   <new_user>   : mandatory user name
#   [port]       : optional SSH port (default 111)

set -euo pipefail

############################################################
# 0. Sanity checks
############################################################
(( EUID == 0 )) || { echo "Run as root." >&2; exit 1; }

NEW_USER="$1"
SSH_PORT="${2:-111}"
SERVER_IP=$(hostname -I | awk '{print $1}')

############################################################
# 1. Packages
############################################################
echo "==> Updating and upgrading system"
apt update -qq
DEBIAN_FRONTEND=noninteractive apt -y upgrade

############################################################
# 2. Create user and set password interactively
############################################################
if id "$NEW_USER" &>/dev/null; then
  echo "User $NEW_USER already exists — skipping adduser."
else
  echo "==> Creating user $NEW_USER"
  adduser --gecos "" "$NEW_USER"
fi

echo "==> Set a *temporary* password for $NEW_USER (will be disabled later)"
passwd "$NEW_USER"

echo "==> Granting sudo privileges"
usermod -aG sudo "$NEW_USER"

############################################################
# 3. SSH key directory (optional but convenient)
############################################################
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"

############################################################
# 4. SSH configuration — idempotent, no duplicates
############################################################
CUSTOM_CFG="/etc/ssh/sshd_config.d/99-olenellus.conf"
TMP_PWD_CFG="/etc/ssh/sshd_config.d/20-${NEW_USER}-password.conf"

echo "==> Writing main hardening file   ($CUSTOM_CFG)"
cat > "$CUSTOM_CFG" <<EOF
# Installed by olenellus.sh
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
EOF

echo "==> Writing temporary Match block ($TMP_PWD_CFG)"
cat > "$TMP_PWD_CFG" <<EOF
# Temporary: allow $NEW_USER to push their public key
Match User $NEW_USER
    PasswordAuthentication yes
EOF

############################################################
# 5. Disable socket activation to honour Port directive
############################################################
if systemctl is-active --quiet ssh.socket; then
  echo "==> Disabling systemd socket activation"
  systemctl disable --now ssh.socket
fi

############################################################
# 6. Syntax‑check & restart
############################################################
echo "==> Validating SSH configuration"
sshd -t

echo "==> Restarting ssh.service"
systemctl restart ssh.service
systemctl is-active --quiet ssh && echo "   ↳ sshd restarted OK"

############################################################
# 7. Guide the administrator through ssh-copy-id
############################################################
cat <<EOT

#################################################################
 PHASE 1: copy your key FROM YOUR LAPTOP / WORKSTATION
#################################################################

Run on your local machine:

   ssh-copy-id -p $SSH_PORT $NEW_USER@$SERVER_IP

Log in once to verify key‑only access:

   ssh -p $SSH_PORT $NEW_USER@$SERVER_IP

#################################################################
 Press ENTER here *after* key login works.
 (This will lock password auth for $NEW_USER.)
#################################################################
EOT
read -r

############################################################
# 8. Remove password & temp Match block, harden permanently
############################################################
echo "==> Disabling password for $NEW_USER"
passwd -d "$NEW_USER"

echo "==> Removing temporary Match block"
rm -f "$TMP_PWD_CFG"

echo "==> Final SSH syntax check & restart"
sshd -t
systemctl restart ssh.service
systemctl is-active --quiet ssh && echo "   ↳ sshd restarted OK"

echo "==> Done. Password authentication is now disabled."