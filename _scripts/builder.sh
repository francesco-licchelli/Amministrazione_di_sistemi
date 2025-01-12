#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Nessun percorso specificato"
    exit 1
fi

if ! mkdir -p "$1"; then
    echo "Errore creazione cartella"
    exit 1
fi

BASE_DIR="$1"
VAG_FILE="$BASE_DIR/Vagrantfile"
PLB_FILE="$BASE_DIR/site.yml"
COMMON_DIR="$BASE_DIR/roles/_common"
TASKS_FILE="$COMMON_DIR/tasks/main.yml"
VARS_FILE="$COMMON_DIR/vars/main.yml"

# Creazione dei file principali
touch "$VAG_FILE"
touch "$PLB_FILE"

# Creazione della struttura roles/_common
mkdir -p "$COMMON_DIR/tasks"
mkdir -p "$COMMON_DIR/vars"

echo "Struttura delle cartelle creata."

# Scrive il contenuto nel file Vagrantfile
cat <<EOT > "$VAG_FILE"
Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"

    config.vm.provider "virtualbox" do |vb|
        vb.linked_clone = true
    end
    config.vm.provision "ansible" do |ansible|
        ansible.playbook = "site.yml"
    end

    config.vm.define "R" do |machine|
        machine.vm.hostname = "R"
        machine.vm.network "private_network", virtualbox__intnet: "NET1", auto_config: false
        machine.vm.network "private_network", virtualbox__intnet: "NET2", auto_config: false
    end
    
    (1..1).each do |i|
        config.vm.define "C#{i}" do |machine|
            machine.vm.hostname = "C#{i}"
            machine.vm.network "private_network", virtualbox__intnet: "NET1", auto_config: false
        end
    end

    (1..2).each do |i|
        config.vm.define "S#{i}" do |machine|
            machine.vm.hostname = "S#{i}"
            machine.vm.network "private_network", virtualbox__intnet: "NET2", auto_config: false
        end
    end
end
EOT

echo "Vagrantfile creato."

# Scrive il contenuto nel file site.yml
cat <<EOT > "$PLB_FILE"
- hosts: all
  become: true
  roles:
    - role: _common
EOT

echo "site.yml creato."

# Scrive il contenuto nel file tasks/main.yml
cat <<EOT > "$TASKS_FILE"
- name: Attivo vi-mode su tutti i terminali delle VM
  lineinfile:
    path: /etc/bash.bashrc
    line: set -o vi
    state: present

- name: "Aggiorno tutti i pacchetti"
  apt:
    update_cache: true

- name: "Cambio allow-hotplug con auto"
  replace:
    path: '/etc/network/interfaces'
    regexp: '^allow\\-hotplug'
    replace: 'auto'

- name: Configurazione /etc/apt/apt.conf.d/proxy.conf
  become: true
  lineinfile:
    path: '/etc/apt/apt.conf.d/proxy.conf'
    create: true
    owner: root
    group: root
    mode: '0644'
    state: present
    line: "{{ item }}"
  loop:
    - 'Acquire::http::Proxy "{{ proxy_url }}/";'
    - 'Acquire::https::Proxy "{{ proxy_url }}/";'

- name: Configurazione ~/.bashrc
  become: true
  lineinfile:
    path: '/home/vagrant/.bashrc'
    state: present
    line: "{{ item }}"
  loop:
    - 'export HTTP_PROXY="{{ proxy_url }}"'
    - 'export HTTPS_PROXY="{{ proxy_url }}"'
EOT

echo "tasks/main.yml creato."

# Scrive il contenuto nel file vars/main.yml
cat <<EOT > "$VARS_FILE"
lab_num: 3
proxy_url: 'http://192.168.12{{ lab_num }}.249:8080'
EOT

echo "vars/main.yml creato."
