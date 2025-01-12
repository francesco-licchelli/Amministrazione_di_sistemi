#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
  echo "Uso: $0 <nome_ruolo>"
  exit 1
fi

RUOLO=$1
ROLE_DIR="roles/$RUOLO"

# Creazione della directory tasks se non esiste
TASKS_DIR="$ROLE_DIR/tasks"

mkdir -p "$TASKS_DIR"

TASKS_MAIN="$TASKS_DIR/main.yml"

# Funzione per aggiungere un task se non presente
add_task_if_missing() {
  local task_name="$1"
  local task_content="$2"
  if ! grep -q "name: $task_name" "$TASKS_MAIN"; then
    echo "$task_content" >> "$TASKS_MAIN"
    echo "Aggiunto il task '$task_name' a $TASKS_MAIN."
  else
    echo "Il task '$task_name' è già presente in $TASKS_MAIN."
  fi
}

# Aggiunta dei task a tasks/main.yml
if [ ! -f "$TASKS_MAIN" ]; then
  touch "$TASKS_MAIN"
  echo "Creato il file $TASKS_MAIN."
fi

add_task_if_missing "Verifico non-free e contrib abilitati" "
- name: Verifico non-free e contrib abilitati
  ansible.builtin.apt_repository:
    repo: deb https://deb.debian.org/debian bookworm main contrib non-free
    state: present
"

add_task_if_missing "Installo SNMP e Mibs" "
- name: Installo SNMP e Mibs
  ansible.builtin.apt:
    name: [ snmp, snmp-mibs-downloader ]
    update_cache: true
"

add_task_if_missing "Configuro MIBS" "
- name: Configuro MIBS
  ansible.builtin.lineinfile:
    path: /etc/snmp/snmp.conf
    regexp: '^mibs'
    state: absent
"

echo "Script completato con successo."
