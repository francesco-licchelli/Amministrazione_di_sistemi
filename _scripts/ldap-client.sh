#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
  echo "Uso: $0 <nome_ruolo>"
  exit 1
fi

RUOLO=$1
ROLE_DIR="roles/$RUOLO"

# Creazione struttura di base
TASKS_DIR="$ROLE_DIR/tasks"
HANDLERS_DIR="$ROLE_DIR/handlers"
VARS_DIR="$ROLE_DIR/vars"

mkdir -p "$TASKS_DIR" "$HANDLERS_DIR" "$VARS_DIR"

TASKS_MAIN="$TASKS_DIR/main.yml"
HANDLERS_MAIN="$HANDLERS_DIR/main.yml"
VARS_MAIN="$VARS_DIR/main.yml"

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

# Creazione e popolamento di tasks/main.yml
if [ ! -f "$TASKS_MAIN" ]; then
  touch "$TASKS_MAIN"
  echo "Creato il file $TASKS_MAIN."
fi

add_task_if_missing "Configura debconf per libnss-ldapd" "
- name: Configura debconf per libnss-ldapd
  debconf:
    name: libnss-ldapd
    question: \"{{ item.question }}\"
    value: \"{{ item.value }}\"
    vtype: \"{{ item.vtype }}\"
  loop: \"{{ libnss_ldapd }}\"
"

add_task_if_missing "Configura debconf per nslcd" "
- name: Configura debconf per nslcd
  debconf:
    name: nslcd
    question: \"{{ item.question }}\"
    value: \"{{ item.value }}\"
    vtype: \"{{ item.vtype }}\"
  loop: \"{{ nslcd }}\"
"

add_task_if_missing "Installa ldap-utils, libpam-ldap e libnss-ldap" "
- name: Installa ldap-utils, libpam-ldap e libnss-ldap
  apt:
    name:
      - ldap-utils
      - nslcd
      - libpam-ldapd
      - libnss-ldapd
    update_cache: true
  notify: Riavvia nscd
"

# Creazione e popolamento di handlers/main.yml
if [ ! -f "$HANDLERS_MAIN" ]; then
  touch "$HANDLERS_MAIN"
  echo "Creato il file $HANDLERS_MAIN."
fi

if ! grep -q "name: Riavvia nscd" "$HANDLERS_MAIN"; then
  cat <<EOL >> "$HANDLERS_MAIN"

- name: Riavvia nscd
  service:
    name: nscd
    state: restarted
EOL
  echo "Aggiunto handler 'Riavvia nscd' a $HANDLERS_MAIN."
else
  echo "Handler 'Riavvia nscd' già presente in $HANDLERS_MAIN."
fi

# Creazione e popolamento di vars/main.yml
if [ ! -f "$VARS_MAIN" ]; then
  cat <<EOL > "$VARS_MAIN"
ldapserver: EDITME
libnss_ldapd:
  - question: libnss-ldapd/clean_nsswitch
    value: true
    vtype: boolean
  - question: libnss-ldapd/nsswitch
    value: passwd, group, shadow
    vtype: string

nslcd:
  - question: nslcd/ldap-uris
    value: "ldap://{{ ldapserver }}/"
    vtype: string
  - question: nslcd/ldap-base
    value: dc=labammsis
    vtype: string
EOL
  echo "Creato il file $VARS_MAIN con i contenuti richiesti."
else
  echo "Il file $VARS_MAIN esiste già."
fi

echo "Script completato con successo."
