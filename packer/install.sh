#!/usr/bin/env bash

set -eux

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings

distribution="$(lsb_release --short --id | awk '{ print tolower($0) }')"
distribution_release="$(lsb_release --short --codename)"

packages_installed=()
packages_removed=()
services_enabled=()

install_docker() {
  curl -fsSL "https://download.docker.com/linux/${distribution}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources << EOL
Enabled: yes
Types: deb
URIs: https://download.docker.com/linux/${distribution}
Suites: ${distribution_release}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOL

  packages_installed+=(docker-ce docker-compose-plugin)
  services_enabled+=(docker)
}

install_crowdsec() {
  curl -fsSL https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
  packages_installed+=(crowdsec crowdsec-firewall-bouncer-iptables)
  services_enabled+=(crowdsec crowdsec-firewall-bouncer)
}

remove_snapd() {
  packages_removed+=(snapd)
}

install_docker
install_crowdsec
remove_snapd

apt-get update
apt-get install -y "${packages_installed[@]}"

systemctl enable "${services_enabled[@]}"

apt-get purge -y "${packages_removed[@]}" || true

# Step 3: Enable and start all specified services
echo "Enabling and starting services..."
for service in "${services_enabled[@]}"; do
  systemctl enable --now "$service"
done