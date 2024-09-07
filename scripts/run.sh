#!/bin/bash

playbook="${1:-nginx}"
name="${2:-"box-1"}"

user_data=$"
#cloud-config
packages:
  - git
ansible:
  install_method: distro
  package_name: ansible
  pull:
    url: https://github.com/kebien6020/cloud-init-data.git
    playbook_name: ansible/$playbook/playbook.yml
"

set -x

doctl compute droplet create \
    --image fedora-40-x64 \
    --size s-1vcpu-1gb \
    --region nyc1 \
    --user-data "$user_data" \
	--ssh-keys 7a:aa:a4:0f:19:86:df:3a:d0:6f:5c:99:02:c2:6c:b2 \
    "$name"
