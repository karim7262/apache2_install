#!/bin/bash

function cleardown (){
	yes '' | head -n 100
}
cleardown
ME="$(echo $0 | sed -e 's/^.*\///')"
if ! [ $(id -u) = 0 ]; then
	echo -e "Необходимо запустить "$ME" от имени root\\nДля этого выполните команду sudo "$ME
	exit
fi

echo -n "Проверка доступности новых версий пакетов"
apt-get update --fix-missing > /dev/null 2>.update.err
if ! [ "$?" -eq 0 ]; then
	echo
	echo -en "\e[0;31m"
	cat .update.err | grep -E "^E:"
	echo -en "\e[0m"
	rm -f .update.err
	read -p "Продолжить установку? [Y/N]: " -n 1 REPLAY 
	echo
	case $REPLAY in
		Y|y) cleardown
			echo -e "\e[0;32mПродолжаем...\e[0m" ;;
		*) exit 1 ;;
	esac
else
	echo -e "\e[0;32m   [Готово]\e[0m"
fi
echo "Установка WEB Сервера Apache и включение необходимых модулей"
apt-get -y install apache2 apache2-utils > /dev/null 2>&1

cp /etc/apache2/conf-available/security.conf /etc/apache2/conf-available/security.conf.bk
if [ -f /etc/apache2/conf-available/security.conf ]; then
	if ! [ -z "$(cat /etc/apache2/conf-available/security.conf | grep -E '^ServerSignature')" ]; then
		sed -i "/^ServerSignature/s/ServerSignature.*$/ServerSignature Off/g" /etc/apache2/conf-available/security.conf
	else
		echo "ServerSignature Off" >> /etc/apache2/conf-available/security.conf
	fi
	if ! [ -z "$(cat /etc/apache2/conf-available/security.conf | grep -E '^ServerTokens')" ]; then
		sed -i "/^ServerTokens/s/ServerTokens.*$/ServerTokens Prod/g" /etc/apache2/conf-available/security.conf
	else
		echo "ServerTokens Prod" >> /etc/apache2/conf-available/security.conf
	fi
fi

cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:80>
    # The ServerName directive sets the request scheme, hostname and port that
    # the server uses to identify itself. This is used when creating
    # redirection URLs. In the context of virtual hosts, the ServerName
    # specifies what hostname must appear in the request's Host: header to
    # match this virtual host. For the default virtual host (this file) this
    # value is not decisive as it is used as a last resort host regardless.
    # However, you must set it for any further virtual host explicitly.
    # ServerName www.example.com
    
            ServerAdmin webmaster@localhost
            DocumentRoot /var/www/html
            AddDefaultCharset utf-8
    		
            <Directory /var/www/html>
                    Options FollowSymLinks
                    AllowOverride All
                    Order deny,allow
                    Allow From All
                    Require all granted
            </Directory>
            
    # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
    # error, crit, alert, emerg.
    # It is also possible to configure the loglevel for particular
    # modules, e.g.
    #LogLevel info ssl:warn
    
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    
    # For most configuration files from conf-available/, which are
    # enabled or disabled at a global level, it is possible to
    # include a line for only one particular virtual host. For example the
    # following line enables the CGI configuration for this host only
    # after it has been globally disabled with "a2disconf".
    #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

echo "Перезапускаем Apache"
service apache2 restart > /dev/null 2>&1

echo "Web сервер Apache `apachectl -v | grep -a 'Server version:' | sed -e "s/^.*\///g"` успешно установлен"

