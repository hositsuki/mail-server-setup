#!/bin/bash

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以root权限运行此脚本"
    exit 1
fi

# 获取参数
DOMAIN_NAME=$1
ADMIN_EMAIL=$2

if [ -z "$DOMAIN_NAME" ] || [ -z "$ADMIN_EMAIL" ]; then
    echo "使用方法: $0 <域名> <管理员邮箱>"
    exit 1
fi

# 安装LAMP环境
echo "安装LAMP环境..."
apt update
apt install -y apache2 mariadb-server php php-{mysql,imap,json,curl,mbstring,xml,zip,gd}

# 配置MariaDB
echo "配置数据库..."
mysql_secure_installation

# 创建Roundcube数据库和用户
DB_NAME="roundcube"
DB_USER="roundcube"
DB_PASS=$(openssl rand -base64 12)

mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 下载和安装Roundcube
echo "安装Roundcube..."
cd /var/www/html
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.4/roundcubemail-1.6.4-complete.tar.gz
tar xzf roundcubemail-1.6.4-complete.tar.gz
mv roundcubemail-1.6.4 webmail
rm roundcubemail-1.6.4-complete.tar.gz
chown -R www-data:www-data webmail

# 配置Roundcube
cat > /var/www/html/webmail/config/config.inc.php << EOL
<?php
\$config['db_dsnw'] = 'mysql://$DB_USER:$DB_PASS@localhost/$DB_NAME';
\$config['default_host'] = 'localhost';
\$config['smtp_server'] = 'localhost';
\$config['smtp_port'] = 587;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['support_url'] = 'mailto:$ADMIN_EMAIL';
\$config['product_name'] = '$DOMAIN_NAME Webmail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = array(
    'archive',
    'zipdownload',
    'managesieve',
    'password',
    'newmail_notifier',
    'identities',
);
\$config['language'] = 'zh_CN';
\$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);
\$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);
EOL

# 配置Apache虚拟主机
cat > /etc/apache2/sites-available/webmail.conf << EOL
<VirtualHost *:80>
    ServerName mail.$DOMAIN_NAME
    DocumentRoot /var/www/html/webmail
    ErrorLog \${APACHE_LOG_DIR}/webmail_error.log
    CustomLog \${APACHE_LOG_DIR}/webmail_access.log combined

    <Directory /var/www/html/webmail>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# 启用Apache配置
a2ensite webmail.conf
a2enmod rewrite
systemctl restart apache2

# 配置SSL
certbot --apache -d mail.$DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL

# 安装管理工具
echo "安装管理工具..."
apt install -y postfixadmin

# 配置PostfixAdmin
cat > /etc/postfixadmin/config.local.php << EOL
<?php
\$CONF['configured'] = true;
\$CONF['database_type'] = 'mysqli';
\$CONF['database_host'] = 'localhost';
\$CONF['database_user'] = '$DB_USER';
\$CONF['database_password'] = '$DB_PASS';
\$CONF['database_name'] = '$DB_NAME';
\$CONF['admin_email'] = '$ADMIN_EMAIL';
\$CONF['domain_path'] = 'YES';
\$CONF['domain_in_mailbox'] = 'NO';
\$CONF['fetchmail'] = 'YES';
\$CONF['sendmail'] = 'YES';
EOL

# 设置权限
chown -R www-data:www-data /etc/postfixadmin

echo "Webmail和管理界面安装完成！"
echo "Webmail地址: https://mail.$DOMAIN_NAME/webmail"
echo "管理界面地址: https://mail.$DOMAIN_NAME/postfixadmin"
echo "数据库信息已保存到 /root/.mail_credentials"

# 保存凭据
echo "Database Name: $DB_NAME" > /root/.mail_credentials
echo "Database User: $DB_USER" >> /root/.mail_credentials
echo "Database Password: $DB_PASS" >> /root/.mail_credentials
