#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
    echo "Uso: $0 <nome_ruolo>"
    exit 1
fi

RUOLO=$1
ROLE_DIR="roles/$RUOLO"
TASKS_MAIN="$ROLE_DIR/tasks/main.yml"
HANDLERS_MAIN="$ROLE_DIR/handlers/main.yml"
FILES_DIR="$ROLE_DIR/files"

# Creazione directory del ruolo se non esiste
if [ ! -d "$ROLE_DIR" ]; then
    echo "Il ruolo $RUOLO non esiste. Creazione in corso..."
    mkdir -p "$ROLE_DIR/tasks" "$ROLE_DIR/handlers" "$FILES_DIR"
    echo "Ruolo $RUOLO creato con successo."
fi

# Assicura che il file tasks/main.yml esista
if [ ! -f "$TASKS_MAIN" ]; then
    echo "Creazione del file $TASKS_MAIN..."
    touch "$TASKS_MAIN"
    echo "---" > "$TASKS_MAIN" # Intestazione YAML se necessario
    echo "File $TASKS_MAIN creato con successo."
fi

# Assicura che il file handlers/main.yml esista
if [ ! -f "$HANDLERS_MAIN" ]; then
    echo "Creazione del file $HANDLERS_MAIN..."
    touch "$HANDLERS_MAIN"
    echo "---" > "$HANDLERS_MAIN" # Intestazione YAML se necessario
    echo "File $HANDLERS_MAIN creato con successo."
fi

# Funzione per aggiungere un task solo se non presente
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

add_handler_if_missing() {
    local handler_name="$1"
    local handler_content="$2"
    if ! grep -q "name: $handler_name" "$HANDLERS_MAIN"; then
      echo "$handler_content" >> "$HANDLERS_MAIN"
      echo "Aggiunto handler '$handler_name' a $HANDLERS_MAIN."
    else
        echo "L'handler '$handler_name' è già presente in $HANDLERS_MAIN."
    fi
}

# Task: Installa debconf
add_task_if_missing "Installa debconf" "
- name: Installa debconf
  apt:
    update_cache: yes
    name: [ 'debconf', 'debconf-utils']
    state: latest
"

# Task: Configura slapd
add_task_if_missing "Configura slapd" "
- name: Configura slapd
  copy:
    src: debconf-slapd.conf
    dest: /root/debconf-slapd.conf
    owner: root
    group: root
    mode: 0644
"

# Task: Esegui debconf
add_task_if_missing "Esegui debconf" "
- name: Esegui debconf
  shell:
    cmd: cat /root/debconf-slapd.conf | debconf-set-selections
"

# Task: Installa slapd
add_task_if_missing "Installa slapd" "
- name: Installa slapd
  apt:
    update_cache: yes
    name: [ 'slapd', 'ldap-utils']
    state: latest
"

add_task_if_missing "Copio config ldif" "
- name: Copio config ldif
  copy:
    src: \"{{ item }}\"
    dest: /tmp
    mode: 0644
  loop:
    - groups.ldif
    - people.ldif
  notify: Importa file ldif
"

add_handler_if_missing "Importa file ldif" "
- name: Importa file ldif
  shell: |-
    ldapsearch -x -b \"ou=Groups,dc=labammsis\" -s base > /dev/null || 
      ldapadd -x -H ldapi:/// -D \"cn=admin,dc=labammsis\" -w \"peppecasa\" -f /tmp/groups.ldif
    ldapsearch -x -b \"ou=People,dc=labammsis\" -s base > /dev/null || 
      ldapadd -x -H ldapi:/// -D \"cn=admin,dc=labammsis\" -w \"peppecasa\" -f /tmp/people.ldif
"



echo "Verifica e aggiunta dei task completata."

# Creazione file debconf-slapd.conf
DEBCONF_FILE="$FILES_DIR/debconf-slapd.conf"
if [ ! -f "$DEBCONF_FILE" ]; then
    cat <<EOL > "$DEBCONF_FILE"
slapd slapd/password1 password peppecasa
slapd slapd/password2 password peppecasa
slapd slapd/move_old_database boolean true
slapd slapd/domain string labammsis
slapd shared/organization string Unibo
slapd slapd/no_configuration boolean false
slapd slapd/purge_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/backend select MDB
EOL
    echo "Creato il file $DEBCONF_FILE."
else
    echo "Il file $DEBCONF_FILE esiste già."
fi

# Creazione file people.ldif
PEOPLE_FILE="$FILES_DIR/people.ldif"
if [ ! -f "$PEOPLE_FILE" ]; then
    cat <<EOL > "$PEOPLE_FILE"
dn: ou=People,dc=labammsis
objectClass: organizationalunit
ou: People
description: system users
EOL
    echo "Creato il file $PEOPLE_FILE."
else
    echo "Il file $PEOPLE_FILE esiste già."
fi

# Creazione file groups.ldif
GROUPS_FILE="$FILES_DIR/groups.ldif"
if [ ! -f "$GROUPS_FILE" ]; then
    cat <<EOL > "$GROUPS_FILE"
dn: ou=Groups,dc=labammsis
objectClass: organizationalunit
ou: Groups
description: system groups
EOL
    echo "Creato il file $GROUPS_FILE."
else
    echo "Il file $GROUPS_FILE esiste già."
fi
