#!/bin/bash

# =========================================================
# Caddy Management Script v1.3.1
# Author: Shinyuz | Fix: Spacing (Strict)
# =========================================================

# --- 颜色定义 ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
PLAIN='\033[0m'

# --- 基础变量 ---
CADDY_CONF_FILE="/etc/caddy/Caddyfile"
CADDY_BIN_PATH="/usr/bin/caddy"
SCRIPT_VERSION="v1.3.1"
DEFAULT_VER="v2.8.4"
# 使用支持 IPv6 的 Cloudflare 节点源
GH_PROXY="https://gh-proxy.com/"
GH_PROXY_BACKUP="https://521github.com/"

# --- 检查 Root 权限 ---
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用 root 用户运行此脚本！\n" && exit 1

# --- 工具函数：按任意键返回 ---
any_key_back() {
    echo ""
    read -n 1 -s -r -p "按任意键返回..."
    echo ""
}

# --- 工具函数：设置快捷键 ---
set_shortcut() {
    if [[ ! -f /usr/bin/ca ]]; then
        ln -sf "$0" /usr/bin/ca
        chmod +x /usr/bin/ca
        echo ""
        echo -e "${GREEN}快捷键设置成功！输入 'ca' 即可随时呼出脚本。${PLAIN}"
        echo ""
    fi
}

# --- 核心工具：智能重载/启动 Caddy (屏蔽日志) ---
reload_caddy() {
    caddy fmt --overwrite "$CADDY_CONF_FILE" &> /dev/null
    if systemctl is-active caddy &> /dev/null; then
        caddy reload --config "$CADDY_CONF_FILE" &> /dev/null
    else
        systemctl restart caddy &> /dev/null
    fi
    if systemctl is-active caddy &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# --- 核心工具：检测网络环境 ---
check_network() {
    if ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
        echo "ipv4"
    else
        echo "ipv6_only"
    fi
}

# --- 自动安装 Caddy ---
install_caddy() {
    if command -v caddy &> /dev/null; then
        return 0
    fi

    # 修正：去掉了这里多余的 echo ""，因为上一个函数结尾已经有空行了
    echo -e "${BLUE}检测到未安装 Caddy，准备安装...${PLAIN}"
    echo ""

    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  download_arch="amd64" ;;
        aarch64) download_arch="arm64" ;;
        arm64)   download_arch="arm64" ;;
        *)       echo -e "${RED}不支持的架构: ${ARCH}${PLAIN}"; exit 1 ;;
    esac

    if ! command -v wget &> /dev/null; then
        if [[ -f /etc/debian_version ]]; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y wget >/dev/null 2>&1
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y wget >/dev/null 2>&1
        fi
    fi

    echo -e "${YELLOW}正在获取 Caddy 最新版本信息...${PLAIN}"
    echo ""
    
    LATEST_VER=$(wget --no-check-certificate -qO- -t1 -T5 "https://api.github.com/repos/caddyserver/caddy/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    
    if [[ -z "$LATEST_VER" ]]; then
        echo -e "${RED}获取失败，将使用默认稳定版: ${DEFAULT_VER}${PLAIN}"
        LATEST_VER="$DEFAULT_VER"
    else
        echo -e "${GREEN}获取成功，当前最新版本: ${LATEST_VER}${PLAIN}"
    fi
    echo ""

    URL_OFFICIAL="https://github.com/caddyserver/caddy/releases/download/${LATEST_VER}/caddy_${LATEST_VER//v/}_linux_${download_arch}.tar.gz"
    URL_MIRROR="${GH_PROXY}${URL_OFFICIAL}"
    URL_MIRROR_2="${GH_PROXY_BACKUP}${URL_OFFICIAL}"
    
    rm -rf /tmp/caddy_install
    mkdir -p /tmp/caddy_install
    
    NET_TYPE=$(check_network)
    
    if [[ "$NET_TYPE" == "ipv6_only" ]]; then
        echo -e "${YELLOW}检测到 IPv6-Only 环境，使用 IPv6 专用源下载...${PLAIN}"
        echo ""
        if wget --no-check-certificate -O /tmp/caddy_install/caddy.tar.gz "$URL_MIRROR"; then
            echo -e "${GREEN}下载成功！${PLAIN}"
        else
            echo -e "${RED}主源下载失败，尝试备用源...${PLAIN}"
            echo ""
            if wget --no-check-certificate -O /tmp/caddy_install/caddy.tar.gz "$URL_MIRROR_2"; then
                echo -e "${GREEN}备用源下载成功！${PLAIN}"
            else
                echo -e "${RED}所有 IPv6 源均不可达，请检查 DNS (推荐 Google DNS64)。${PLAIN}\n"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}正在使用 Wget 下载 Caddy (${download_arch})...${PLAIN}"
        echo ""
        if wget --no-check-certificate -O /tmp/caddy_install/caddy.tar.gz "$URL_OFFICIAL"; then
            echo -e "${GREEN}官方源下载成功！${PLAIN}"
        else
            echo -e "${RED}官方源下载失败，自动切换到加速镜像...${PLAIN}"
            echo ""
            if wget --no-check-certificate -O /tmp/caddy_install/caddy.tar.gz "$URL_MIRROR"; then
                echo -e "${GREEN}加速源下载成功！${PLAIN}"
            else
                echo -e "${RED}下载彻底失败，请检查网络连接。${PLAIN}\n"
                exit 1
            fi
        fi
    fi
    echo ""

    echo -e "${BLUE}正在解压安装...${PLAIN}"
    echo ""
    
    tar -xzf /tmp/caddy_install/caddy.tar.gz -C /tmp/caddy_install
    mv /tmp/caddy_install/caddy "$CADDY_BIN_PATH"
    chmod +x "$CADDY_BIN_PATH"
    rm -rf /tmp/caddy_install

    id -u caddy &>/dev/null || useradd -r -d /var/lib/caddy -s /usr/sbin/nologin caddy
    groupadd caddy &>/dev/null
    usermod -aG caddy caddy &>/dev/null

    mkdir -p /etc/caddy
    mkdir -p /var/lib/caddy
    touch "$CADDY_CONF_FILE"
    chown -R caddy:caddy /etc/caddy
    chown -R caddy:caddy /var/lib/caddy

    cat > /etc/systemd/system/caddy.service <<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable caddy &> /dev/null
    systemctl restart caddy &> /dev/null
    
    if systemctl is-active caddy &> /dev/null; then
        echo -e "${GREEN}Caddy 安装并启动成功！${PLAIN}"
    else
        echo -e "${GREEN}Caddy 安装成功(配置为空，服务暂未启动)${PLAIN}"
    fi
    set_shortcut
}

