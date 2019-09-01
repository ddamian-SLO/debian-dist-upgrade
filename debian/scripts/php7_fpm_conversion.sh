#!/bin/bash
APACHE_SITES_ENABLED="/etc/apache2/sites-enabled/"

function php_fpm_config_gen () {
    cd ${APACHE_SITES_ENABLED}
    for vhost in ${APACHE_SITES_ENABLED}/*; do
        user=$(grep -i SuexecUserGroup ${vhost} | awk '{ print $2 }' | uniq);
        group=$(grep -i SuexecUserGroup ${vhost} | awk '{ print $3 }' | uniq);
        site=$(grep -i ServerName ${vhost} | awk '{ print $2 }' | uniq);
        printf "\t<FilesMatch \"\\.php$\">\n\t\tSetHandler \"proxy:unix:/var/run/php-fpm_${site}.sock|fcgi://localhost\"\n\t</FilesMatch>\n" > ${php_fpm_handler_config}

        echo "[${site}]
user = ${user}
group = ${group}
listen = /var/run/php-fpm_${site}.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 20
pm.start_servers = 6
pm.min_spare_servers = 1
pm.max_spare_servers = 8
pm.max_requests = 100
chdir = /" > ${php_fpm_root}/${site}.conf

        # Insert FilesMatch syntax above VirtualHost
        awk '/^<\/VirtualHost>$/ {
        system("cat /root/upgrades/php7.0_handler.txt") }; { print } ' ${vhost} > tmp-${site}.conf 
        cp tmp-${site} ${vhost}
    done
}

function php_convert_main () {
    if [[ "$(dpkg -l | grep ii | awk '{ print $2 }' | grep php7\.3)" ]]; then 
        php_fpm_root="/etc/php/7.3/fpm/pool.d"
        php_fpm_handler_config="/root/upgrades/php7.3_handler_config"
        if [[ -d "/etc/php/7.0/fpm/pool.d" ]]; then
            cd /etc/php/7.0/fpm/pool.d
            for conf in /etc/php/7.0/fpm/pool.d/*.conf; do 
                mv ${conf} ${php_fpm_root}/${conf}
            done
            systemctl stop php7.0-fpm 
            systemctl start php7.3-fpm
        else
            php_fpm_config_gen
        fi
    elif [[ "$(dpkg -l | grep ii | awk '{ print $2 }' | grep php7\.0)" ]]; then
        php_fpm_root="/etc/php/7.0/fpm/pool.d"
        php_fpm_handler_config="/root/upgrades/php7.0_handler_config"
        php_fpm_config_gen
    else
        echo "No PHP instances installed"
        exit 1
}

#### MAIN #####
php_convert_main