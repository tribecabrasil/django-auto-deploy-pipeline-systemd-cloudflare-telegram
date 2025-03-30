# 🚀 Automação de Deploy – Projeto Corradi

Este projeto implementa um fluxo completo de deploy automatizado com:

- Deploy com um comando (`deploycorradi`)
- Git Pull + Migrações + Static files
- Reinício automático do uWSGI
- Purge do cache Cloudflare via API
- Notificação via Telegram
- Inicialização automática no boot via systemd

---

## 📁 Estrutura de arquivos utilizados

```
/home/corradi/
├── projects/site/                    # Projeto Django
├── start_corradi.sh                 # Script de boot do projeto
├── deploy.sh → /usr/local/bin/deploycorradi
├── .telegram.env                    # Variáveis para o Telegram
└── .cloudflare.env                  # Variáveis do Cloudflare
```

---

## 1. 📦 Script `deploycorradi`

Criado como `/usr/local/bin/deploycorradi`:

```bash
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

# Cloudflare Purge
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

# Telegram Notification
echo "📲 Enviando notificação para Telegram..."
source ~/.telegram.env

MENSAGEM="✅ Deploy Corradi finalizado com sucesso em $(date '+%d/%m/%Y %H:%M') 🚀"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
     -d chat_id="$TELEGRAM_CHAT_ID" \
     -d text="$MENSAGEM" \
     -d parse_mode="Markdown" > /dev/null

echo "📬 Notificação enviada para Telegram."
```

---

## 2. 🌐 `.cloudflare.env`

```env
CLOUDFLARE_ZONE_ID=xxxxxxxxxxxxxxxxxxxxx
CLOUDFLARE_API_TOKEN=xxxxxxxxxxxxxxxxxxxxx
```

---

## 3. 📲 `.telegram.env`

```env
TELEGRAM_BOT_TOKEN=123456:ABCdefGHIjkLmnOPQ
TELEGRAM_CHAT_ID=123456789
```

---

## 4. ⚙️ Script de inicialização automática no boot

Arquivo: `/home/corradi/start_corradi.sh`

```bash
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
```

---

## 5. 🛠 systemd Service

Arquivo: `/etc/systemd/system/corradi.service`

```ini
[Unit]
Description=Iniciar ambiente Corradi com uWSGI
After=network.target

[Service]
Type=simple
User=corradi
ExecStart=/home/corradi/start_corradi.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Comandos para ativar o serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl enable corradi.service
sudo systemctl start corradi.service
```

---

## ✅ Resultados

- `deploycorradi` faz todo o deploy em segundos
- Ambiente reinicia automaticamente após reboot
- Logs e notificações garantem rastreabilidade
- Cloudflare cache é limpo automaticamente
- Telegram envia alerta no fim do processo