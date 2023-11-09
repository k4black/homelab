# Personal Infrastructure Setup with Ansible

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

To run the playbooks, execute the following command:
```bash
ansible-playbook macbook_playbook.yml
ansible-playbook homeserver_playbook.yml
```