# --- 更新 Caddy ---
update_caddy() {
    echo -e "\n========= 更新 Caddy =========\n"
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  download_arch="amd64" ;;
        aarch64) download_arch="arm64" ;;
        arm64)   download_arch="arm64" ;;
        *)       echo -e "${RED}不支持的架构: ${ARCH}${PLAIN}"; any_key_back; return ;;
    esac

    echo -e "${YELLOW}正在检查最新版本...${PLAIN}"
    echo ""
    
    LATEST_VER=$(wget --no-check-certificate -qO- -t1 -T5 "https://api.github.com/repos/caddyserver/caddy/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

    if [[ -z "$LATEST_VER" ]]; then
        echo -e "${RED}获取最新版本失败，无法更新。${PLAIN}"
        any_key_back
        return
    fi
    
    CURRENT_VER=$(caddy version | awk '{print $1}')
    
    echo -e "当前版本: ${CURRENT_VER}"
    echo ""
    echo -e "最新版本: ${LATEST_VER}"
    echo ""
    
    if [[ "$CURRENT_VER" == "$LATEST_VER" ]]; then
        echo -e "${GREEN}已经是最新版本，无需更新。${PLAIN}"
        any_key_back
        return
    fi
    
    read -p "发现新版本，确认更新? (y/n): " confirm
    echo ""
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消。${PLAIN}"
        any_key_back
        return
    fi

    URL_OFFICIAL="https://github.com/caddyserver/caddy/releases/download/${LATEST_VER}/caddy_${LATEST_VER//v/}_linux_${download_arch}.tar.gz"
    URL_MIRROR="${GH_PROXY}${URL_OFFICIAL}"
    URL_MIRROR_2="${GH_PROXY_BACKUP}${URL_OFFICIAL}"
    
    rm -rf /tmp/caddy_update
    mkdir -p /tmp/caddy_update
    
    NET_TYPE=$(check_network)
    
    echo -e "${YELLOW}正在下载新版本...${PLAIN}"
    echo ""
    
    if [[ "$NET_TYPE" == "ipv6_only" ]]; then
        if wget --no-check-certificate -O /tmp/caddy_update/caddy.tar.gz "$URL_MIRROR"; then
            echo -e "${GREEN}下载成功。${PLAIN}"
        elif wget --no-check-certificate -O /tmp/caddy_update/caddy.tar.gz "$URL_MIRROR_2"; then
            echo -e "${GREEN}备用源下载成功。${PLAIN}"
        else
            echo -e "${RED}下载失败。${PLAIN}"
            any_key_back
            return
        fi
    else
        if wget --no-check-certificate -O /tmp/caddy_update/caddy.tar.gz "$URL_OFFICIAL"; then
            echo -e "${GREEN}下载成功。${PLAIN}"
        else
            echo -e "${RED}直连下载失败，尝试加速源...${PLAIN}"
            echo ""
            if wget --no-check-certificate -O /tmp/caddy_update/caddy.tar.gz "$URL_MIRROR"; then
                echo -e "${GREEN}加速源下载成功。${PLAIN}"
            else
                echo -e "${RED}更新下载失败。${PLAIN}"
                any_key_back
                return
            fi
        fi
    fi
    echo ""

    echo -e "${BLUE}正在覆盖安装...${PLAIN}"
    tar -xzf /tmp/caddy_update/caddy.tar.gz -C /tmp/caddy_update
    
    systemctl stop caddy
    mv /tmp/caddy_update/caddy "$CADDY_BIN_PATH"
    chmod +x "$CADDY_BIN_PATH"
    rm -rf /tmp/caddy_update
    
    echo ""
    echo -e "${BLUE}正在重启服务...${PLAIN}"
    systemctl restart caddy
    
    echo ""
    echo -e "${GREEN}Caddy 更新完成！当前版本: $(caddy version | awk '{print $1}')${PLAIN}"
    any_key_back
}

