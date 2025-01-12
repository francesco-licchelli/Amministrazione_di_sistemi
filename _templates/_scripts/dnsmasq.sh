#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
    echo "Uso: $0 <nome_ruolo>"
    exit 1
fi
ROLE="$1"
DIR="roles/$ROLE"

# Controlla se il ruolo esiste e lo crea se necessario
if [ ! -d "$DIR" ]; then
    echo "Il ruolo $ROLE non esiste. Creazione in corso..."
    mkdir -p "$DIR/files" "$DIR/handlers" "$DIR/tasks"
    echo "Ruolo $ROLE creato con successo in $DIR."
fi

# Variabili per i nomi
TASK_NAME_INSTALL="Installo dnsmasq"
TASK_NAME_CONFIGURE="Configuro dnsmasq"
HANDLER_NAME="Riavvia dnsmasq"

# Verifica che il file dnsmasq.conf esista nella cartella files
if [ ! -f "$DIR/files/dnsmasq.conf" ]; then
    echo "Errore: Il file dnsmasq.conf non esiste in $DIR/files."
    exit 1
fi

# Aggiungi il contenuto a <dir>/tasks/main.yml
TASKS_FILE="$DIR/tasks/main.yml"
if ! grep -q "name: $TASK_NAME_INSTALL" "$TASKS_FILE" 2>/dev/null; then
    echo "Aggiungo il task di installazione e configurazione di dnsmasq a $TASKS_FILE"
    cat <<EOL >> "$TASKS_FILE"

- name: $TASK_NAME_INSTALL
  apt:
    name: dnsmasq
    state: present
    update_cache: true

- name: $TASK_NAME_CONFIGURE
  copy:
    src: dnsmasq.conf
    dest: /etc/dnsmasq.conf
    owner: root
    group: root
    mode: 0644
  notify: $HANDLER_NAME
EOL
else
    echo "I task relativi a dnsmasq sono già presenti in $TASKS_FILE. Nessuna modifica effettuata."
fi

# Aggiungi il contenuto a <dir>/handlers/main.yml
HANDLERS_FILE="$DIR/handlers/main.yml"
if ! grep -q "name: $HANDLER_NAME" "$HANDLERS_FILE" 2>/dev/null; then
    echo "Aggiungo il handler di riavvio di dnsmasq a $HANDLERS_FILE"
    cat <<EOL >> "$HANDLERS_FILE"

- name: $HANDLER_NAME
  service:
    name: dnsmasq
    state: restarted
EOL
else
    echo "L'handler $HANDLER_NAME è già presente in $HANDLERS_FILE. Nessuna modifica effettuata."
fi

echo "Operazione completata con successo!"
