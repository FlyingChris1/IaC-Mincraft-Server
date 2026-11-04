resource "hcloud_server" "vm" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image
  location    = var.location

  ssh_keys = [hcloud_ssh_key.main.id]

  firewall_ids = [hcloud_firewall.minecraft.id]
  user_data    = file("${path.module}/cloud-init.yaml")

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
