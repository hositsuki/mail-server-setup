param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainName
)

# 检查是否安装了PuTTY
$puttyPath = "C:\Program Files\PuTTY\plink.exe"
if (-not (Test-Path $puttyPath)) {
    Write-Host "正在安装 PuTTY..."
    winget install -e --id PuTTY.PuTTY
}

# 创建SSH命令函数
function Execute-SSH {
    param(
        [string]$command
    )
    & "$puttyPath" -ssh -batch -pw $Password "$Username@$ServerIP" $command
}

Write-Host "开始配置邮件服务器..."

# 1. 更新系统
Write-Host "1. 更新系统..."
Execute-SSH "apt update && apt upgrade -y"

# 2. 设置主机名
Write-Host "2. 设置主机名..."
Execute-SSH "hostnamectl set-hostname mail.$DomainName"

# 3. 安装必要软件
Write-Host "3. 安装必要软件..."
Execute-SSH @"
DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-imapd dovecot-pop3d certbot nginx
"@

# 4. 配置Postfix
Write-Host "4. 配置Postfix..."
$postfixConfig = @"
# 基本设置
myhostname = mail.$DomainName
mydomain = $DomainName
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
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.$DomainName/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/mail.$DomainName/privkey.pem

# 限制设置
smtpd_recipient_restrictions =
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination

# 大小限制
message_size_limit = 52428800
mailbox_size_limit = 1073741824

# 网络设置
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
"@

Execute-SSH "echo '$postfixConfig' > /etc/postfix/main.cf"

# 5. 配置Dovecot
Write-Host "5. 配置Dovecot..."
Execute-SSH @"
echo 'mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}' > /etc/dovecot/conf.d/10-mail.conf

echo 'disable_plaintext_auth = no
auth_mechanisms = plain login
!include auth-system.conf.ext' > /etc/dovecot/conf.d/10-auth.conf
"@

# 6. 获取SSL证书
Write-Host "6. 获取SSL证书..."
Execute-SSH @"
systemctl stop nginx
certbot certonly --standalone -d mail.$DomainName --non-interactive --agree-tos --email admin@$DomainName
"@

# 7. 配置SSL
Write-Host "7. 配置SSL..."
Execute-SSH @"
echo 'ssl = required
ssl_cert = </etc/letsencrypt/live/mail.$DomainName/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.$DomainName/privkey.pem
ssl_min_protocol = TLSv1.2' > /etc/dovecot/conf.d/10-ssl.conf
"@

# 8. 创建默认管理员账户
Write-Host "8. 创建管理员账户..."
Execute-SSH "useradd -m -s /bin/bash admin && echo 'admin:Admin123!@#' | chpasswd"

# 9. 重启服务
Write-Host "9. 重启服务..."
Execute-SSH "systemctl restart postfix && systemctl restart dovecot && systemctl start nginx"

Write-Host @"
邮件服务器配置完成！

请在您的DNS管理面板中添加以下记录：
1. A记录：
   mail.$DomainName -> $ServerIP

2. MX记录：
   @ -> mail.$DomainName (优先级：10)

3. SPF记录 (TXT记录)：
   @ -> "v=spf1 mx -all"

4. DMARC记录 (TXT记录)：
   _dmarc -> "v=DMARC1; p=quarantine; rua=mailto:admin@$DomainName"

默认管理员账户：
用户名：admin
密码：Admin123!@#

邮件客户端配置：
IMAP: mail.$DomainName:993 (SSL/TLS)
SMTP: mail.$DomainName:587 (STARTTLS)
POP3: mail.$DomainName:995 (SSL/TLS)
"@
