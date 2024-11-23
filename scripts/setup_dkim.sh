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

# 安装OpenDKIM
echo "安装OpenDKIM..."
apt update
apt install -y opendkim opendkim-tools

# 配置OpenDKIM
cat > /etc/opendkim.conf << EOL
# 基本设置
Syslog                  yes
UMask                   002
Canonicalization        relaxed/simple
Mode                    sv
SubDomains             no
AutoRestart             yes
AutoRestartRate         10/1h

# 签名选项
SignatureAlgorithm      rsa-sha256
SignHeaders             From,To,Subject,Date,Message-ID
OversignHeaders         From,To,Subject,Date,Message-ID

# 密钥文件
KeyTable                refile:/etc/opendkim/key.table
SigningTable           refile:/etc/opendkim/signing.table
ExternalIgnoreList     refile:/etc/opendkim/trusted.hosts
InternalHosts          refile:/etc/opendkim/trusted.hosts

# Socket设置
Socket                  local:/var/spool/postfix/opendkim/opendkim.sock
PidFile                /var/run/opendkim/opendkim.pid
EOL

# 创建必要的目录和文件
mkdir -p /etc/opendkim/keys/$DOMAIN_NAME
mkdir -p /var/spool/postfix/opendkim
chown -R opendkim:opendkim /etc/opendkim
chown -R opendkim:postfix /var/spool/postfix/opendkim

# 生成密钥
opendkim-genkey -b 2048 -d $DOMAIN_NAME -D /etc/opendkim/keys/$DOMAIN_NAME -s mail -v

# 配置签名表
echo "mail._domainkey.$DOMAIN_NAME $DOMAIN_NAME:mail:/etc/opendkim/keys/$DOMAIN_NAME/mail.private" > /etc/opendkim/key.table
echo "*@$DOMAIN_NAME mail._domainkey.$DOMAIN_NAME" > /etc/opendkim/signing.table

# 配置信任主机
cat > /etc/opendkim/trusted.hosts << EOL
127.0.0.1
localhost
$DOMAIN_NAME
mail.$DOMAIN_NAME
*.$DOMAIN_NAME
EOL

# 设置权限
chown -R opendkim:opendkim /etc/opendkim/keys
chmod -R 700 /etc/opendkim/keys

# 配置Postfix使用OpenDKIM
cat >> /etc/postfix/main.cf << EOL

# OpenDKIM配置
milter_protocol = 2
milter_default_action = accept
smtpd_milters = local:/var/spool/postfix/opendkim/opendkim.sock
non_smtpd_milters = \$smtpd_milters
EOL

# 重启服务
systemctl restart opendkim
systemctl restart postfix

# 添加到监控系统
cat >> /usr/local/bin/mail_monitor.sh << 'EOL'

# 检查OpenDKIM状态
if systemctl is-active --quiet opendkim; then
    echo "opendkim_status 1" | curl --data-binary @- http://localhost:9091/metrics/job/mail/instance/dkim
else
    echo "opendkim_status 0" | curl --data-binary @- http://localhost:9091/metrics/job/mail/instance/dkim
fi
EOL

# 添加Prometheus告警规则
cat >> /etc/prometheus/rules/mail_alerts.yml << EOL

  - alert: OpenDKIMDown
    expr: opendkim_status == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "OpenDKIM服务停止运行"
      description: "OpenDKIM服务已经停止运行，需要立即检查"
EOL

# 重启Prometheus以加载新规则
systemctl restart prometheus

# 获取DNS记录
DNS_RECORD=$(cat /etc/opendkim/keys/$DOMAIN_NAME/mail.txt)

echo "OpenDKIM安装和配置完成！"
echo "
请在您的DNS管理面板中添加以下TXT记录：

$DNS_RECORD

配置文件位置：
- OpenDKIM配置：/etc/opendkim.conf
- 密钥目录：/etc/opendkim/keys/$DOMAIN_NAME/

测试DKIM配置：
1. 发送测试邮件到 check-auth@verifier.port25.com
2. 您将收到一份详细的认证报告

注意：
1. DNS记录生效可能需要几分钟到几小时
2. 请确保密钥文件安全，不要泄露私钥
3. 建议定期轮换DKIM密钥（每年一次）
"
