#!/usr/bin/env bash

set -e

source /usr/local/share/entrypoint.mod/functions
enable-entrypoint-module awscli-store.sh
sudo cp terraform-store.sh /usr/local/share/entrypoint.d/

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo /opt/setup-tools/install-apt-packages.sh terraform
