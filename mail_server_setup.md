# Ubuntu 邮件服务器搭建教程

## 1. 系统准备
```bash
# 更新系统
apt update
apt upgrade -y

# 设置正确的主机名（替换 mail.yourdomain.com 为您的域名）
hostnamectl set-hostname mail.yourdomain.com
```

## 2. 安装必要软件
```bash
# 安装邮件服务器软件包
apt install -y postfix dovecot-imapd dovecot-pop3d

# 安装其他工具
apt install -y certbot python3-certbot-nginx nginx spamassassin opendkim opendkim-tools
```

## 3. Postfix 基础配置
编辑 /etc/postfix/main.cf：
```bash
# 备份原配置
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak

# 编辑配置文件
nano /etc/postfix/main.cf
```

添加/修改以下内容：
```
# 基本设置
myhostname = mail.yourdomain.com
mydomain = yourdomain.com
myorigin = $mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# TLS 设置
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.yourdomain.com/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.yourdomain.com/privkey.pem
smtpd_use_tls=yes
smtpd_tls_auth_only = yes

# 认证设置
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes

# 限制设置
smtpd_recipient_restrictions =
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination

# 大小限制
message_size_limit = 52428800  # 50MB
mailbox_size_limit = 1073741824  # 1GB
```

## 4. Dovecot 配置
### 4.1 主配置（/etc/dovecot/dovecot.conf）
```bash
nano /etc/dovecot/dovecot.conf
```
添加：
```
protocols = imap pop3
```

### 4.2 邮件位置配置（/etc/dovecot/conf.d/10-mail.conf）
```bash
nano /etc/dovecot/conf.d/10-mail.conf
```
修改：
```
mail_location = maildir:/var/mail/vhosts/%d/%n
```

### 4.3 SSL配置（/etc/dovecot/conf.d/10-ssl.conf）
```bash
nano /etc/dovecot/conf.d/10-ssl.conf
```
修改：
```
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.yourdomain.com/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.yourdomain.com/privkey.pem
```

## 5. SSL 证书设置
```bash
# 获取SSL证书
certbot --nginx -d mail.yourdomain.com

# 确保证书自动更新
systemctl enable certbot.timer
systemctl start certbot.timer
```

## 6. 创建邮箱用户
```bash
# 创建邮件存储目录
mkdir -p /var/mail/vhosts/yourdomain.com

# 创建用户（替换username为实际用户名）
useradd -m username
passwd username
```

## 7. DNS 记录设置
在您的域名管理面板中添加以下DNS记录：

```
# MX记录
@ IN MX 10 mail.yourdomain.com.

# A记录
mail IN A 198.46.152.154

# SPF记录
@ IN TXT "v=spf1 mx -all"

# DMARC记录
_dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com"
```

## 8. 启动服务
```bash
# 重启服务
systemctl restart postfix
systemctl restart dovecot

# 设置开机自启
systemctl enable postfix
systemctl enable dovecot
```

## 9. 测试配置
```bash
# 检查Postfix配置
postfix check

# 检查端口是否开放
netstat -tuln | grep '25\|110\|143\|465\|587\|993\|995'
```

## 10. 防火墙设置
```bash
# 开放必要端口
ufw allow 25/tcp   # SMTP
ufw allow 465/tcp  # SMTPS
ufw allow 587/tcp  # Submission
ufw allow 110/tcp  # POP3
ufw allow 995/tcp  # POP3S
ufw allow 143/tcp  # IMAP
ufw allow 993/tcp  # IMAPS
```

## 常见问题排查

### 1. 检查服务状态
```bash
systemctl status postfix
systemctl status dovecot
```

### 2. 查看日志
```bash
tail -f /var/log/mail.log
```

### 3. 测试邮件发送
```bash
echo "Test mail" | mail -s "Test Subject" user@example.com
```

### 4. 检查端口
```bash
netstat -tuln | grep '25\|110\|143\|465\|587\|993\|995'
```

## 安全建议

1. 定期更新系统和软件包
2. 使用强密码
3. 监控日志文件
4. 定期备份邮件数据
5. 配置 SpamAssassin 进行垃圾邮件过滤
6. 启用 DKIM 签名

## 维护建议

1. 定期检查磁盘使用情况
2. 监控邮件队列
3. 检查日志中的异常情况
4. 定期更新SSL证书
5. 保持系统更新
