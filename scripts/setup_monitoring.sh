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

# 安装监控工具
echo "安装监控工具..."
apt update
apt install -y prometheus node-exporter prometheus-pushgateway grafana

# 配置Prometheus
cat > /etc/prometheus/prometheus.yml << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]

  - job_name: "pushgateway"
    honor_labels: true
    static_configs:
      - targets: ["localhost:9091"]
EOL

# 配置Grafana
cat > /etc/grafana/provisioning/datasources/prometheus.yml << EOL
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOL

# 创建监控脚本
cat > /usr/local/bin/mail_monitor.sh << 'EOL'
#!/bin/bash

# 检查邮件队列
QUEUE_SIZE=$(mailq | grep -c "^[A-F0-9]")
echo "mail_queue_size $QUEUE_SIZE" | curl --data-binary @- http://localhost:9091/metrics/job/postfix/instance/queue

# 检查磁盘使用率
DISK_USAGE=$(df /var/mail | awk 'NR==2 {print $5}' | sed 's/%//')
echo "mail_disk_usage $DISK_USAGE" | curl --data-binary @- http://localhost:9091/metrics/job/postfix/instance/disk

# 检查IMAP连接数
IMAP_CONN=$(netstat -an | grep :993 | grep ESTABLISHED | wc -l)
echo "mail_imap_connections $IMAP_CONN" | curl --data-binary @- http://localhost:9091/metrics/job/postfix/instance/imap

# 检查SMTP连接数
SMTP_CONN=$(netstat -an | grep :587 | grep ESTABLISHED | wc -l)
echo "mail_smtp_connections $SMTP_CONN" | curl --data-binary @- http://localhost:9091/metrics/job/postfix/instance/smtp

# 检查日志错误
ERROR_COUNT=$(grep -c "error\|warning" /var/log/mail.log)
echo "mail_log_errors $ERROR_COUNT" | curl --data-binary @- http://localhost:9091/metrics/job/postfix/instance/logs
EOL

chmod +x /usr/local/bin/mail_monitor.sh

# 添加定时任务
echo "*/5 * * * * root /usr/local/bin/mail_monitor.sh" > /etc/cron.d/mail_monitor

# 创建备份脚本
cat > /usr/local/bin/mail_backup.sh << 'EOL'
#!/bin/bash

BACKUP_DIR="/var/backups/mail"
DATE=$(date +%Y%m%d)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份邮件数据
tar -czf $BACKUP_DIR/mail_$DATE.tar.gz /var/mail

# 备份数据库
mysqldump --all-databases | gzip > $BACKUP_DIR/databases_$DATE.sql.gz

# 备份配置文件
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /etc/postfix /etc/dovecot

# 删除7天前的备份
find $BACKUP_DIR -type f -mtime +7 -delete
EOL

chmod +x /usr/local/bin/mail_backup.sh

# 添加备份定时任务
echo "0 2 * * * root /usr/local/bin/mail_backup.sh" > /etc/cron.d/mail_backup

# 创建日志轮转配置
cat > /etc/logrotate.d/mail_server << EOL
/var/log/mail.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 syslog adm
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOL

# 启动服务
systemctl restart prometheus
systemctl restart node-exporter
systemctl restart prometheus-pushgateway
systemctl restart grafana-server

# 配置防火墙（如果启用）
ufw allow 3000/tcp  # Grafana
ufw allow 9090/tcp  # Prometheus
ufw allow 9100/tcp  # Node Exporter
ufw allow 9091/tcp  # Pushgateway

echo "监控系统安装完成！"
echo "Grafana 访问地址: http://mail.$DOMAIN_NAME:3000"
echo "默认用户名: admin"
echo "默认密码: admin"
echo "请立即修改默认密码！"

# 创建基本告警规则
cat > /etc/prometheus/rules/mail_alerts.yml << EOL
groups:
- name: mail_alerts
  rules:
  - alert: HighMailQueue
    expr: mail_queue_size > 100
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "邮件队列堆积"
      description: "邮件队列中有超过100封邮件等待发送"

  - alert: DiskSpaceLow
    expr: mail_disk_usage > 80
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "磁盘空间不足"
      description: "邮件存储空间使用率超过80%"

  - alert: HighErrorRate
    expr: rate(mail_log_errors[5m]) > 10
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "错误日志频率过高"
      description: "5分钟内出现超过10个错误日志"
EOL

# 重启Prometheus以加载告警规则
systemctl restart prometheus
