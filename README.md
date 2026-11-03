# IaC-Mincraft-Server

A private Minecraft Java Edition server hosted on **Hetzner Cloud**, provisioned with **Terraform**, configured using **Ansible**, and deployed with **Docker**.

The infrastructure is secured using **UFW** and **ufw-docker**. Minecraft is accessible through an encrypted **SSH tunnel**, keeping the game server port private instead of exposing it directly to the internet.

## Tech Stack

| Technology | Purpose |
|------------|---------|
| Hetzner Cloud | Cloud infrastructure provider |
| Terraform | Infrastructure provisioning |
| Ansible | Configuration management and automation |
| Docker | Containerized Minecraft server |
| Ubuntu | Server operating system |
| UFW | Host-based firewall |
| ufw-docker | Docker firewall integration |
| SSH | Secure remote access and port forwarding |
| WSL | Linux development environment on Windows |

## Architecture

```text
Windows PC
├── Visual Studio Code
├── Git Bash / WSL
├── Terraform
├── Ansible
└── Minecraft Java Client
         |
         | SSH Tunnel (TCP 22)
         |
         v
Hetzner Cloud
└── Ubuntu Virtual Machine
    ├── UFW Firewall
    │   ├── SSH (22) -> Allowed
    │   └── Other incoming traffic -> Denied
    │
    └── Docker
        └── Minecraft Server
            ├── 127.0.0.1:25565
            └── /opt/minecraft/data
```

## Project Structure

```text
MC-Server/
├── README.md
├── .gitignore
│
├── hetzner-terraform/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── ssh.tf
│   ├── server.tf
│   └── outputs.tf
│
└── ansible-minecraft/
    ├── ansible.cfg
    ├── inventory.ini
    ├── playbook.yaml
    └── firewall.yaml
```

The project separates infrastructure provisioning from application configuration:

- **Terraform** provisions the Hetzner Cloud virtual machine.
- **Ansible** configures Ubuntu and installs Docker.
- **Docker** runs the Minecraft server.
- **UFW** controls host-level network access.
- **ufw-docker** helps manage Docker network exposure.
- **SSH tunneling** provides private Minecraft access.

## Prerequisites

Before starting, make sure the following requirements are met:

