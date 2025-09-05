# Personal Infrastructure Setup with Ansible

[![Test playbooks](https://github.com/k4black/personal-infra/actions/workflows/test.yml/badge.svg)](https://github.com/k4black/personal-infra/actions/workflows/test.yml)

This repository contains Ansible playbooks to set up a personal MacBook and home server. 
This README provides instructions on how to customize variables and run the playbooks.


## Prerequisites

Install [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) on your local machine.
```bash
python -m pip install ansible
```


## Configuration

Before running the playbook, you need to set the desired variables in `group_vars/*` files.
Also be sure to set up `inventory.ini` with the correct IP addresses of your hosts.


## Running the Playbook

Install command line tools to get git
```bash
xcode-select –-install
```

Create env and install ansible
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Update the roles
```bash
ansible-galaxy install -r requirements.yml --force
```

To run the playbooks, execute the following command:
```bash
ansible-playbook playbook_macbook.yml --ask-become-pass
ansible-playbook playbook_work_macbook.yml --ask-become-pass
ansible-playbook playbook_homelab.yml
ansible-playbook playbook_vps.yml
```




1. create vault password file `.vault_pass.txt`
2. to encrypt smth `ansible-vault encrypt_string --stdin-name mas_email`
3. to decrypt `ansible-vault decrypt_string --stdin-name mas_email`
4. to run `ansible-playbook -i inventory.ini playbook_macbook.yml`
5. to run `ansible-playbook -i inventory.ini playbook_vps.yml`

To lint run `yamllint .` and `ansible-lint`


## homelab setup

### General

Create duckdns [DOMAIN] and [TOKEN]

### Backups 

Connect disk to the raspberry pi and get uuid (PARTUUID)
```bash
sudo blkid
```
update vars/homelab.yml

### Pi initial setup:

1. Install raspbian lite on raspberry pi  
    Easy way: use [raspberry pi imager](https://www.raspberrypi.org/software/)  
    Fill wi-fi credentials and enable ssh with your ssh key
2. Create ssh config for the homelab with key and `homelab` announced name
3. Run `ansible-playbook -i inventory.ini playbook_homelab.yml` to setup homelab


### Router setup:

1. Connect raspberry pi to the power (auto network connection)
2. Fix ip address in router settings  
    Home Network -> Network -> Network Connections -> Edit homelab -- "Always assign this network device the same IPv4 address"
3. Announce homelab as upstream dns server in router settings
    Internet -> Account Information -> DNS Server -> Use other DNSv4/DNSv6 Servers  
    * Fill both fields with raspberry pi ip address
    * Checkbox fallback to public dns 
4. Forward vpn subnet through homelab  
    Home Network -> Network -> Network Settings -> IPv4 Addresses -> Network Settings -> IPv4 Routes -> New IPv4 Route  
   (same as in vars/all.yml)
    ```
    IPv4 Network: 10.1.0.0
    Subnet Mask: 255.255.255.0  (/24)
    Gateway: [homelab fixed ip]
    Ipv4 route active: checked
    ```
5. Forward ports to homelab  
    Internet -> Permit Access -> Port Sharing -> New Port Sharing Rule  
    Device: homelab  
    New Sharing -> Port Sharing
    ```
    Application: Custom
    Service Name: Wireguard
    Protocol: UPD
    Port: 51820
    ```
   

## router setup

### General

Create duckdns [DOMAIN] and [TOKEN]

### Generate config files

`ansible-playbook -i inventory.ini playbook_router.yml --tags=generate`

### VPN setup:

1. Setup DynDNS to update on the router
    Internet -> Permit Access -> DynDNS  
    ```
    Update URL: https://www.duckdns.org/update?domains=[DOMAIN]&token=[TOKEN]&ip=<ipaddr>&ipv6=<ip6addr>
    Domain Name: [DOMAIN].duckdns.org
    Username: none
    Password: [TOKEN]
    ```
2. Enable Wireguard on the router  
    Internet -> Permit Access -> VPN (WireGuard) -> Enable WireGuard -> Add connection  
    ```
    Connect networks or establish special connections
    already been set up: yes
    Name: wg0
    ```
    Load config from `.tmp/router-wg0.conf`
