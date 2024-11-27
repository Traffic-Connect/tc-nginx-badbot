#!/bin/bash

CONFIG_FILE="/etc/nginx/conf.d/badbot.conf"
FORCE=false

# Проверяем, передан ли флаг -f
while getopts "f" opt; do
  case $opt in
    f)
      FORCE=true
      ;;
    *)
      echo "Неправильный флаг. Используйте -f для принудительного перезаписывания конфигураций."
      exit 1
      ;;
  esac
done

# Создание или перезапись badbot.conf
if [ ! -f "$CONFIG_FILE" ] || [ "$FORCE" = true ]; then
    cat <<EOL > "$CONFIG_FILE"
map \$http_user_agent \$limit_bots {
    default 0;
    ~*(PetalBot|Ahrefs|SemrushBot|DotBot|ia_archiver|MJ12|Majestic-12|SEOkicks-Robot|Screaming\ Frog\ SEO\ Spider|Netpeak\ Spider|publicwww|LinkpadBot|serpstatbot|SiteAnalyzerBot|majestic12|Semrush|MJ12bot|AhrefsBot|BLEXBot|DataForSeoBot|Go-http-client|TinyTestBot|Nmap|python-requests|thesis-research-bot|spider|my-tiny-bot|Crawler|Barkrowler|Applebot|Amazonbot|Censys|claudebot|SeekportBot|GPTBot|keys-so-bot|bidswitchbot|AwarioBot) 1;
}
EOL
    echo "$CONFIG_FILE создан или перезаписан."
else
    echo "$CONFIG_FILE уже существует."
fi

for US in $(/usr/local/hestia/bin/v-list-users | awk '{print $1}' | grep -Ev "USER|----"); do
    for DOMAIN in $(/usr/local/hestia/bin/v-list-web-domains "$US" | awk '{print $1}' | grep -Ev "DOMAIN|------"); do
        SSL_CONF="/home/$US/conf/web/$DOMAIN/nginx.ssl.conf_badbot"
        NON_SSL_CONF="/home/$US/conf/web/$DOMAIN/nginx.conf_badbot"
        
        # Перезаписываем или добавляем конструкцию в конфигурационные файлы
        if [ "$FORCE" = true ] || ! ([ -f "$SSL_CONF" ] && grep -q '\$limit_bots' "$SSL_CONF" &&
                                     [ -f "$NON_SSL_CONF" ] && grep -q '\$limit_bots' "$NON_SSL_CONF"); then
            echo 'if ($limit_bots = 1) { return 444; }' > "$SSL_CONF"
            echo 'if ($limit_bots = 1) { return 444; }' > "$NON_SSL_CONF"
            echo "Конфигурации для домена $DOMAIN обновлены или перезаписаны."
        fi
    done
done

# Пауза на 5 секунд
sleep 5

# Проверка конфигурации Nginx и перезагрузка
nginx -t
if [ $? -eq 0 ]; then
    nginx -s reload
    echo "Nginx успешно перезагружен."
else
    echo "Ошибка в конфигурации Nginx. Перезагрузка отменена."
fi
