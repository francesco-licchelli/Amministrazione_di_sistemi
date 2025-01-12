#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
  echo "Uso: $0 <nome_ruolo>"
  exit 1
fi

RUOLO=$1
ROLE_DIR="roles/$RUOLO"

# Creazione delle directory se non esistono
TASKS_DIR="$ROLE_DIR/tasks"
HANDLERS_DIR="$ROLE_DIR/handlers"
FILES_DIR="$ROLE_DIR/files"

mkdir -p "$TASKS_DIR" "$HANDLERS_DIR" "$FILES_DIR"

TASKS_MAIN="$TASKS_DIR/main.yml"
HANDLERS_MAIN="$HANDLERS_DIR/main.yml"
SNMPD_CONF="$FILES_DIR/snmpd.conf"

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

add_task_if_missing "Installo snmpd" "
- name: Installo snmpd
  apt:
    name: snmpd
    state: present
"

add_task_if_missing "Configuro snmpd" "
- name: Configuro snmpd
  copy:
    src: snmpd.conf
    dest: /etc/snmp/snmpd.conf
  notify: Riavvia snmpd
"

add_task_if_missing "Configuro sudoers" "
- name: Configuro sudoers
  lineinfile:
    path: /etc/sudoers
    state: present
    line: \"{{ item }}\"
  loop:
    - 'Debian-snmp ALL=(vagrant) NOPASSWD:/usr/bin/cat /home/vagrant/keys/*'
    - 'vagrant ALL=(ALL) NOPASSWD: /bin/echo, /usr/bin/tee /etc/snmp/snmpd.conf'
"

# Aggiunta dei handler a handlers/main.yml
HANDLER_NAME="Restart snmpd"
if [ ! -f "$HANDLERS_MAIN" ]; then
  touch "$HANDLERS_MAIN"
  echo "Creato il file $HANDLERS_MAIN."
fi

if ! grep -q "name: $HANDLER_NAME" "$HANDLERS_MAIN"; then
  cat <<EOL >> "$HANDLERS_MAIN"

- name: Riavvia snmpd
  service:
    name: snmpd
    state: restarted
EOL
  echo "Aggiunto handler '$HANDLER_NAME' a $HANDLERS_MAIN."
else
  echo "Handler '$HANDLER_NAME' già presente in $HANDLERS_MAIN."
fi

# Creazione e popolamento di snmpd.conf in files/
if [ ! -f "$SNMPD_CONF" ]; then
  cat <<EOL > "$SNMPD_CONF"
agentAddress udp:161
view all included .1
rocommunity public default -V all
rwcommunity supercom default -V all
EOL
  echo "Creato il file $SNMPD_CONF."
else
  echo "Il file $SNMPD_CONF esiste già."
fi

echo "Script completato con successo."
