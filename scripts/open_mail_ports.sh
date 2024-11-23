#!/bin/bash

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以root权限运行此脚本"
    exit 1
fi

# 备份当前的iptables规则
iptables-save > /root/iptables_backup_$(date +%Y%m%d_%H%M%S).rules

# 开放邮件服务器必要端口
echo "开放邮件服务器端口..."

# SMTP
iptables -A INPUT -p tcp --dport 25 -j ACCEPT
# Secure SMTP (SMTPS)
iptables -A INPUT -p tcp --dport 465 -j ACCEPT
# Submission
iptables -A INPUT -p tcp --dport 587 -j ACCEPT

# 保存iptables规则
if command -v iptables-save >/dev/null 2>&1; then
    case "$(lsb_release -si)" in
        "Ubuntu"|"Debian")
            iptables-save > /etc/iptables/rules.v4
            ;;
        "CentOS"|"RedHat"|"Fedora")
            service iptables save
            ;;
        *)
            iptables-save > /etc/sysconfig/iptables
            ;;
    esac
fi

# 检查端口是否开放
echo "检查端口状态..."
for port in 25 465 587; do
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo "端口 $port 已开放并正在监听"
    else
        echo "警告：端口 $port 未在监听"
    fi
done

# 检查postfix状态
echo "检查Postfix状态..."
systemctl status postfix

echo "
邮件服务器端口已开放：
- 端口 25 (SMTP)
- 端口 465 (SMTPS)
- 端口 587 (Submission)

如果端口仍然无法访问，请检查：
1. 云服务器安全组设置
2. 服务器提供商的防火墙设置
3. Postfix配置是否正确
"
