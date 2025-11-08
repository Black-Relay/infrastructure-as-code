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

data "hcloud_ssh_key" "Dell-XPS" {
  name = "robbie@Robbie-Dell-XPS"
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

locals {
  cloud_init = <<-EOT
    #cloud-config
    users:
      - name: josh
        groups: sudo, docker
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${data.hcloud_ssh_key.Josh-Noll.public_key}
      - name: robbie
        groups: sudo, docker
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${data.hcloud_ssh_key.EOS-Desktop.public_key}
          - ${data.hcloud_ssh_key.Robbie-Dell.public_key}
    
    ssh_pwauth: false
    disable_root: false
    
    write_files:
      - path: /etc/ssh/sshd_config.d/99-hardening.conf
        content: |
          PermitRootLogin no
          PasswordAuthentication no
          PubkeyAuthentication yes
          KbdInteractiveAuthentication no
          ChallengeResponseAuthentication no
          MaxAuthTries 3
          AllowTcpForwarding no
          X11Forwarding no
          AllowAgentForwarding no
          AuthorizedKeysFile .ssh/authorized_keys
          AllowUsers josh robbie
        permissions: '0644'
    
    runcmd:
      - systemctl restart sshd
  EOT
}


resource "hcloud_server" "from_snapshot" {
  name        = "black-relay"
  image       = data.hcloud_image.packer_snapshot.id
  server_type = "cx33"
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data = local.cloud_init
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