#!/bin/bash

# VPS配置修复脚本
# 功能：修复配置文件中的API Key和SSL证书路径问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置变量
PROJECT_DIR="/opt/vps-network-moniter"
API_DIR="$PROJECT_DIR/vps-api"

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

# 修复API Key
fix_api_key() {
    log_info "修复API Key配置..."
    
    # 检查当前API Key
    current_key=$(grep -o 'api_key.*=.*"[^"]*"' "$API_DIR/config.py" | cut -d'"' -f2)
    
    if [ "$current_key" = "your-secret-api-key-here" ] || [ -z "$current_key" ]; then
        log_info "生成新的API Key..."
        API_KEY=$(openssl rand -hex 32)
        sed -i "s|your-secret-api-key-here|$API_KEY|g" "$API_DIR/config.py"
        log_info "API Key已更新: $API_KEY"
    else
        log_info "API Key已存在: ${current_key:0:8}..."
    fi
    
    # 确保配置文件权限正确
    chown www-data:www-data "$API_DIR/config.py"
    chmod 644 "$API_DIR/config.py"
}

# 修复SSL证书路径
fix_ssl_paths() {
    log_info "修复SSL证书路径..."
    
    # 检查SSL证书文件是否存在
    if [ -f "/opt/vps-network-moniter/ssl/private.key" ] && [ -f "/opt/vps-network-moniter/ssl/certificate.crt" ]; then
        log_info "SSL证书文件存在，更新路径..."
        sed -i "s|/path/to/private.key|/opt/vps-network-moniter/ssl/private.key|g" "$API_DIR/config.py"
        sed -i "s|/path/to/certificate.crt|/opt/vps-network-moniter/ssl/certificate.crt|g" "$API_DIR/config.py"
        log_info "SSL证书路径已更新"
    else
        log_warn "SSL证书文件不存在，将使用HTTP模式"
        # 移除SSL配置
        sed -i 's|"ssl_keyfile": "[^"]*"|"ssl_keyfile": ""|g' "$API_DIR/config.py"
        sed -i 's|"ssl_certfile": "[^"]*"|"ssl_certfile": ""|g' "$API_DIR/config.py"
    fi
}

# 重启服务
restart_service() {
    log_info "重启API服务..."
    systemctl restart vps-api
    sleep 3
    
    if systemctl is-active --quiet vps-api; then
        log_info "服务启动成功"
    else
        log_error "服务启动失败"
        log_error "查看服务日志:"
        journalctl -u vps-api --no-pager -n 10
        exit 1
    fi
}

# 测试服务
test_service() {
    log_info "测试API服务..."
    
    # 获取API Key
    API_KEY=$(grep -o 'api_key.*=.*"[^"]*"' "$API_DIR/config.py" | cut -d'"' -f2)
    
    # 测试连接
    if curl -k -s -H "Authorization: Bearer $API_KEY" https://localhost:8443/status | grep -q "success"; then
        log_info "API服务测试成功"
    else
        log_warn "API服务测试失败，可能需要等待几秒钟"
        log_info "可以手动测试: curl -k -H 'Authorization: Bearer $API_KEY' https://localhost:8443/status"
    fi
}

# 主函数
main() {
    log_info "开始修复VPS配置..."
    
    check_root
    fix_api_key
    fix_ssl_paths
    restart_service
    test_service
    
    log_info "配置修复完成！"
    echo
    echo "=== 修复结果 ==="
    echo "配置文件: $API_DIR/config.py"
    echo "服务状态: $(systemctl is-active vps-api)"
    echo "端口监听: $(ss -tlnp | grep :8443 || echo '未监听')"
    echo
    echo "=== 测试命令 ==="
    API_KEY=$(grep -o 'api_key.*=.*"[^"]*"' "$API_DIR/config.py" | cut -d'"' -f2)
    echo "curl -k -H 'Authorization: Bearer $API_KEY' https://localhost:8443/status"
    echo "curl -k -H 'Authorization: Bearer $API_KEY' https://localhost:8443/traffic"
}

# 运行主函数
main 