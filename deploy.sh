#!/bin/bash

set -e

echo "🔁 Entrando na pasta do projeto..."
cd /home/corradi/projects/site/ || { echo "❌ Erro ao entrar na pasta do projeto."; exit 1; }

echo "⬇️ Atualizando código com git pull..."
git pull || { echo "❌ Erro ao executar git pull."; exit 1; }

echo "🧪 Carregando virtualenvwrapper..."
export WORKON_HOME="/home/corradi/opt/virtual_env/"
source "/usr/share/virtualenvwrapper/virtualenvwrapper.sh" || {
  echo "❌ Erro ao carregar o virtualenvwrapper."; exit 1;
}

echo "🧪 Ativando o ambiente virtual..."
workon corradi || { echo "❌ Erro ao ativar o ambiente virtual."; exit 1; }

echo "🛠 Aplicando migrações do banco de dados..."
./manage.py migrate || { echo "❌ Erro ao aplicar migrações."; exit 1; }

echo "🧹 Removendo pasta static/..."
rm -rf static/ || { echo "❌ Erro ao remover a pasta static."; exit 1; }

echo "📦 Coletando arquivos estáticos..."
./manage.py collectstatic --noinput || { echo "❌ Erro ao coletar os arquivos estáticos."; exit 1; }

echo "🚀 Reiniciando o uWSGI..."
./uwsgi.sh restart || { echo "❌ Erro ao reiniciar o uWSGI."; exit 1; }

echo "🌐 Limpando cache no Cloudflare..."
source ~/.cloudflare.env

response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/purge_cache" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}')

if echo "$response" | grep -q '"success":true'; then
    echo "✅ Cache do Cloudflare limpo com sucesso."
else
    echo "❌ Falha ao limpar cache do Cloudflare:"
    echo "$response"
    exit 1
fi

echo "✅ Deploy concluído com sucesso!"

echo "📲 Enviando notificação para Telegram..."
source ~/.telegram.env

MENSAGEM="✅ Deploy Corradi finalizado com sucesso em $(date '+%d/%m/%Y %H:%M') 🚀"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
     -d chat_id="$TELEGRAM_CHAT_ID" \
     -d text="$MENSAGEM" \
     -d parse_mode="Markdown" > /dev/null

echo "📬 Notificação enviada para Telegram."