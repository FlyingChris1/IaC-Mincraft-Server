variable "server_name" {
  description = "Name des Hetzner Servers"
  type        = string
}

variable "server_type" {
  description = "Hetzner Servertyp"
  type        = string
}

variable "image" {
  description = "Betriebssystem"
  type        = string
}

variable "location" {
  description = "Hetzner Standort"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Pfad zum SSH Public Key"
  type        = string
}
