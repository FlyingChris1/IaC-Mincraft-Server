#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

INVENTORY="inventory.ini"

echo "=================================="
echo " Minecraft Server Deployment"
echo "=================================="

echo "[1/3] Checking deployment user..."

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
    -e ansible_user=root \
    --ask-vault-pass
fi

echo "[2/3] Configuring server..."

ansible-playbook \
  -i "$INVENTORY" \
  site.yaml \
  -e ansible_user=deploy \
  --ask-become-pass

echo "[3/3] Verifying connection..."

ansible -i "$INVENTORY" minecraft \
  -m ansible.builtin.ping \
  -e ansible_user=deploy

echo "=================================="
echo " Deployment completed successfully"
echo "=================================="