# 私人邮件服务器搭建指南

本项目提供了自动化脚本和详细指南，帮助您快速搭建一个完整的私人邮件服务器系统。支持在Windows和Linux环境下部署，并包含了完整的安全配置和防火墙规则。

## 主要功能

- 自动安装和配置邮件服务器（Postfix + Dovecot）
- 自动配置SSL证书（Let's Encrypt）
- 配置垃圾邮件过滤（SpamAssassin）
- 设置邮件认证（DKIM、SPF、DMARC）
- 配置防火墙规则
- 支持多种邮件协议（SMTP、IMAP、POP3）及其加密版本

## 快速开始

### Windows环境部署

1. 确保您的系统已安装PowerShell（Windows 10和11默认已安装）
2. 下载`setup_mail_server_windows.ps1`脚本
3. 打开PowerShell，切换到脚本所在目录
4. 运行脚本：
   ```powershell
   .\setup_mail_server_windows.ps1
   ```

### Linux环境部署

1. 下载`setup_mail_server_linux.sh`脚本
2. 添加执行权限：
   ```bash
   chmod +x setup_mail_server_linux.sh
   ```
3. 以root权限运行：
   ```bash
   sudo ./setup_mail_server_linux.sh
   ```

## 系统要求

### 硬件配置
- CPU：2核心及以上
- 内存：4GB及以上
- 存储：50GB及以上（取决于预期邮件存储量）
- 网络：固定IP地址

### 软件要求
- 操作系统：
  - Windows：Windows 10/11 或 Windows Server 2019/2022
  - Linux：Ubuntu 22.04 LTS / Debian 11 或更高版本
- 必需的开放端口：
  - SMTP：25（标准邮件传输）
  - SMTPS：465（加密邮件传输）
  - Submission：587（邮件客户端提交）
  - IMAP：143（标准邮件收取）
  - IMAPS：993（加密邮件收取）
  - POP3：110（标准邮件下载）
  - POP3S：995（加密邮件下载）
  - HTTP：80（网页访问）
  - HTTPS：443（加密网页访问）

## 自动安装的组件

- Postfix：邮件传输服务器
- Dovecot：邮件接收服务器
- Nginx：网页服务器
- Certbot：SSL证书管理
- SpamAssassin：垃圾邮件过滤
- OpenDKIM：邮件认证系统

## 安装后配置

详细的安装后配置步骤请参考 [mail_server_setup_readme.md](./mail_server_setup_readme.md)，包括：

1. DNS记录配置
2. 邮件客户端设置
3. 安全配置
4. 日常维护指南

## 安全建议

1. 及时更新系统和相关软件包
2. 定期检查服务器日志
3. 配置强密码策略
4. 启用防火墙规则
5. 定期备份邮件数据
6. 监控服务器状态

## 常见问题

如果遇到问题，请：

1. 检查服务器日志
2. 验证DNS配置
3. 确认端口开放状态
4. 检查SSL证书状态
5. 查看防火墙规则

## 技术支持

如需帮助，请：

1. 查看详细文档：[mail_server_setup_readme.md](./mail_server_setup_readme.md)
2. 提交Issues，并附上：
   - 错误日志
   - 系统信息
   - 问题描述
   - 复现步骤

## 许可证

本项目采用 MIT 许可证，详情请参见 [LICENSE](./LICENSE) 文件。
