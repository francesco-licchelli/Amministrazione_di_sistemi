#!/bin/bash

# Funzione per modificare il file YML
fix_yml_file() {
    local file=$1

    # Aggiungi '---' all'inizio del file se non è già presente
    if ! head -n 1 "$file" | grep -q "^---"; then
        echo "---" | cat - "$file" > temp && mv temp "$file"
    fi

    # Modifica i file per assicurare che le righe che iniziano con '- name:' siano precedute da una riga vuota o '---'
    awk '
        BEGIN {prev=""}
        {
            # Se la riga corrente inizia con "- name:", controlla la riga precedente
            if ($0 ~ /^- name:/) {
                if (prev != "" && prev !~ /^---/ && prev !~ /^[[:space:]]*$/) {
                    print "";  # Aggiungi una riga vuota
                }
                print $0;
            } else {
                print $0;
            }
            prev=$0;
        }
    ' "$file" > temp && mv temp "$file"

}

# Verifica che sia stata passata una directory come argomento
if [ $# -ne 1 ]; then
    echo "Uso: $0 <directory>"
    exit 1
fi

directory=$1

# Verifica che la directory esista
if [ ! -d "$directory" ]; then
    echo "Errore: La directory $directory non esiste."
    exit 1
fi

# Controlla e modifica tutti i file .yml ricorsivamente nella directory
find "$directory" -type f -name "*.yml" | while read -r file; do
    fix_yml_file "$file"
done
