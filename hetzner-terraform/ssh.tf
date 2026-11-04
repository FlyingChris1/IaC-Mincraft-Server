resource "hcloud_ssh_key" "main" {
  name = "ansible-lab-ssh"

  public_key = file(
    pathexpand("~/.ssh/id_ed25519.pub")
  )
}
