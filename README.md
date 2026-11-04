# Minecraft Server Infrastructure

A private Minecraft Java Edition server hosted on **Hetzner Cloud**, provisioned with **Terraform** and configured using **Ansible** and **Docker**.

The server uses SSH hardening, UFW, Fail2ban, automatic security updates, and Docker security restrictions. Minecraft is accessible exclusively through an encrypted SSH tunnel.

## Tech Stack

| Technology | Purpose |
|---|---|
| Terraform | Infrastructure provisioning |
| Ansible | Automated server configuration |
| Docker | Minecraft server container |
| Hetzner Cloud | Virtual machine hosting |
| UFW & Hetzner Firewall | Network security |
| Fail2ban | SSH brute-force protection |
| Ansible Vault | Encrypted password configuration |
| SSH | Secure administration and port forwarding |

## Project Structure

```text
MC-Server/
├── README.md
├── hetzner-terraform/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── server.tf
│   ├── firewall.tf
│   ├── ssh.tf
│   ├── inventory.tf
│   └── outputs.tf
└── ansible-minecraft/
    ├── inventory.ini
    ├── bootstrap.yaml
    ├── ssh-hardening.yaml
    ├── ssh-crypto-hardening.yaml
    ├── security-updates.yaml
    ├── firewall.yaml
    ├── fail2ban.yaml
    ├── sudo-password.yaml
    ├── playbook.yaml
    ├── site.yaml
    ├── deploy.sh
    └── vars/
        └── deploy-vault.yaml
```

## Deployment

### 1. Provision Infrastructure

Open **Git Bash** in `hetzner-terraform/`.

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

Terraform provisions the Ubuntu VM, configures the Hetzner Cloud Firewall, and generates the Ansible inventory.

### 2. Configure the Server

Open **WSL (Ubuntu)** in `ansible-minecraft/`.

Run:

```bash
bash deploy.sh
```

The deployment automates:

- Deployment user configuration
- SSH hardening
- Automatic security updates
- UFW firewall
- Fail2ban
- Docker and Minecraft

Ansible requests the `deploy` sudo password when required. Initial provisioning may also require the Ansible Vault password.

The playbooks are designed to be **idempotent**, meaning existing configurations are preserved unless changes are necessary.

## Security

### SSH Hardening

SSH operates on **port `2222`** with the following restrictions:

- Root SSH login disabled
- Password authentication disabled
- Public key authentication enabled
- Administrative access through `deploy`
- Sudo password required for privileged commands

SSH cryptographic hardening is managed through `ssh-crypto-hardening.yaml`, which restricts key exchange algorithms, host key algorithms, and MACs when applied.

### Firewall & Fail2ban

**UFW** blocks incoming traffic by default and allows SSH on port `2222`.

The **Hetzner Cloud Firewall** provides an additional network security layer.

**Fail2ban** monitors SSH authentication failures and temporarily blocks suspicious IP addresses using UFW.

Configured Fail2ban policy:

| Setting | Value |
|---|---|
| Protected service | SSH |
| Port | 2222 |
| Maximum failed attempts | 5 |
| Detection window | 10 minutes |
| Ban duration | 1 hour |

### Docker Hardening

The Minecraft container uses additional security restrictions:

| Setting | Configuration |
|---|---|
| Privileged mode | Disabled |
| Privilege escalation | Restricted |
| `NET_RAW` capability | Dropped |
| Memory limit | 3 GB |
| CPU limit | 1.5 CPUs |
| Process limit | 512 |
| Minecraft port | `127.0.0.1:25565` |
| World data | `/opt/minecraft/data` |

The Minecraft port is not publicly exposed.

### Supply Chain Security

The Minecraft Docker image uses the fixed release:

```text
itzg/minecraft-server:2026.10.1-java25
```

For immutable image pinning, the following SHA-256 digest was recorded:

```text
sha256:d12aed7e35981dfe259b60fbfee77d23a19b5898a7a31dca298d18b47b7b5776
```

The corresponding Ansible image reference is:

```yaml
image: "itzg/minecraft-server@sha256:d12aed7e35981dfe259b60fbfee77d23a19b5898a7a31dca298d18b47b7b5776"
```

Digest pinning prevents an image from being silently replaced under the same version tag. It does not independently verify the image publisher or guarantee that the original image is free of vulnerabilities.

## Connect to the Server

Open **WSL (Ubuntu)**:

```bash
ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@SERVER_IP
```

Administrative commands require the Linux password of `deploy`:

```bash
sudo docker ps
```

## Connect to Minecraft

Open **Git Bash** or WSL and establish an SSH tunnel:

```bash
ssh -N \
  -p 2222 \
  -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:25565:127.0.0.1:25565 \
  -i ~/.ssh/id_ed25519 \
  deploy@SERVER_IP
```

Keep the terminal open while playing.

In **Minecraft Java Edition**, connect to:

```text
localhost:25565
```

## Server Management

Run these commands on the Hetzner VM:

```bash
sudo docker ps
sudo docker logs -f minecraft
sudo docker restart minecraft
sudo docker stats --no-stream minecraft
```

Verify security settings:

```bash
sudo ufw status verbose
sudo fail2ban-client status sshd
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication) '
```

Apply configuration changes from WSL:

```bash
bash deploy.sh
```

Run an individual Ansible playbook:

```bash
ansible-playbook -i inventory.ini fail2ban.yaml \
  -e ansible_port=2222 \
  -K
```

## Destroy Infrastructure

Open **Git Bash** in `hetzner-terraform/`:

```bash
terraform destroy
```

**Warning:** Minecraft world data is stored under `/opt/minecraft/data` on the VM. Destroying the VM deletes this data unless it has been backed up externally.

Automated external backups are not currently configured.

## Security Notes

Never commit Terraform state files, API tokens, SSH private keys, or plaintext passwords to Git.

The encrypted Ansible Vault file contains the password hash for `deploy`. Keep the Vault password secure.

When changing SSH settings, ensure that Terraform, Ansible, UFW, and the Hetzner Cloud Firewall use the same SSH port.

## References

- [Hetzner Cloud](https://www.hetzner.com/cloud/)
- [Terraform](https://developer.hashicorp.com/terraform/docs)
- [Ansible](https://docs.ansible.com/)
- [Docker](https://docs.docker.com/)
- [Minecraft Docker Image](https://github.com/itzg/docker-minecraft-server)
- [ssh-audit](https://www.sshaudit.com/)