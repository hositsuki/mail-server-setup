# 个人邮件服务器一键部署脚本

这个项目包含两个脚本，用于在Debian/Ubuntu服务器上快速部署个人邮件服务器。支持Windows和Linux系统运行部署脚本。

## 前提条件

1. 一个运行Debian/Ubuntu的服务器（推荐Ubuntu 20.04或更新版本）
2. 一个已注册的域名
3. 能够修改域名DNS记录的权限
4. 服务器的25、80、443、587、993和995端口必须开放

## 使用方法

### Windows用户

1. 确保您的系统已安装PowerShell（Windows 10和11默认已安装）
2. 下载`setup_mail_server_windows.ps1`脚本
3. 打开PowerShell，切换到脚本所在目录
4. 运行脚本：
   ```powershell
   .\setup_mail_server_windows.ps1
   ```
5. 根据提示输入以下信息：
   - 服务器IP地址
   - SSH用户名
   - SSH密码
   - 域名

### Linux用户

1. 下载`setup_mail_server_linux.sh`脚本
2. 给脚本添加执行权限：
   ```bash
   chmod +x setup_mail_server_linux.sh
   ```
3. 以root权限运行脚本：
   ```bash
   sudo ./setup_mail_server_linux.sh
   ```
4. 根据提示输入以下信息：
   - 服务器IP地址
   - SSH用户名
   - SSH密码
   - 域名

## 脚本功能

脚本会自动完成以下配置：

1. 更新系统包
2. 设置正确的主机名
3. 安装必要的软件包（Postfix、Dovecot、Certbot、Nginx）
4. 配置Postfix邮件服务器
5. 配置Dovecot邮件投递代理
6. 获取并配置SSL证书
7. 创建默认管理员账户
8. 配置所有必要的安全设置

## 部署后配置

脚本运行完成后，您需要：

1. 在域名管理面板中添加以下DNS记录：
   - A记录：`mail.yourdomain.com` -> 您的服务器IP
   - MX记录：`@` -> `mail.yourdomain.com` (优先级：10)
   - SPF记录 (TXT)：`@` -> `v=spf1 mx -all`
   - DMARC记录 (TXT)：`_dmarc` -> `v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com`

2. 等待DNS记录生效（通常需要几分钟到几小时不等）

## 默认配置

- 管理员账户：
  - 用户名：admin
  - 密码：Admin123!@#

- 邮件客户端配置：
  - IMAP：mail.yourdomain.com:993 (SSL/TLS)
  - SMTP：mail.yourdomain.com:587 (STARTTLS)
  - POP3：mail.yourdomain.com:995 (SSL/TLS)

## 安全建议

1. 部署完成后立即修改默认管理员密码
2. 定期更新系统和软件包
3. 监控服务器日志以防滥用
4. 考虑配置防火墙规则
5. 定期备份邮件数据

## 故障排除

如果遇到问题，请检查：

1. 所有必需的端口是否开放
2. DNS记录是否正确配置
3. SSL证书是否成功获取
4. 查看日志文件：
   - Postfix日志：`/var/log/mail.log`
   - Dovecot日志：`/var/log/dovecot.log`
   - 系统日志：`/var/log/syslog`

## 注意事项

1. 此脚本适用于个人或小型组织使用
2. 确保服务器有足够的存储空间
3. 建议在防火墙后面运行邮件服务器
4. 定期监控垃圾邮件和服务器负载

## 许可证

MIT License
