#!/bin/bash
# Install the public key(s) passed in AUTHORIZED_KEYS for $USERNAME, then run sshd
set -e
ssh_dir=$(getent passwd "$USERNAME" | cut -d: -f6)/.ssh
mkdir -p "$ssh_dir"
printf '%s\n' "$AUTHORIZED_KEYS" > "$ssh_dir/authorized_keys"
chmod 700 "$ssh_dir" && chmod 600 "$ssh_dir/authorized_keys"
chown -R "$USERNAME:" "$ssh_dir"
rm -f /run/nologin /var/run/nologin  # no systemd to remove it, would block non-root logins
exec /usr/sbin/sshd -D -e
