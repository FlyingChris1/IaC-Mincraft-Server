
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible-minecraft/inventory.ini"

  content = <<-EOT
[minecraft]
mc1 ansible_host=${hcloud_server.vm.ipv4_address} ansible_user=deploy ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_ssh_common_args='-o HostKeyAlias=minecraft-${hcloud_server.vm.id} -o StrictHostKeyChecking=accept-new -o CheckHostIP=no'
EOT
}
