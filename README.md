# Caddy Management Script (Caddy 管理脚本)

![License](https://img.shields.io/github/license/SHINYUZ/Caddy?color=blue)
![Language](https://img.shields.io/badge/language-Bash-green)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Version](https://img.shields.io/badge/version-v1.3.1-orange)

这就一个功能强大、简单易用的 Caddy 一键管理脚本。专为 Linux VPS 设计，支持自动安装、配置反向代理、SSL 证书自动申请以及服务管理。

---

## ✨ 主要功能

- **🚀 智能安装**：自动检测系统架构 (AMD64/ARM64)，智能识别网络环境（IPv4/IPv6），自动选择最佳下载源。
- **🔄 反代管理**：交互式菜单，轻松添加、修改、查看、删除反向代理配置。
- **🔒 自动 HTTPS**：基于 Caddy 强大的自动 SSL 能力，配置后自动申请并续期证书。
- **⚡ 智能重载**：修改配置后自动判断服务状态，智能选择重载 (Reload) 或重启 (Restart)，确保持续运行。
- **🌍 IPv6 优化**：完美支持纯 IPv6 (IPv6-Only) 机器，解决 GitHub 官方源无法连接的问题。
- **⌨️ 快捷命令**：安装后输入 `ca` 即可随时唤出管理菜单。

---

## 🚀 安装 (Installation)

复制和执行以下命令：

```bash
wget -N --no-check-certificate "https://raw.githubusercontent.com/SHINYUZ/Caddy/main/caddy.sh" && chmod +x caddy.sh && ./caddy.sh
```
如果下载失败，请检查 VPS 的网络连接或 DNS 设置

使用镜像加速源下载：

```bash
wget -N --no-check-certificate https://ghproxy.net/https://raw.githubusercontent.com/SHINYUZ/Caddy/main/caddy.sh && chmod +x caddy.sh && sed -i 's|https://github.com|https://ghproxy.net/https://github.com|g' caddy.sh && sed -i 's|https://api.github.com|https://ghproxy.net/https://api.github.com|g' caddy.sh && ./caddy.sh
```
如果下载失败，请使用其他加速源下载

---

## ⌨️ 快捷指令

安装完成后，以后只需在终端输入以下命令即可打开菜单：

```bash
ca
```

---

## 📂 文件路径

* **可执行文件**: `/usr/bin/caddy`
* **配置文件**: `/etc/caddy/Caddyfile`
* **数据目录**: `/var/lib/caddy`
* **Systemd 服务**: `/etc/systemd/system/caddy.service`

---

## ⚠️ 免责声明

1. 本脚本仅供学习交流使用，请勿用于非法用途。
2. 使用本脚本造成的任何损失（包括但不限于数据丢失、服务器被封锁等），作者不承担任何责任。
3. 请遵守当地法律法规。

---

## 📄 开源协议

本项目遵循 [GPL-3.0 License](LICENSE) 协议开源。

Copyright (c) 2026 Shinyuz

---

**如果这个脚本对你有帮助，请给一个 ⭐ Star！**
