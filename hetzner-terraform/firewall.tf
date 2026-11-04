resource "hcloud_firewall" "minecraft" {
  name = "minecraft-firewall"

  # Alter SSH-Port (vorübergehend)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"

    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]

    description = "Temporary SSH access"
  }

  # Neuer SSH-Port
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "2222"

    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]

    description = "Allow SSH access"
  }
}