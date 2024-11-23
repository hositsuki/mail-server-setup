#!/bin/bash

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以root权限运行此脚本"
    exit 1
fi

# 获取参数
read -p "请输入目标服务器IP: " SERVER_IP
read -p "请输入SSH用户名: " SSH_USER
read -s -p "请输入SSH密码: " SSH_PASS
echo ""
read -p "请输入您的域名(例如: example.com): " DOMAIN_NAME

# SSH命令函数
execute_ssh() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "$1"
}

echo "开始配置邮件服务器..."

# 1. 安装sshpass
apt update && apt install -y sshpass

# 2. 更新系统
echo "1. 更新系统..."
execute_ssh "apt update && apt upgrade -y"

# 3. 设置主机名
echo "2. 设置主机名..."
execute_ssh "hostnamectl set-hostname mail.$DOMAIN_NAME"

# 4. 安装必要软件
echo "3. 安装必要软件..."
execute_ssh "DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-imapd dovecot-pop3d certbot nginx"

# 5. 配置Postfix
echo "4. 配置Postfix..."
POSTFIX_CONFIG="# 基本设置
myhostname = mail.$DOMAIN_NAME
mydomain = $DOMAIN_NAME
myorigin = \$mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain

# 邮箱设置
home_mailbox = Maildir/

# SMTP认证
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname

# TLS设置
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.$DOMAIN_NAME/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/mail.$DOMAIN_NAME/privkey.pem

# 限制设置
smtpd_recipient_restrictions =
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination

# 大小限制
message_size_limit = 52428800
mailbox_size_limit = 1073741824

# 网络设置
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"

execute_ssh "echo '$POSTFIX_CONFIG' > /etc/postfix/main.cf"

# 6. 配置Dovecot
echo "5. 配置Dovecot..."
execute_ssh "echo 'mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}' > /etc/dovecot/conf.d/10-mail.conf"

execute_ssh "echo 'disable_plaintext_auth = no
auth_mechanisms = plain login
!include auth-system.conf.ext' > /etc/dovecot/conf.d/10-auth.conf"

# 7. 获取SSL证书
echo "6. 获取SSL证书..."
execute_ssh "systemctl stop nginx
certbot certonly --standalone -d mail.$DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME"

# 8. 配置SSL
echo "7. 配置SSL..."
execute_ssh "echo 'ssl = required
ssl_cert = </etc/letsencrypt/live/mail.$DOMAIN_NAME/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.$DOMAIN_NAME/privkey.pem
ssl_min_protocol = TLSv1.2' > /etc/dovecot/conf.d/10-ssl.conf"

# 9. 创建默认管理员账户
echo "8. 创建管理员账户..."
execute_ssh "useradd -m -s /bin/bash admin && echo 'admin:Admin123!@#' | chpasswd"

# 10. 重启服务
echo "9. 重启服务..."
execute_ssh "systemctl restart postfix && systemctl restart dovecot && systemctl start nginx"

cat << EOF
邮件服务器配置完成！

请在您的DNS管理面板中添加以下记录：
1. A记录：
   mail.$DOMAIN_NAME -> $SERVER_IP

2. MX记录：
   @ -> mail.$DOMAIN_NAME (优先级：10)

3. SPF记录 (TXT记录)：
   @ -> "v=spf1 mx -all"

4. DMARC记录 (TXT记录)：
   _dmarc -> "v=DMARC1; p=quarantine; rua=mailto:admin@$DOMAIN_NAME"

默认管理员账户：
用户名：admin
密码：Admin123!@#

邮件客户端配置：
IMAP: mail.$DOMAIN_NAME:993 (SSL/TLS)
SMTP: mail.$DOMAIN_NAME:587 (STARTTLS)
POP3: mail.$DOMAIN_NAME:995 (SSL/TLS)
EOF