# --- 获取状态 ---
get_status() {
    if systemctl is-active caddy &> /dev/null; then
        STATUS="${GREEN}running${PLAIN}"
    else
        STATUS="${RED}stopped${PLAIN}"
    fi
    if command -v caddy &> /dev/null; then
        VER=$(caddy version | awk '{print $1}' | sed 's/v//')
    else
        VER="${RED}未安装${PLAIN}"
    fi
}

# --- 功能：添加反代 ---
add_proxy() {
    echo -e "\n========= 添加反代配置 =========\n"
    
    read -p "请输入绑定的域名: " domain
    echo ""
    
    read -p "请输入反代IP: " proxy_ip
    echo ""
    
    read -p "请输入反代端口: " proxy_port
    echo ""

    echo -e "${BLUE}正在写入配置...${PLAIN}\n"

cat <<EOF >> "$CADDY_CONF_FILE"

${domain} {
    reverse_proxy ${proxy_ip}:${proxy_port}
}
EOF

    if reload_caddy; then
        echo -e "${GREEN}配置添加成功！${PLAIN}"
    else
        echo -e "${RED}配置添加失败，请检查端口是否被占用或配置错误。${PLAIN}"
    fi
    any_key_back
}

# --- 功能：更改配置 ---
modify_proxy() {
    echo -e "\n========= 更改配置 =========\n"
    
    if [[ ! -s "$CADDY_CONF_FILE" ]]; then
        echo -e "${RED}配置文件为空，无法修改。${PLAIN}"
        any_key_back
        return
    fi

    mapfile -t domains < <(grep -E " \{$" "$CADDY_CONF_FILE" | awk '{print $1}')

    if [[ ${#domains[@]} -eq 0 ]]; then
        echo -e "${RED}未检测到有效配置。${PLAIN}"
        any_key_back
        return
    fi

    echo -e "当前已有的配置：\n"
    local i=1
    for d in "${domains[@]}"; do
        echo -e " ${i}. ${d}"
        echo ""
        ((i++))
    done
    echo -e " 0. 返回"
    echo ""

    read -p "请选择[0-${#domains[@]}]: " select_idx
    if [[ "$select_idx" == "0" ]]; then
        return
    fi
    echo ""

    if ! [[ "$select_idx" =~ ^[0-9]+$ ]] || [[ "$select_idx" -lt 1 ]] || [[ "$select_idx" -gt ${#domains[@]} ]]; then
        echo -e "${RED}无效的选择。${PLAIN}"
        any_key_back
        return
    fi

    old_domain="${domains[$((select_idx-1))]}"
    old_target=$(grep -A 2 "${old_domain} {" "$CADDY_CONF_FILE" | grep "reverse_proxy" | awk '{print $2}')
    old_ip=$(echo "$old_target" | cut -d':' -f1)
    old_port=$(echo "$old_target" | cut -d':' -f2)

    echo -e "${YELLOW}正在修改：${old_domain} -> ${old_target}${PLAIN}"
    echo ""

    read -p "请修改绑定的域名(回车默认:${old_domain}): " new_domain
    [[ -z "$new_domain" ]] && new_domain="$old_domain"
    echo ""

    read -p "请修改反代IP(回车默认:${old_ip}): " new_ip
    [[ -z "$new_ip" ]] && new_ip="$old_ip"
    echo ""

    read -p "请修改反代端口(回车默认:${old_port}): " new_port
    [[ -z "$new_port" ]] && new_port="$old_port"
    echo ""

    echo -e "${BLUE}正在更新配置...${PLAIN}\n"

    sed -i "/^${old_domain} {/,/}/d" "$CADDY_CONF_FILE"

cat <<EOF >> "$CADDY_CONF_FILE"

${new_domain} {
    reverse_proxy ${new_ip}:${new_port}
}
EOF

    if reload_caddy; then
        echo -e "${GREEN}修改成功！${PLAIN}"
    else
        echo -e "${RED}修改失败，请检查输入格式。${PLAIN}"
    fi
    any_key_back
}

# --- 功能：查看配置 ---
view_config() {
    while true; do
        echo -e "\n========= 查看当前配置 =========\n"
        
        if [[ ! -s "$CADDY_CONF_FILE" ]]; then
            echo -e "${RED}配置文件为空。${PLAIN}"
            any_key_back
            return
        fi

        mapfile -t domains < <(grep -E " \{$" "$CADDY_CONF_FILE" | awk '{print $1}')

        if [[ ${#domains[@]} -eq 0 ]]; then
            echo -e "${RED}未检测到有效配置。${PLAIN}"
            any_key_back
            return
        fi

        local i=1
        for d in "${domains[@]}"; do
            echo -e " ${i}. ${d}"
            echo ""
            ((i++))
        done
        echo -e " 0. 返回"
        echo ""

        read -p "请选择[0-${#domains[@]}]: " view_idx
        if [[ "$view_idx" == "0" ]]; then
            return
        fi
        echo ""

        if ! [[ "$view_idx" =~ ^[0-9]+$ ]] || [[ "$view_idx" -lt 1 ]] || [[ "$view_idx" -gt ${#domains[@]} ]]; then
            echo -e "${RED}无效的选择。${PLAIN}\n"
            continue
        fi

        selected_domain="${domains[$((view_idx-1))]}"
        echo -e "${GREEN}--- [ ${selected_domain} ] 的详细配置 ---${PLAIN}\n"
        sed -n "/^${selected_domain} {/,/}/p" "$CADDY_CONF_FILE"
        
        any_key_back
    done
}

# --- 功能：管理配置 ---
manage_config() {
    while true; do
        echo -e "\n========= 删除配置 =========\n"
        
        echo -e " 1. 删除配置"
        echo ""
        echo -e " 2. 清空配置"
        echo ""
        echo -e " 0. 返回"
        echo ""
        
        read -p "请选择[0-2]: " m_choice
        if [[ "$m_choice" == "0" ]]; then
            return
        fi
        echo ""
        
        case "$m_choice" in
            1) 
                if [[ ! -s "$CADDY_CONF_FILE" ]]; then
                    echo -e "${RED}配置文件为空。${PLAIN}"
                    any_key_back
                else
                    mapfile -t domains < <(grep -E " \{$" "$CADDY_CONF_FILE" | awk '{print $1}')
                    if [[ ${#domains[@]} -eq 0 ]]; then
                         echo -e "${RED}无有效配置。${PLAIN}"
                         any_key_back
                    else
                        echo -e "请选择要删除的配置："
                        echo ""
                        local i=1
                        for d in "${domains[@]}"; do
                            echo -e " ${i}. ${d}"
                            echo ""
                            ((i++))
                        done
                        echo -e " 0. 返回"
                        echo ""
                        
                        read -p "请选择[0-${#domains[@]}]: " del_idx
                        if [[ "$del_idx" != "0" ]]; then
                            echo ""
                            if ! [[ "$del_idx" =~ ^[0-9]+$ ]] || [[ "$del_idx" -lt 1 ]] || [[ "$del_idx" -gt ${#domains[@]} ]]; then
                                echo -e "${RED}无效选择${PLAIN}"
                            else
                                target_domain="${domains[$((del_idx-1))]}"
                                echo -e "正在删除: ${target_domain}"
                                sed -i "/^${target_domain} {/,/}/d" "$CADDY_CONF_FILE"
                                reload_caddy
                                echo ""
                                echo -e "${GREEN}删除成功${PLAIN}"
                            fi
                            any_key_back
                        fi
                    fi
                fi
                ;;
            2) 
                read -p "确认清空所有配置? (y/n): " confirm
                echo ""
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    > "$CADDY_CONF_FILE"
                    reload_caddy
                    echo -e "${GREEN}配置已清空。${PLAIN}"
                else
                    echo -e "${YELLOW}已取消。${PLAIN}"
                fi
                any_key_back
                ;;
            *) 
                echo -e "${RED}无效选项${PLAIN}" 
                any_key_back
                ;;
        esac
    done
}

# --- 子菜单：Caddy 服务管理 ---
caddy_mgmt_menu() {
    while true; do
        get_status
        echo -e "\n========= Caddy 服务管理 =========\n"
        echo -e " Caddy 状态: ${STATUS}\n"
        echo -e "==================================\n"
        echo -e " 1. 启动\n"
        echo -e " 2. 停止\n"
        echo -e " 3. 重启\n"
        echo -e " 4. 更新\n"
        echo -e " 5. 日志\n"
        echo -e " 0. 返回\n"
        read -p "请选择[0-5]: " sub_choice
        
        if [[ "$sub_choice" == "0" ]]; then
            return
        fi
        
        case "$sub_choice" in
            1) 
                systemctl start caddy
                echo ""
                echo -e "${GREEN}已启动${PLAIN}"
                any_key_back
                ;;
            2) 
                systemctl stop caddy
                echo ""
                echo -e "${RED}已停止${PLAIN}"
                any_key_back
                ;;
            3) 
                systemctl restart caddy
                echo ""
                echo -e "${GREEN}已重启${PLAIN}"
                any_key_back
                ;;
            4) 
                update_caddy 
                ;;
            5) 
                echo ""
                journalctl -u caddy -n 50 --no-pager
                any_key_back
                ;;
            *) echo -e "\n${RED}无效选项${PLAIN}"; sleep 1 ;;
        esac
    done
}

# --- 功能：完全卸载 ---
uninstall_all() {
    echo -e "\n========= 卸载管理 =========\n"
    echo -e "${RED}警告：此操作将删除 Caddy、配置文件以及本脚本！${PLAIN}\n"
    
    read -p "确认卸载? (y/n): " confirm
    echo ""
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${BLUE}正在停止服务...${PLAIN}"
        systemctl stop caddy
        systemctl disable caddy &> /dev/null
        echo ""

        echo -e "${BLUE}正在删除文件...${PLAIN}"
        rm -f /usr/bin/caddy
        rm -f /etc/systemd/system/caddy.service
        systemctl daemon-reload
        
        rm -rf /etc/caddy
        rm -rf /usr/share/caddy
        rm -f /usr/bin/ca
        
        echo ""
        echo -e "${GREEN}卸载完成${PLAIN}"
        echo ""
        rm -f "$0"
        exit 0
    else
        echo -e "${YELLOW}已取消${PLAIN}"
        sleep 1
    fi
}

# --- 子菜单：脚本管理 ---
script_mgmt_menu() {
    while true; do
        echo -e "\n========= 脚本管理 =========\n"
        echo -e " 1. 卸载\n"
        echo -e " 0. 返回\n"
        read -p "请选择[0-1]: " sub_choice
        
        if [[ "$sub_choice" == "0" ]]; then
            return
        fi
        
        case "$sub_choice" in
            1) uninstall_all; return ;;
            *) echo -e "\n${RED}无效选项${PLAIN}"; sleep 1 ;;
        esac
    done
}

# --- 主菜单 ---
show_menu() {
    set_shortcut
    install_caddy
    get_status
    
    echo ""
    
    echo -e "${GREEN}========= Caddy Script ${SCRIPT_VERSION} By Shinyuz =========${PLAIN}"
    echo ""
    echo -e " Caddy: ${GREEN}${VER}${PLAIN}"
    echo ""
    echo -e " Caddy: ${GREEN}${STATUS}${PLAIN}"
    echo ""
    echo -e "${GREEN}======================================================${PLAIN}"
    echo ""
    echo -e " 1. 添加配置"
    echo ""
    echo -e " 2. 更改配置"
    echo ""
    echo -e " 3. 查看配置"
    echo ""
    echo -e " 4. 管理配置"
    echo ""
    echo -e " 5. 管理Caddy服务"
    echo ""
    echo -e " 6. 脚本管理"
    echo ""
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-6]: " choice
}

# --- 主逻辑 ---
while true; do
    show_menu
    case "$choice" in
        1) add_proxy ;;
        2) modify_proxy ;;
        3) view_config ;;
        4) manage_config ;;
        5) caddy_mgmt_menu ;;
        6) script_mgmt_menu ;;
        0) 
           echo ""
           exit 0 
           ;;
        *) echo -e "\n${RED}无效选项${PLAIN}"; sleep 1 ;;
    esac
done