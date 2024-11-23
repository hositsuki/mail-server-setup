# 私人邮件服务器搭建指南

本项目提供了自动化脚本和详细指南，帮助您快速搭建一个完整的私人邮件服务器系统。

## 快速开始

### 使用自动化脚本（推荐）

#### Windows用户
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

#### Linux用户
1. 下载`setup_mail_server_linux.sh`脚本
2. 给脚本添加执行权限：
   ```bash
   chmod +x setup_mail_server_linux.sh
   ```
3. 以root权限运行脚本：
   ```bash
   sudo ./setup_mail_server_linux.sh
   ```
4. 根据提示输入相关信息

### 手动安装（适合高级用户）

## 系统要求

### 硬件要求
- CPU: 2核心及以上
- 内存: 4GB及以上
- 硬盘: 50GB及以上（取决于预期邮件存储量）
- 网络: 固定IP地址，良好的网络连接
- 必需的开放端口：25、80、443、587、993和995

### 软件要求
- 操作系统: Ubuntu Server 22.04 LTS / Debian 11或更新版本
- 自动安装的组件：
  - 邮件服务: Postfix + Dovecot
  - SSL证书: Let's Encrypt (Certbot)
  - Web服务器: Nginx

## 自动化脚本功能

脚本会自动完成以下配置：

1. 系统更新和必要软件安装
2. 主机名配置
3. Postfix邮件服务器配置
   - SMTP认证
   - TLS加密
   - 反垃圾邮件设置
4. Dovecot配置
   - 邮件存储
   - 用户认证
   - SSL/TLS加密
5. SSL证书自动获取和配置
6. 创建默认管理员账户
7. 基本安全设置

## 部署后配置

脚本运行完成后，您需要：

1. 在域名管理面板中添加以下DNS记录：
   ```
   # A记录
   mail IN A your.server.ip.address

   # MX记录
   @ IN MX 10 mail.yourdomain.com.

   # SPF记录
   @ IN TXT "v=spf1 mx -all"

   # DMARC记录
   _dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com"
   ```

2. 修改默认管理员密码（默认账户：admin/Admin123!@#）

3. 配置邮件客户端：
   - IMAP: mail.yourdomain.com:993 (SSL/TLS)
   - SMTP: mail.yourdomain.com:587 (STARTTLS)
   - POP3: mail.yourdomain.com:995 (SSL/TLS)

## 项目结构

```
.
├── README.md                     # 项目说明文档
├── setup_mail_server_windows.ps1 # Windows部署脚本
├── setup_mail_server_linux.sh    # Linux部署脚本
└── docs/
    └── manual_setup.md          # 手动安装指南
```

## 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本项目
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 作者

- YukiSayu - *初始工作* - [YukiSayu](https://github.com/YukiSayu)

## 致谢

- 感谢所有为这个项目做出贡献的开发者
- 特别感谢 Postfix、Dovecot 和其他开源项目的开发者

## 免责声明

本项目仅供学习和个人使用。在将此邮件服务器用于生产环境之前，请确保：

1. 遵守所有相关法律法规
2. 实施适当的安全措施
3. 定期备份重要数据
4. 监控服务器状态

作者不对使用本项目造成的任何损失负责。

## 维护建议

1. 定期备份
   - 邮件数据
   - 配置文件
   - 用户数据

2. 安全更新
   - 定期更新系统
   - 监控安全公告
   - 检查日志文件

3. 性能监控
   - 监控磁盘使用
   - 检查邮件队列
   - 监控系统资源

## 故障排除

常见问题及解决方案：
1. 邮件发送失败
   - 检查DNS记录
   - 验证SSL证书
   - 检查防火墙设置

2. 垃圾邮件问题
   - 调整SpamAssassin规则
   - 检查黑名单状态
   - 更新反垃圾邮件规则

3. 性能问题
   - 检查系统资源使用
   - 优化配置参数
   - 清理旧邮件和日志

## 注意事项

1. 安全性
   - 使用强密码
   - 定期更新系统
   - 启用双因素认证
   - 限制登录失败次数

2. 合规性
   - 遵守相关法律法规
   - 实施适当的数据保留政策
   - 保护用户隐私

3. 维护
   - 定期备份
   - 监控系统状态
   - 及时处理问题
