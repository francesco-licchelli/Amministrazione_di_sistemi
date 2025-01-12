#!/bin/bash

# Verifica del parametro
if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <path-dir-config>"
  exit 1
fi

CONFIG_DIR="$1"

# Controllo esistenza directory di configurazione
if [ ! -d "$CONFIG_DIR" ]; then
  echo "Errore: la directory $CONFIG_DIR non esiste."
  exit 1
fi

ROLES_DIR="$CONFIG_DIR/roles"

# Controllo esistenza directory roles
if [ ! -d "$ROLES_DIR" ]; then
  echo "Errore: la directory $CONFIG_DIR non contiene una sottodirectory roles."
  exit 1
fi

# Iterazione sulle directory dei ruoli
for ROLE_DIR in "$ROLES_DIR"/*; do
  FILES_DIR="$ROLE_DIR/files"

  # Verifica esistenza directory files
  if [ -d "$FILES_DIR" ]; then
    for CONFIG_FILE in "$FILES_DIR"/iface_*; do
      [ -e "$CONFIG_FILE" ] || continue

      ROLE_NAME=$(basename "$ROLE_DIR")
      INTERFACE_FILE=$(basename "$CONFIG_FILE")
      INTERFACE_NAME=$(echo "$INTERFACE_FILE" | cut -d_ -f2)

      HANDLERS_FILE="$ROLE_DIR/handlers/main.yml"
      TASKS_FILE="$ROLE_DIR/tasks/main.yml"

      # Gestione handlers/main.yml
      mkdir -p "$ROLE_DIR/handlers/"
      if [ ! -f "$HANDLERS_FILE" ]; then
        cat <<EOT > "$HANDLERS_FILE"
- name: Riavvia network
  service:
    name: networking
    state: restarted
EOT
      elif ! grep -q "^- name: Riavvia network$" "$HANDLERS_FILE"; then
        cat <<EOT >> "$HANDLERS_FILE"

- name: Riavvia network
  service:
    name: networking
    state: restarted
EOT
      fi
      # Gestione tasks/main.yml
      mkdir -p "$ROLE_DIR/tasks/"
      if [ ! -f "$TASKS_FILE" ]; then
        touch "$TASKS_FILE"
      fi

      if ! grep -q "^- name: Configuro $INTERFACE_NAME$" "$TASKS_FILE"; then
        cat <<EOT >> "$TASKS_FILE"
- name: Configuro $INTERFACE_NAME
  copy:
    src: $INTERFACE_FILE
    dest: /etc/network/interfaces.d/$INTERFACE_NAME
    owner: root
    group: root
    mode: 0644
    validate: /usr/sbin/ifup --no-act -i %s $INTERFACE_NAME
  notify: Riavvia network

EOT
      fi
      echo "$INTERFACE_NAME aggiunta per il ruolo $ROLE_NAME"
    done
  fi
done
