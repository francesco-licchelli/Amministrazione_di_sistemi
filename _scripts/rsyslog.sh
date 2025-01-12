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
HANDLERS_DIR="$ROLE_DIR/handlers"
FILES_DIR="$ROLE_DIR/files"

mkdir -p "$TASKS_DIR" "$HANDLERS_DIR" "$FILES_DIR"

TASKS_MAIN="$TASKS_DIR/main.yml"
HANDLERS_MAIN="$HANDLERS_DIR/main.yml"
RSYSLOG_CONF="$FILES_DIR/rsyslog.conf"
RSYSLOG_MINE_CONF="$FILES_DIR/rsyslog_mine.conf"

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

add_task_if_missing "Copio config di base rsyslog" "
- name: Copio config di base rsyslog
  copy:
    src: rsyslog.conf
    dest: '/etc/rsyslog.conf'
    owner: 'root'
    group: 'root'
    mode: '0644'
  notify: Riavvia rsyslog
"

add_task_if_missing "Copio mia config rsyslog" "
- name: Copio mia config rsyslog
  copy:
    src: rsyslog_mine.conf
    dest: '/etc/rsyslog.d/'
    owner: 'root'
    group: 'root'
    mode: '0644'
  notify: Riavvia rsyslog
"

# Aggiunta del handler a handlers/main.yml
HANDLER_CONTENT="
- name: Riavvia rsyslog
  service:
    name: rsyslog
    state: restarted
"

if [ ! -f "$HANDLERS_MAIN" ]; then
  touch "$HANDLERS_MAIN"
  echo "Creato il file $HANDLERS_MAIN."
fi

if ! grep -q "name: Riavvia rsyslog" "$HANDLERS_MAIN"; then
  echo "$HANDLER_CONTENT" >> "$HANDLERS_MAIN"
  echo "Aggiunto handler 'Riavvia rsyslog' a $HANDLERS_MAIN."
else
  echo "Handler 'Riavvia rsyslog' già presente in $HANDLERS_MAIN."
fi

# Creazione del file rsyslog.conf
if [ ! -f "$RSYSLOG_CONF" ]; then
  cat <<EOL > "$RSYSLOG_CONF"
# /etc/rsyslog.conf configuration file for rsyslog
#
# For more information install rsyslog-doc and see
# /usr/share/doc/rsyslog-doc/html/configuration/index.html


#################
#### MODULES ####
#################

module(load="imuxsock") # provides support for local system logging
module(load="imklog")   # provides kernel logging support
#module(load="immark")  # provides --MARK-- message capability

# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
#module(load="imtcp")
#input(type="imtcp" port="514")


###########################
#### GLOBAL DIRECTIVES ####
###########################

#
# Use traditional timestamp format.
# To enable high precision timestamps, comment out the following line.
#
$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

#
# Set the default permissions for all log files.
#
$FileOwner root
$FileGroup adm
$FileCreateMode 0640
$DirCreateMode 0755
$Umask 0022

#
# Where to place spool and state files
#
$WorkDirectory /var/spool/rsyslog

#
# Include all config files in /etc/rsyslog.d/
#
$IncludeConfig /etc/rsyslog.d/*.conf


###############
#### RULES ####
###############

#
# First some standard log files.  Log by facility.
#
auth,authpriv.*			/var/log/auth.log
*.*;auth,authpriv.none		-/var/log/syslog
#cron.*				/var/log/cron.log
daemon.*			-/var/log/daemon.log
kern.*				-/var/log/kern.log
lpr.*				-/var/log/lpr.log
mail.*				-/var/log/mail.log
user.*				-/var/log/user.log

#
# Logging for the mail system.  Split it up so that
# it is easy to write scripts to parse these files.
#
mail.info			-/var/log/mail.info
mail.warn			-/var/log/mail.warn
mail.err			/var/log/mail.err

#
# Some "catch-all" log files.
#
*.=debug;\
	auth,authpriv.none;\
	mail.none		-/var/log/debug
*.=info;*.=notice;*.=warn;\
	auth,authpriv.none;\
	cron,daemon.none;\
	mail.none		-/var/log/messages

#
# Emergencies are sent to everybody logged in.
#
*.emerg				:omusrmsg:*
EOL
  echo "Creato il file $RSYSLOG_CONF."
else
  echo "Il file $RSYSLOG_CONF esiste già."
fi

# Creazione del file rsyslog_mine.conf (vuoto)
if [ ! -f "$RSYSLOG_MINE_CONF" ]; then
  touch "$RSYSLOG_MINE_CONF"
  echo "Creato il file $RSYSLOG_MINE_CONF."
else
  echo "Il file $RSYSLOG_MINE_CONF esiste già."
fi

echo "Script completato con successo."
