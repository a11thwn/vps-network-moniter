#!/bin/bash

# VPS流量监控系统部署脚本
# 功能：自动化部署VPS端API服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="/opt/vps-traffic-monitor"
VENV_DIR="$PROJECT_DIR/venv"
API_DIR="$PROJECT_DIR/vps-api"
SERVICE_NAME="vps-api"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    log_info "检查系统要求..."
    
    # 检查并安装Python 3.11
    if ! command -v python3.11 &> /dev/null; then
        log_info "Python 3.11 未安装，正在安装..."
        
        # 更新包列表
        apt update
        
        # 安装Python 3.11
        apt install -y python3.11 python3.11-venv python3.11-dev python3.11-pip
        
        # 创建软链接（如果不存在）
        if [ ! -f /usr/bin/python3.11 ]; then
            log_warn "Python 3.11 安装可能失败，尝试其他方法..."
            
            # 尝试从源码编译安装
            apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
            
            # 下载Python 3.11源码
            cd /tmp
            wget https://www.python.org/ftp/python/3.11.7/Python-3.11.7.tgz
            tar -xf Python-3.11.7.tgz
            cd Python-3.11.7
            
            # 编译安装
            ./configure --enable-optimizations
            make -j$(nproc)
            make altinstall
            
            # 创建软链接
            ln -sf /usr/local/bin/python3.11 /usr/bin/python3.11
            ln -sf /usr/local/bin/pip3.11 /usr/bin/pip3.11
        fi
        
        log_info "Python 3.11 安装完成"
    else
        log_info "Python 3.11 已安装，版本: $(python3.11 --version)"
    fi
    
    # 检查并安装vnstat
    if ! command -v vnstat &> /dev/null; then
        log_info "vnstat 未安装，正在安装..."
        apt update && apt install -y vnstat
        
        # 启动vnstat服务
        systemctl enable vnstat
        systemctl start vnstat
        
        # 等待vnstat收集初始数据
        log_info "等待vnstat收集初始数据..."
        sleep 10
    else
        log_info "vnstat 已安装，版本: $(vnstat --version | head -n1)"
    fi
    
    # 检查并安装其他必要工具
    local required_tools=("curl" "wget" "git" "jq" "openssl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_info "安装 $tool..."
            apt install -y "$tool"
        fi
    done
    
    log_info "系统要求检查完成"
}

# 创建项目目录
setup_directories() {
    log_info "创建项目目录..."
    
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$API_DIR"
    mkdir -p /var/log/vps-api
    
    # 设置权限
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    
    log_info "目录创建完成"
}

# 创建Python虚拟环境
setup_venv() {
    log_info "创建Python虚拟环境..."
    
    # 确保Python 3.11可用
    if ! command -v python3.11 &> /dev/null; then
        log_error "Python 3.11 不可用，请检查安装"
        exit 1
    fi
    
    # 删除旧的虚拟环境（如果存在）
    if [ -d "$VENV_DIR" ]; then
        log_info "删除旧的虚拟环境..."
        rm -rf "$VENV_DIR"
    fi
    
    # 创建新的虚拟环境
    log_info "创建Python 3.11虚拟环境..."
    python3.11 -m venv "$VENV_DIR"
    
    # 激活虚拟环境并安装依赖
    log_info "安装Python依赖..."
    source "$VENV_DIR/bin/activate"
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装依赖
    if [ -f "$API_DIR/requirements.txt" ]; then
        pip install -r "$API_DIR/requirements.txt"
    else
        log_error "requirements.txt 文件不存在"
        exit 1
    fi
    
    log_info "虚拟环境设置完成"
    log_info "Python版本: $(python --version)"
    log_info "虚拟环境路径: $VENV_DIR"
}

# 配置服务
setup_service() {
    log_info "配置systemd服务..."
    
    # 复制服务文件
    cp "$API_DIR/vps-api.service" /etc/systemd/system/
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$SERVICE_NAME"
    
    log_info "服务配置完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 允许Cloudflare IP段访问8443端口
    ufw allow from 173.245.48.0/20 to any port 8443
    ufw allow from 103.21.244.0/22 to any port 8443
    ufw allow from 103.22.200.0/22 to any port 8443
    ufw allow from 103.31.4.0/22 to any port 8443
    ufw allow from 141.101.64.0/18 to any port 8443
    ufw allow from 108.162.192.0/18 to any port 8443
    ufw allow from 190.93.240.0/20 to any port 8443
    ufw allow from 188.114.96.0/20 to any port 8443
    ufw allow from 197.234.240.0/22 to any port 8443
    ufw allow from 198.41.128.0/17 to any port 8443
    ufw allow from 162.158.0.0/15 to any port 8443
    ufw allow from 104.16.0.0/13 to any port 8443
    ufw allow from 104.24.0.0/14 to any port 8443
    ufw allow from 172.64.0.0/13 to any port 8443
    ufw allow from 131.0.72.0/22 to any port 8443
    
    log_info "防火墙配置完成"
}

