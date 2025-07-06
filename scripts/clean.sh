#!/bin/bash

# VPS清理脚本
# 功能：清理旧的部署文件，为重新部署做准备

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置变量
PROJECT_DIR="/opt/vps-network-moniter"

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

# 停止服务
stop_service() {
    log_info "停止API服务..."
    if systemctl is-active --quiet vps-api; then
        systemctl stop vps-api
        log_info "服务已停止"
    else
        log_info "服务未运行"
    fi
    
    # 禁用服务
    systemctl disable vps-api 2>/dev/null || true
}

# 清理项目文件
clean_project() {
    log_info "清理项目文件..."
    
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
        log_info "项目目录已清理: $PROJECT_DIR"
    fi
    
    # 清理日志文件
    if [ -f "/var/log/vps-api.log" ]; then
        rm -f /var/log/vps-api.log
        log_info "日志文件已清理"
    fi
    
    # 清理systemd服务文件
    if [ -f "/etc/systemd/system/vps-api.service" ]; then
        rm -f /etc/systemd/system/vps-api.service
        log_info "服务文件已清理"
    fi
    
    # 重新加载systemd
    systemctl daemon-reload
}

# 清理SSL证书（可选）
clean_ssl() {
    log_info "清理SSL证书..."
    
    if [ -d "/opt/vps-network-moniter/ssl" ]; then
        rm -rf /opt/vps-network-moniter/ssl
        log_info "SSL证书已清理"
    fi
}

# 显示清理结果
show_result() {
    log_info "清理完成！"
    echo
    echo "=== 清理结果 ==="
    echo "项目目录: $([ -d "$PROJECT_DIR" ] && echo "存在" || echo "已清理")"
    echo "服务状态: $(systemctl is-active vps-api 2>/dev/null || echo "已停止")"
    echo "服务文件: $([ -f "/etc/systemd/system/vps-api.service" ] && echo "存在" || echo "已清理")"
    echo
    echo "=== 下一步 ==="
    echo "现在可以重新运行部署脚本:"
    echo "sudo bash scripts/deploy.sh"
}

# 主函数
main() {
    log_info "开始清理VPS部署..."
    
    check_root
    stop_service
    clean_project
    clean_ssl
    show_result
}

# 显示帮助信息
show_help() {
    echo "VPS清理脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help             显示此帮助信息"
    echo "  -s, --ssl-only         仅清理SSL证书"
    echo
    echo "示例:"
    echo "  $0                      # 完全清理"
    echo "  $0 -s                   # 仅清理SSL证书"
    echo
}

# 解析命令行参数
SSL_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--ssl-only)
            SSL_ONLY=true
            shift
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
if [ "$SSL_ONLY" = true ]; then
    log_info "仅清理SSL证书..."
    check_root
    clean_ssl
    show_result
else
    main
fi 