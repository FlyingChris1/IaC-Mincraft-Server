
#!/usr/bin/env bash

set -euo pipefail

# Always run from the script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

INVENTORY="inventory.ini"

echo "=================================="
echo " Minecraft Server Deployment"
echo "=================================="

# Check requirements
command -v ansible >/dev/null || {
  echo "ERROR: Ansible is not installed."
  exit 1
}

test -f "$INVENTORY" || {
  echo "ERROR: inventory.ini not found."
  exit 1
}

# Step 1: Bootstrap if necessary
echo "[1/4] Checking deployment user..."

if ansible -i "$INVENTORY" minecraft \
  -m ansible.builtin.ping \
  -e ansible_user=deploy >/dev/null 2>&1
then
  echo "Deployment user already exists."
else
  echo "Bootstrapping server as root..."

  ansible-playbook \
    -i "$INVENTORY" \
    bootstrap.yaml \
    -e ansible_user=root
fi

# Step 2: Verify sudo permissions
echo "[2/4] Verifying sudo access..."

ansible -i "$INVENTORY" minecraft \
  -b \
  -m ansible.builtin.command \
  -a "whoami" \
  -e ansible_user=deploy

# Step 3: Apply security and Minecraft setup
echo "[3/4] Configuring server..."

ansible-playbook \
  -i "$INVENTORY" \
  site.yaml \
  -e ansible_user=deploy

# Step 4: Verify Minecraft container
echo "[4/4] Checking Minecraft container..."

ansible -i "$INVENTORY" minecraft \
  -b \
  -m ansible.builtin.command \
  -a "docker ps --filter name=^/minecraft$" \
  -e ansible_user=deploy

echo "=================================="
echo " Deployment completed successfully"
echo "=================================="
