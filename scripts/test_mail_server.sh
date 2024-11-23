#!/bin/bash

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以root权限运行此脚本"
    exit 1
fi

# 获取参数
DOMAIN_NAME=$1
TEST_EMAIL=$2

if [ -z "$DOMAIN_NAME" ] || [ -z "$TEST_EMAIL" ]; then
    echo "使用方法: $0 <域名> <测试邮箱>"
    exit 1
fi

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试函数
test_service() {
    local service=$1
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}[✓] $service 服务运行正常${NC}"
        return 0
    else
        echo -e "${RED}[✗] $service 服务未运行${NC}"
        return 1
    fi
}

test_port() {
    local port=$1
    local service=$2
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo -e "${GREEN}[✓] $service 端口 $port 正常监听${NC}"
        return 0
    else
        echo -e "${RED}[✗] $service 端口 $port 未监听${NC}"
        return 1
    fi
}

test_certificate() {
    local domain=$1
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/fullchain.pem" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local now_epoch=$(date +%s)
        local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
        
        if [ $days_left -gt 0 ]; then
            echo -e "${GREEN}[✓] SSL证书有效，还有 $days_left 天过期${NC}"
            return 0
        else
            echo -e "${RED}[✗] SSL证书已过期${NC}"
            return 1
        fi
    else
        echo -e "${RED}[✗] SSL证书文件不存在${NC}"
        return 1
    fi
}

send_test_email() {
    local to_email=$1
    local subject="邮件服务器测试 - $(date '+%Y-%m-%d %H:%M:%S')"
    local body="这是一封测试邮件，用于验证邮件服务器功能。\n\n发送时间: $(date '+%Y-%m-%d %H:%M:%S')\n服务器: $HOSTNAME"
    
    echo -e "$body" | mail -s "$subject" "$to_email"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] 测试邮件已发送到 $to_email${NC}"
        return 0
    else
        echo -e "${RED}[✗] 测试邮件发送失败${NC}"
        return 1
    fi
}

check_mail_queue() {
    local queue_size=$(mailq | grep -c "^[A-F0-9]")
    if [ $queue_size -eq 0 ]; then
        echo -e "${GREEN}[✓] 邮件队列为空${NC}"
        return 0
    else
        echo -e "${RED}[✗] 邮件队列中有 $queue_size 封邮件待处理${NC}"
        return 1
    fi
}

check_dns_records() {
    local domain=$1
    local records=("MX" "SPF" "DKIM" "DMARC")
    local all_ok=true

    for record in "${records[@]}"; do
        case $record in
            "MX")
                if host -t MX $domain > /dev/null; then
                    echo -e "${GREEN}[✓] MX记录配置正确${NC}"
                else
                    echo -e "${RED}[✗] MX记录未找到${NC}"
                    all_ok=false
                fi
                ;;
            "SPF")
                if host -t TXT $domain | grep "v=spf1" > /dev/null; then
                    echo -e "${GREEN}[✓] SPF记录配置正确${NC}"
                else
                    echo -e "${RED}[✗] SPF记录未找到${NC}"
                    all_ok=false
                fi
                ;;
            "DKIM")
                if host -t TXT "mail._domainkey.$domain" > /dev/null; then
                    echo -e "${GREEN}[✓] DKIM记录配置正确${NC}"
                else
                    echo -e "${RED}[✗] DKIM记录未找到${NC}"
                    all_ok=false
                fi
                ;;
            "DMARC")
                if host -t TXT "_dmarc.$domain" > /dev/null; then
                    echo -e "${GREEN}[✓] DMARC记录配置正确${NC}"
                else
                    echo -e "${RED}[✗] DMARC记录未找到${NC}"
                    all_ok=false
                fi
                ;;
        esac
    done

    return $all_ok
}

# 开始测试
echo "开始测试邮件服务器..."
echo "域名: $DOMAIN_NAME"
echo "测试邮箱: $TEST_EMAIL"
echo "----------------------------------------"

# 1. 检查核心服务
echo "1. 检查核心服务状态"
test_service postfix
test_service dovecot
test_service nginx
test_service opendkim
test_service spamassassin
echo

# 2. 检查端口
echo "2. 检查服务端口"
test_port 25 "SMTP"
test_port 465 "SMTPS"
test_port 587 "Submission"
test_port 993 "IMAPS"
test_port 995 "POP3S"
echo

# 3. 检查SSL证书
echo "3. 检查SSL证书"
test_certificate $DOMAIN_NAME
echo

# 4. 检查DNS记录
echo "4. 检查DNS记录"
check_dns_records $DOMAIN_NAME
echo

# 5. 检查邮件队列
echo "5. 检查邮件队列"
check_mail_queue
echo

# 6. 发送测试邮件
echo "6. 发送测试邮件"
send_test_email $TEST_EMAIL
echo

# 7. 检查日志错误
echo "7. 检查最近的错误日志"
echo "Postfix 错误:"
grep "error\|warning" /var/log/mail.log | tail -n 5
echo
echo "Dovecot 错误:"
grep "Error\|Warning" /var/log/dovecot.log | tail -n 5
echo

echo "----------------------------------------"
echo "测试完成！"
echo "如果发现任何问题，请检查相应的服务配置和日志文件。"
echo "建议发送测试邮件到 check-auth@verifier.port25.com 获取详细的邮件认证报告。"
