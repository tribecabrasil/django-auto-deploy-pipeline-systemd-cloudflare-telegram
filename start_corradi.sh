#!/bin/bash

LOGFILE="/home/corradi/deploy.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "==== $(date '+%Y-%m-%d %H:%M:%S') ==== Iniciando script de boot ===="

export WORKON_HOME="/home/corradi/opt/virtual_env/"
source "/usr/share/virtualenvwrapper/virtualenvwrapper.sh"

workon corradi || { echo "❌ Falha ao ativar o ambiente virtual"; exit 1; }

cd /home/corradi/projects/site/ || exit
./uwsgi.sh restart

echo "✅ Inicialização concluída"