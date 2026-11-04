# Minecraft Server Infrastructure

A private Minecraft Java Edition server hosted on **Hetzner Cloud**, provisioned with **Terraform** and configured using **Ansible** and **Docker**.

The server uses SSH hardening, UFW, a Hetzner Cloud Firewall, and automatic security updates. Minecraft is accessible only through an SSH tunnel.

## Tech Stack

- **Terraform** – Infrastructure provisioning
- **Ansible** – Automated server configuration
- **Docker** – Minecraft server container
- **UFW & Hetzner Cloud Firewall** – Network security
- **SSH** – Secure administration and private Minecraft access

## Prerequisites

- Hetzner Cloud account and API token
- Terraform
- Ansible installed in WSL (Ubuntu)
- SSH key pair
- Minecraft Java Edition

## Deployment

### 1. Provision Infrastructure

Open **Git Bash** and navigate to `hetzner-terraform/`.

Set the Hetzner API token:

```bash
read -rsp "Hetzner API Token: " HCLOUD_TOKEN
echo
export HCLOUD_TOKEN
```

Deploy the infrastructure:

```bash
terraform init
terraform plan
terraform apply
```

Terraform creates the VM, configures the cloud firewall, and generates the Ansible inventory.

### 2. Configure the Server

Open **WSL (Ubuntu)** and navigate to `ansible-minecraft/`.

Install the required Ansible collections if necessary:

```bash
ansible-galaxy collection install community.docker community.general
```

Run the deployment script:

```bash
bash deploy.sh
```

The script automatically configures:

- Deployment user (`deploy`)
- SSH hardening
- Automatic security updates
- UFW firewall
- Docker and Minecraft

## Connect to Minecraft

Open **Git Bash** in the project root and start the SSH tunnel:

```bash
ssh -F minecraft-ssh.conf \
  -N \
  -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:25565:127.0.0.1:25565 \
  minecraft-server
```

This requires the generated SSH configuration to use the `deploy` account.

Keep the terminal open while playing.

In **Minecraft Java Edition**, connect to:

```text
localhost:25565
```

## Server Management

Connect to the VM as `deploy`.

```bash
# Container status
sudo docker ps

# Minecraft logs
sudo docker logs -f minecraft

# Restart Minecraft
sudo docker restart minecraft

# Resource usage
sudo docker stats --no-stream minecraft
```

## Destroy Infrastructure

Open **Git Bash** in `hetzner-terraform/`:

```bash
terraform destroy
```

**Warning:** Destroying the VM deletes locally stored Minecraft worlds. External backups are not yet automated.

## References

- [Terraform](https://developer.hashicorp.com/terraform/docs)
- [Ansible](https://docs.ansible.com/)
- [Hetzner Cloud](https://www.hetzner.com/cloud/)
- [Minecraft Docker Image](https://github.com/itzg/docker-minecraft-server)