# 配置SSL证书
setup_ssl() {
    log_info "配置SSL证书..."
    
    if [ -z "$DOMAIN" ]; then
        log_info "未指定域名，使用自签证书..."
        setup_self_signed_cert
    else
        log_info "使用Let's Encrypt证书..."
        setup_letsencrypt_cert
    fi
}

# 配置自签证书
setup_self_signed_cert() {
    log_info "生成自签SSL证书..."
    
    # 创建证书目录
    mkdir -p /opt/vps-traffic-monitor/ssl
    
    # 生成自签证书（有效期10年）
    openssl req -x509 -newkey rsa:4096 -keyout /opt/vps-traffic-monitor/ssl/private.key \
        -out /opt/vps-traffic-monitor/ssl/certificate.crt -days 3650 -nodes \
        -subj "/C=CN/ST=State/L=City/O=Organization/CN=localhost"
    
    # 设置权限
    chmod 600 /opt/vps-traffic-monitor/ssl/private.key
    chmod 644 /opt/vps-traffic-monitor/ssl/certificate.crt
    chown -R www-data:www-data /opt/vps-traffic-monitor/ssl
    
    # 更新配置文件
    sed -i "s|/path/to/private.key|/opt/vps-traffic-monitor/ssl/private.key|g" "$API_DIR/config.py"
    sed -i "s|/path/to/certificate.crt|/opt/vps-traffic-monitor/ssl/certificate.crt|g" "$API_DIR/config.py"
    
    log_info "自签SSL证书配置完成（有效期10年）"
}

# 配置Let's Encrypt证书
setup_letsencrypt_cert() {
    log_info "配置Let's Encrypt证书..."
    
    # 安装certbot
    if ! command -v certbot &> /dev/null; then
        apt install -y certbot
    fi
    
    # 获取SSL证书
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
    
    # 更新配置文件
    sed -i "s|your-domain.com|$DOMAIN|g" "$API_DIR/config.py"
    sed -i "s|/path/to/private.key|/etc/letsencrypt/live/$DOMAIN/privkey.pem|g" "$API_DIR/config.py"
    sed -i "s|/path/to/certificate.crt|/etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" "$API_DIR/config.py"
    
    log_info "Let's Encrypt SSL证书配置完成"
}

# 生成API Key
generate_api_key() {
    log_info "生成API Key..."
    
    API_KEY=$(openssl rand -hex 32)
    sed -i "s|your-secret-api-key-here|$API_KEY|g" "$API_DIR/config.py"
    
    log_info "API Key已生成: $API_KEY"
    log_warn "请保存此API Key，用于Workers配置"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    systemctl start "$SERVICE_NAME"
    systemctl status "$SERVICE_NAME" --no-pager
    
    log_info "服务启动完成"
}

# 显示部署信息
show_info() {
    log_info "部署完成！"
    echo
    echo "=== 部署信息 ==="
    echo "项目目录: $PROJECT_DIR"
    echo "API目录: $API_DIR"
    echo "服务名称: $SERVICE_NAME"
    echo "配置文件: $API_DIR/config.py"
    echo
    echo "=== 管理命令 ==="
    echo "启动服务: systemctl start $SERVICE_NAME"
    echo "停止服务: systemctl stop $SERVICE_NAME"
    echo "重启服务: systemctl restart $SERVICE_NAME"
    echo "查看状态: systemctl status $SERVICE_NAME"
    echo "查看日志: journalctl -u $SERVICE_NAME -f"
    echo
    echo "=== 测试API ==="
    if [ ! -z "$DOMAIN" ]; then
        echo "curl -H 'Authorization: Bearer $API_KEY' https://$DOMAIN:8443/status"
    else
        echo "curl -k -H 'Authorization: Bearer $API_KEY' https://localhost:8443/status"
        echo "curl -k -H 'Authorization: Bearer $API_KEY' https://your-vps-ip:8443/status"
    fi
    echo
}

# 主函数
main() {
    log_info "开始部署VPS流量监控API服务..."
    
    check_root
    check_system
    setup_directories
    setup_venv
    setup_service
    setup_firewall
    
    # 总是配置SSL证书（自签或Let's Encrypt）
    setup_ssl
    
    generate_api_key
    start_service
    show_info
}

# 显示帮助信息
show_help() {
    echo "VPS流量监控系统部署脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -d, --domain DOMAIN    指定域名 (用于Let's Encrypt证书，可选)"
    echo "  -e, --email EMAIL      指定邮箱 (用于Let's Encrypt证书，可选)"
    echo "  -h, --help             显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0                      # 使用自签证书"
    echo "  $0 -d example.com -e admin@example.com  # 使用Let's Encrypt证书"
    echo
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
main 