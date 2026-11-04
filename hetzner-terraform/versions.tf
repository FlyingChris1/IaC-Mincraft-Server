
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
