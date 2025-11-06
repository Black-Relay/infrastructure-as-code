terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    
  }
  cloud { 
    
    organization = "black-relay" 

    workspaces { 
      name = "hetzner-control-plane" 
    } 
  } 
}

provider "hcloud" {
  # Token read from HCLOUD_TOKEN env variable
}

data "hcloud_image" "packer_snapshot" {
  with_selector = "app=docker"
  most_recent = true
}

data "hcloud_ssh_key" "Josh-Noll" {
  name = "josh-br-vps"
}

data "hcloud_ssh_key" "EOS-Desktop" {
  name = "robbie@EOS-Desktop"
}

resource "hcloud_firewall" "firewall" {
  name = "Black Relay VPS Firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow web traffic in"

  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow web traffic in"
  }

   rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "Allow SSH in"

  }

}


resource "hcloud_server" "from_snapshot" {
  name        = "black-relay"
  image       = data.hcloud_image.packer_snapshot.id
  server_type = "cx33"
firewall_ids = [hcloud_firewall.firewall.id]
  ssh_keys = [ data.hcloud_ssh_key.Josh-Noll.name, data.hcloud_ssh_key.EOS-Desktop.name  ]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

variable "cloudflare_api_token" {
  type        = string
  description = "API token for Cloudflare"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID fdomain in Cloudflare"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_dns_record" "hetzner_server" {
  zone_id = var.cloudflare_zone_id
  name    = "hs"
  type    = "A"
  content   = hcloud_server.from_snapshot.ipv4_address
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "hetzner_server_ipv6" {
  zone_id = var.cloudflare_zone_id
  name    = "hs"
  type    = "AAAA"
  content   = hcloud_server.from_snapshot.ipv6_address
  ttl     = 1
  proxied = true
}