- [Hetzner Cloud](https://console.hetzner.cloud/) account
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Ansible](https://docs.ansible.com/)
- [WSL with Ubuntu](https://learn.microsoft.com/en-us/windows/wsl/install)
- [Visual Studio Code](https://code.visualstudio.com/)
- SSH key pair
- Minecraft Java Edition

**Development environment:** Windows with Git Bash and Ubuntu running through WSL.

## 1. Infrastructure Provisioning

Terraform provisions an Ubuntu virtual machine on Hetzner Cloud.

### Configure the Hetzner API Token

Generate an API token with **Read & Write** permissions in the Hetzner Cloud Console.

Set the token securely in Git Bash:

```bash
read -rsp "Hetzner API Token: " HCLOUD_TOKEN
echo
export HCLOUD_TOKEN
```

The Hetzner Terraform provider automatically reads the `HCLOUD_TOKEN` environment variable.

The `provider.tf` file therefore does not require a hardcoded token:

```hcl
provider "hcloud" {}
```

> **Security:** Never commit API tokens, passwords, or private SSH keys to version control.

### Initialize Terraform

Navigate to the Terraform directory:

```bash
cd hetzner-terraform
```

Initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt
```

Validate the configuration:

```bash
terraform validate
```

Preview the infrastructure changes:

```bash
terraform plan
```

### Deploy the Virtual Machine

```bash
terraform apply
```

Review the proposed changes and confirm by entering `yes`.

Once Terraform finishes, retrieve the public IP address:

```bash
terraform output -raw server_ip
```

The virtual machine is now ready for configuration with Ansible.

> **Note:** Hetzner Cloud resources incur costs while provisioned. Destroy unused resources to avoid unnecessary charges.

## 2. Ansible Configuration

Ansible is used to configure the Ubuntu server and deploy Minecraft automatically.

### Install Ansible

Open Ubuntu through WSL from PowerShell:

```powershell
wsl -d Ubuntu
```

Inside WSL, install Ansible:

```bash
sudo apt update
sudo apt install -y ansible openssh-client
```

Verify the installation:

```bash
ansible --version
```

### Configure SSH Authentication

Ansible connects to the Hetzner server using SSH.

Generate a key pair if necessary:

```bash
ssh-keygen -t ed25519
```

The key pair contains:

```text
~/.ssh/id_ed25519       # Private key
~/.ssh/id_ed25519.pub   # Public key
```

Terraform registers the public key with Hetzner when creating the server.

If the SSH key was created on Windows, copy it into WSL:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

WIN_HOME="$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' | tr -d '\r')")"

cp "$WIN_HOME/.ssh/id_ed25519" ~/.ssh/id_ed25519

chmod 600 ~/.ssh/id_ed25519
```

This avoids hardcoding a Windows username in the path.

### Configure the Inventory

Create `inventory.ini`:

```ini
[minecraft]
mc1 ansible_host=YOUR_SERVER_IP ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

Replace `YOUR_SERVER_IP` with the public IP address provided by Terraform.

### Test the SSH Connection

From the Ansible project directory:

```bash
ansible -i inventory.ini minecraft -m ping
```

Expected result:

```text
mc1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

This confirms that Ansible can communicate with the remote server.

### Ansible Configuration

The `ansible.cfg` file contains the default configuration:

```ini
[defaults]
inventory = ./inventory.ini
interpreter_python = auto_silent
host_key_checking = True
```

For best compatibility, keep the Ansible project inside the WSL filesystem rather than under `/mnt/c/`.

Example:

```bash
mkdir -p ~/projects/MC-Server
```

This avoids the `world writable directory` warning that can cause Ansible to ignore the local configuration file.

## 3. Minecraft Deployment

Minecraft runs inside Docker using the [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) image.

Ansible automates the following tasks:

1. Install Docker.
2. Start and enable the Docker service.
3. Create the Minecraft data directory.
4. Deploy the Minecraft Docker container.
5. Configure automatic container restarts.

### Install Ansible Docker Collection

```bash
ansible-galaxy collection install community.docker
```

### Minecraft Playbook

Create `playbook.yaml`:

```yaml
---
- name: Minecraft Server Setup
  hosts: minecraft
  become: true

  vars:
    minecraft_data_dir: /opt/minecraft/data
    minecraft_memory: "2G"
    minecraft_port: 25565

  tasks:
    - name: Install Docker
      ansible.builtin.apt:
        name: docker.io
        state: present
        update_cache: true

    - name: Start Docker
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

    - name: Create Minecraft directory
      ansible.builtin.file:
        path: "{{ minecraft_data_dir }}"
        state: directory
        owner: "1000"
        group: "1000"
        mode: "0755"

    - name: Start Minecraft container
      community.docker.docker_container:
        name: minecraft
        image: itzg/minecraft-server:latest
        state: started
        restart_policy: unless-stopped

        published_ports:
          - "127.0.0.1:{{ minecraft_port }}:25565"

        publish_all_ports: false

        volumes:
          - "{{ minecraft_data_dir }}:/data"

        env:
          EULA: "TRUE"
          TYPE: "VANILLA"
          VERSION: "LATEST"
          MEMORY: "{{ minecraft_memory }}"
          ONLINE_MODE: "TRUE"
          ENABLE_RCON: "false"
```

> **Important:** `EULA: "TRUE"` indicates acceptance of the [Minecraft EULA](https://www.minecraft.net/en-us/eula). Review the agreement before running the playbook.

For predictable production deployments, pin a specific Minecraft version and Docker image version instead of using `LATEST`.

### Validate the Playbook

```bash
ansible-playbook -i inventory.ini --syntax-check playbook.yaml
```

### Deploy Minecraft

```bash
ansible-playbook -i inventory.ini playbook.yaml
```

Example of a successful deployment:

```text
PLAY RECAP

mc1 : ok=5 changed=3 unreachable=0 failed=0
```

The number of changed tasks may vary.

## 4. Firewall Configuration

The server uses UFW to restrict incoming network connections.

### Firewall Policy

| Service | Port | Public Access |
|---------|------|---------------|
| SSH | TCP 22 | Allowed |
| Minecraft | TCP 25565 | Blocked |
| HTTP | TCP 80 | Blocked |
| HTTPS | TCP 443 | Blocked |
| Other incoming connections | Any | Blocked |
| Outgoing connections | Any | Allowed |

This is the intended public access policy. Actual network exposure should be verified externally.

### Install UFW

Connect to the Hetzner virtual machine:

```bash
ssh root@YOUR_SERVER_IP
```

Install UFW:

```bash
sudo apt update
sudo apt install -y ufw
```

### Configure Firewall Rules

Allow SSH before enabling the firewall:

```bash
sudo ufw allow 22/tcp
```

Block incoming connections by default:

```bash
sudo ufw default deny incoming
```

Allow outgoing connections:

```bash
sudo ufw default allow outgoing
```

Enable UFW:

```bash
sudo ufw enable
```

Verify the firewall configuration:

```bash
sudo ufw status verbose
```

Expected output:

```text
Status: active
Logging: on (low)

Default: deny (incoming), allow (outgoing), deny (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

> **Warning:** Always allow SSH before enabling UFW. Verify that a second SSH connection works before closing the current one.

### Docker and UFW Integration

Docker manages its own networking and firewall rules.

Published Docker ports can bypass normal UFW incoming restrictions.

The project uses [ufw-docker](https://github.com/chaifeng/ufw-docker) to help integrate Docker traffic filtering with UFW.

Follow the installation instructions in the official repository and review the installation script before executing it with root privileges.

After installation, verify the integration:

```bash
sudo ufw-docker check
```

Inspect configured Docker access rules:

```bash
sudo ufw-docker status
```

The Minecraft container must not have an unintended public port mapping.

For additional protection, configure a Hetzner Cloud Firewall that allows only the required public ports.

## 5. Private Minecraft Access via SSH

The Minecraft server is intentionally not exposed directly to the public internet.

Instead, the Minecraft client connects through an encrypted SSH tunnel.

### Docker Port Binding

The Minecraft container publishes its port only on the VM's loopback interface:

```yaml
published_ports:
  - "127.0.0.1:25565:25565"
```

Verify the Docker container:

```bash
docker ps
```

Expected port mapping:

```text
127.0.0.1:25565->25565/tcp
```

This binds Minecraft to localhost rather than the server's public network interfaces.

Older Docker releases have had limitations with localhost-published ports being reachable from nearby network hosts. Keeping Docker updated and using a Hetzner Cloud Firewall provides additional protection.

### Create the SSH Tunnel

Open **Git Bash on the local Windows computer**.

Run:

```bash
ssh -N \
  -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:25565:127.0.0.1:25565 \
  -i ~/.ssh/id_ed25519 \
  root@YOUR_SERVER_IP
```

Replace `YOUR_SERVER_IP` with the Hetzner server's public IP address.

Keep the terminal open while playing Minecraft.

The tunnel forwards the connection through SSH:

```text
Minecraft Java Client
        |
        | localhost:25565
        |
        v
Local SSH Tunnel
        |
        | Encrypted SSH (TCP 22)
        |
        v
Hetzner Ubuntu Server
        |
        | 127.0.0.1:25565
        |
        v
Minecraft Docker Container
```

### Connect to Minecraft

Open **Minecraft Java Edition**.

Navigate to:

**Multiplayer → Direct Connection**

Enter:

```text
localhost:25565
```

The client connects to the local SSH tunnel, which forwards traffic to the remote Minecraft server.

No public Minecraft port needs to be opened.

### Verify External Access

From the local WSL terminal, check whether the public Minecraft port is reachable:

```bash
nc -zv -w 3 YOUR_SERVER_IP 25565
```

The connection should fail.

If the connection succeeds, investigate:

- Docker port bindings
- Other running Docker containers
- UFW rules
- ufw-docker rules
- Hetzner Cloud Firewall configuration

Verify both IPv4 and IPv6 exposure when applicable.

## 6. Server Management

The following Docker commands are executed on the remote Hetzner server.

### Check Running Containers

```bash
docker ps
```

### View Minecraft Logs

```bash
docker logs minecraft
```

Follow logs in real time:

```bash
docker logs -f minecraft
```

### Restart Minecraft

```bash
docker restart minecraft
```

### Stop Minecraft

```bash
docker stop minecraft
```

### Start Minecraft

```bash
docker start minecraft
```

### Check Firewall Status

```bash
sudo ufw status verbose
```

### Check Listening TCP Ports

```bash
sudo ss -lntp
```

### Redeploy Configuration Changes

From the local Ansible project directory:

```bash
ansible-playbook -i inventory.ini playbook.yaml
```

Ansible applies the required changes to the remote server.

## 7. Persistent Storage and Backups

Minecraft world data is stored outside the Docker container.

Default data directory:

```text
/opt/minecraft/data
```

Docker volume configuration:

```yaml
volumes:
  - "/opt/minecraft/data:/data"
```

This ensures that Minecraft data survives container restarts and recreation.

### Create a Backup

Stop Minecraft to ensure a consistent backup:

```bash
docker stop minecraft
```

Create an archive:

```bash
sudo tar -czf \
  "$HOME/minecraft-backup-$(date +%F).tar.gz" \
  -C /opt/minecraft data
```

Restart Minecraft:

```bash
docker start minecraft
```

Backups should also be stored outside the virtual machine.

> **Warning:** Running `terraform destroy` can permanently delete Minecraft world data stored on the VM. Always create an external backup first.

## 8. Destroying Infrastructure

Terraform can remove the cloud resources created during deployment.

Navigate to the Terraform directory:

```bash
cd hetzner-terraform
```

Preview the changes:

```bash
terraform plan -destroy
```

Destroy the infrastructure:

```bash
terraform destroy
```

Review the changes and confirm with `yes`.

This removes Terraform-managed resources, including the Hetzner virtual machine.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ansible: command not found` | Run Ansible inside WSL instead of PowerShell |
| `Permission denied (publickey)` | Verify SSH username, private key, and permissions |
| `Missing Hetzner Cloud API token` | Set the `HCLOUD_TOKEN` environment variable |
| `ansible.cfg` ignored | Move the project into the WSL filesystem |
| `world writable directory` warning | Avoid running Ansible directly from `/mnt/c/` |
| Minecraft container not running | Check `docker ps -a` and container logs |
| Minecraft client cannot connect | Verify the SSH tunnel and Minecraft container |
| Minecraft port publicly accessible | Check Docker bindings and firewall rules |
| Minecraft world missing | Verify the persistent data directory |
| SSH connection refused | Check SSH service and firewall configuration |

## Security Best Practices

- Use SSH key authentication instead of passwords.
- Restrict SSH access to trusted IP addresses when possible.
- Keep Ubuntu, Docker, and Ansible updated.
- Never commit API tokens or private SSH keys.
- Keep UFW enabled.
- Review Docker firewall rules.
- Avoid publishing unnecessary Docker ports.
- Use SSH tunneling for private Minecraft connections.
- Verify publicly reachable ports from an external machine.
- Store backups outside the virtual machine.
- Use a dedicated non-root user for long-term administration.
- Pin software and container versions.
- Consider a Hetzner Cloud Firewall for additional protection.

### Recommended `.gitignore`

```gitignore
# Terraform
**/.terraform/
**/*.tfstate
**/*.tfstate.*
**/*.tfvars
**/*.tfvars.json
**/*.tfplan
**/crash.log
**/crash.*.log

# Environment variables and secrets
.env
.env.*
!.env.example
*.pem
*.key

# Ansible
*.retry

# Editors
.vscode/
.idea/

# Operating systems
.DS_Store
Thumbs.db
```

Terraform's `.terraform.lock.hcl` should generally be committed to version control.

## Useful Commands

| Command | Description |
|---------|-------------|
| `terraform init` | Initialize Terraform |
| `terraform fmt` | Format Terraform files |
| `terraform validate` | Validate Terraform configuration |
| `terraform plan` | Preview infrastructure changes |
| `terraform apply` | Deploy infrastructure |
| `terraform output` | Display Terraform outputs |
| `terraform destroy` | Destroy infrastructure |
| `ansible minecraft -m ping` | Test Ansible connectivity |
| `ansible-playbook playbook.yaml` | Deploy Minecraft |
| `docker ps` | List running containers |
| `docker logs -f minecraft` | Follow Minecraft logs |
| `docker restart minecraft` | Restart the Minecraft container |
| `sudo ufw status verbose` | Inspect UFW configuration |
| `sudo ufw-docker status` | Inspect Docker firewall rules |
| `sudo ss -lntp` | Inspect listening TCP services |


