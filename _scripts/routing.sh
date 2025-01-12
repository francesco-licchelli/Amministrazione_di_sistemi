#!/bin/bash

# Verifica dei parametri
if [ $# -lt 1 ]; then
    echo "Uso: $0 <nome_ruolo>"
    exit 1
fi

RUOLO=$1
DIR="roles/$RUOLO"
TASKS_FILE="$DIR/tasks/main.yml"
NAME="Verifica attivazione routing"

# Controlla se il ruolo esiste e crea le directory necessarie se non esistono
if [ ! -d "$DIR" ]; then
    echo "Il ruolo $RUOLO non esiste. Creazione in corso..."
    mkdir -p "$DIR/tasks"
    echo "Ruolo $RUOLO creato con successo in $DIR."
fi

# Assicura che il file tasks/main.yml esista
if [ ! -f "$TASKS_FILE" ]; then
    echo "Creazione del file $TASKS_FILE..."
    touch "$TASKS_FILE"
    echo "---" > "$TASKS_FILE" # Aggiungi un'intestazione YAML se necessaria
    echo "File $TASKS_FILE creato con successo."
fi

# Contenuto da aggiungere
CODE="
- name: $NAME
  sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    sysctl_set: yes
    state: present
    reload: yes
"

# Aggiungi il codice al file se non è già presente
if grep -q "name: $NAME" "$TASKS_FILE"; then
    echo "Il blocco è già presente in $TASKS_FILE. Nessuna modifica effettuata."
else
    echo "Aggiungo il blocco al file $TASKS_FILE..."
    echo "$CODE" >> "$TASKS_FILE"
    echo "Blocco aggiunto a $TASKS_FILE con successo."
fi
