output "server_ip" {
  description = "IPv4-Adresse des Servers"
  value       = hcloud_server.vm.ipv4_address
}
