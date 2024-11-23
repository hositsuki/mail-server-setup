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

# 安装SpamAssassin
echo "安装SpamAssassin..."
apt update
apt install -y spamassassin spamc

# 启用SpamAssassin服务
systemctl enable spamassassin
systemctl start spamassassin

# 创建SpamAssassin用户
adduser --system --home /var/lib/spamassassin --disabled-login --shell /bin/false spamd

# 配置SpamAssassin
cat > /etc/spamassassin/local.cf << EOL
# 基本设置
required_score 5.0
use_bayes 1
bayes_auto_learn 1
report_safe 0

# 中文支持
ok_languages zh en
ok_locales zh en

# 自动白名单
use_auto_whitelist 1

# 垃圾邮件主题标记
rewrite_header Subject [SPAM]

# RBL检查
score URIBL_BLACK 7.5
score URIBL_DBL_SPAM 7.5
score SURBL_MULTI 7.5

# 启用插件
loadplugin Mail::SpamAssassin::Plugin::SPF
loadplugin Mail::SpamAssassin::Plugin::URIDNSBL
loadplugin Mail::SpamAssassin::Plugin::Shortcircuit

# 自定义规则
body LOCAL_VIAGRA_SPAM    /viagra|cialis/i
describe LOCAL_VIAGRA_SPAM 药品垃圾邮件
score LOCAL_VIAGRA_SPAM    5.0

body LOCAL_CASINO_SPAM    /casino|gambling|bet now/i
describe LOCAL_CASINO_SPAM 赌博垃圾邮件
score LOCAL_CASINO_SPAM    5.0

# 白名单域名
whitelist_from *@$DOMAIN_NAME
EOL

# 配置Postfix使用SpamAssassin
cat >> /etc/postfix/master.cf << EOL

# SpamAssassin
spamassassin unix -     n       n       -       -       pipe
  user=spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f \${sender} \${recipient}
EOL

# 修改Postfix main.cf
cat >> /etc/postfix/main.cf << EOL

# SpamAssassin配置
content_filter = spamassassin
EOL

# 创建学习脚本
cat > /usr/local/bin/learn_spam.sh << 'EOL'
#!/bin/bash

# 学习垃圾邮件
sa-learn --spam /var/mail/spam/*
# 学习正常邮件
sa-learn --ham /var/mail/ham/*
# 同步数据库
sa-learn --sync
EOL

chmod +x /usr/local/bin/learn_spam.sh

# 添加定时任务每天学习一次
echo "0 3 * * * root /usr/local/bin/learn_spam.sh" > /etc/cron.d/spamassassin_learn

# 创建垃圾邮件和正常邮件文件夹
mkdir -p /var/mail/{spam,ham}
chown -R vmail:vmail /var/mail/{spam,ham}

# 重启服务
systemctl restart spamassassin
systemctl restart postfix

# 添加到监控系统
cat >> /usr/local/bin/mail_monitor.sh << 'EOL'

# 检查SpamAssassin状态
if systemctl is-active --quiet spamassassin; then
    echo "spamassassin_status 1" | curl --data-binary @- http://localhost:9091/metrics/job/mail/instance/spam
else
    echo "spamassassin_status 0" | curl --data-binary @- http://localhost:9091/metrics/job/mail/instance/spam
fi

# 检查垃圾邮件数量
SPAM_COUNT=$(find /var/mail/spam -type f | wc -l)
echo "spam_mail_count $SPAM_COUNT" | curl --data-binary @- http://localhost:9091/metrics/job/mail/instance/spam
EOL

# 添加Prometheus告警规则
cat >> /etc/prometheus/rules/mail_alerts.yml << EOL

  - alert: SpamAssassinDown
    expr: spamassassin_status == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "SpamAssassin服务停止运行"
      description: "SpamAssassin服务已经停止运行，需要立即检查"

  - alert: HighSpamRate
    expr: rate(spam_mail_count[1h]) > 100
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "垃圾邮件数量异常"
      description: "过去1小时内收到了大量垃圾邮件，可能需要调整过滤规则"
EOL

# 重启Prometheus以加载新规则
systemctl restart prometheus

echo "SpamAssassin安装和配置完成！"
echo "
垃圾邮件过滤功能已启用：
1. 基本过滤规则已配置
2. 自动学习功能已启用
3. 监控和告警已配置
4. 每天凌晨3点自动学习新的垃圾邮件特征

使用说明：
1. 将确认的垃圾邮件移动到 /var/mail/spam/ 目录
2. 将误判的正常邮件移动到 /var/mail/ham/ 目录
3. 系统会自动学习这些邮件的特征
4. 可以通过Grafana监控垃圾邮件的数量和过滤效果

配置文件位置：
- SpamAssassin配置：/etc/spamassassin/local.cf
- 学习脚本：/usr/local/bin/learn_spam.sh
"
