#!/bin/bash

# SSL证书管理脚本
# 功能：查看、验证和管理SSL证书

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 证书路径
SELF_SIGNED_CERT="/opt/vps-network-moniter/ssl/certificate.crt"
SELF_SIGNED_KEY="/opt/vps-network-moniter/ssl/private.key"

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

log_cert() {
    echo -e "${BLUE}[CERT]${NC} $1"
}

# 检查证书类型
check_cert_type() {
    if [ -f "$SELF_SIGNED_CERT" ]; then
        echo "self_signed"
    elif [ -f "/etc/letsencrypt/live/"*"/fullchain.pem" ]; then
        echo "letsencrypt"
    else
        echo "none"
    fi
}

# 显示证书信息
show_cert_info() {
    local cert_type=$(check_cert_type)
    
    case $cert_type in
        "self_signed")
            log_cert "检测到自签证书"
            echo "证书路径: $SELF_SIGNED_CERT"
            echo "私钥路径: $SELF_SIGNED_KEY"
            echo
            show_cert_details "$SELF_SIGNED_CERT"
            ;;
        "letsencrypt")
            log_cert "检测到Let's Encrypt证书"
            local cert_path=$(find /etc/letsencrypt/live -name "fullchain.pem" | head -n1)
            local key_path=$(find /etc/letsencrypt/live -name "privkey.pem" | head -n1)
            echo "证书路径: $cert_path"
            echo "私钥路径: $key_path"
            echo
            show_cert_details "$cert_path"
            ;;
        "none")
            log_error "未检测到SSL证书"
            ;;
    esac
}

# 显示证书详细信息
show_cert_details() {
    local cert_file="$1"
    
    if [ ! -f "$cert_file" ]; then
        log_error "证书文件不存在: $cert_file"
        return 1
    fi
    
    log_cert "证书详细信息:"
    echo "----------------------------------------"
    
    # 显示证书有效期
    echo "有效期:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 2 "Validity"
    echo
    
    # 显示证书主题
    echo "证书主题:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Subject:"
    echo
    
    # 显示证书颁发者
    echo "证书颁发者:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 1 "Issuer:"
    echo
    
    # 显示SAN信息
    echo "SAN信息:"
    openssl x509 -in "$cert_file" -text -noout | grep -A 5 "Subject Alternative Name"
    echo
    
    # 显示证书指纹
    echo "证书指纹:"
    openssl x509 -in "$cert_file" -fingerprint -noout
    echo "----------------------------------------"
}

# 验证证书
verify_cert() {
    local cert_type=$(check_cert_type)
    
    case $cert_type in
        "self_signed")
            log_cert "验证自签证书..."
            verify_self_signed_cert
            ;;
        "letsencrypt")
            log_cert "验证Let's Encrypt证书..."
            verify_letsencrypt_cert
            ;;
        "none")
            log_error "未检测到SSL证书"
            return 1
            ;;
    esac
}

# 验证自签证书
verify_self_signed_cert() {
    if [ ! -f "$SELF_SIGNED_CERT" ] || [ ! -f "$SELF_SIGNED_KEY" ]; then
        log_error "自签证书文件不存在"
        return 1
    fi
    
    # 验证证书格式
    if openssl x509 -in "$SELF_SIGNED_CERT" -text -noout &> /dev/null; then
        log_info "✓ 证书格式正确"
    else
        log_error "✗ 证书格式错误"
        return 1
    fi
    
    # 验证私钥格式
    if openssl rsa -in "$SELF_SIGNED_KEY" -check -noout &> /dev/null; then
        log_info "✓ 私钥格式正确"
    else
        log_error "✗ 私钥格式错误"
        return 1
    fi
    
    # 验证证书和私钥匹配
    local cert_modulus=$(openssl x509 -in "$SELF_SIGNED_CERT" -modulus -noout | openssl md5)
    local key_modulus=$(openssl rsa -in "$SELF_SIGNED_KEY" -modulus -noout | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log_info "✓ 证书和私钥匹配"
    else
        log_error "✗ 证书和私钥不匹配"
        return 1
    fi
    
    # 检查证书有效期
    local expiry_date=$(openssl x509 -in "$SELF_SIGNED_CERT" -enddate -noout | cut -d= -f2)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp=$(date +%s)
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [ $days_remaining -gt 0 ]; then
        log_info "✓ 证书有效，剩余 $days_remaining 天"
    else
        log_error "✗ 证书已过期"
        return 1
    fi
}

# 验证Let's Encrypt证书
verify_letsencrypt_cert() {
    local cert_path=$(find /etc/letsencrypt/live -name "fullchain.pem" | head -n1)
    local key_path=$(find /etc/letsencrypt/live -name "privkey.pem" | head -n1)
    
    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        log_error "Let's Encrypt证书文件不存在"
        return 1
    fi
    
    # 验证证书
    if openssl x509 -in "$cert_path" -text -noout &> /dev/null; then
        log_info "✓ Let's Encrypt证书格式正确"
    else
        log_error "✗ Let's Encrypt证书格式错误"
        return 1
    fi
    
    # 检查证书有效期
    local expiry_date=$(openssl x509 -in "$cert_path" -enddate -noout | cut -d= -f2)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp=$(date +%s)
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [ $days_remaining -gt 0 ]; then
        log_info "✓ 证书有效，剩余 $days_remaining 天"
    else
        log_error "✗ 证书已过期"
        return 1
    fi
}

# 重新生成自签证书
regenerate_self_signed_cert() {
    log_cert "重新生成自签证书..."
    
    # 备份旧证书
    if [ -f "$SELF_SIGNED_CERT" ]; then
        local backup_dir="/opt/vps-network-moniter/ssl/backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp "$SELF_SIGNED_CERT" "$backup_dir/"
        cp "$SELF_SIGNED_KEY" "$backup_dir/"
        log_info "旧证书已备份到: $backup_dir"
    fi
    
    # 重新生成证书
    openssl req -x509 -newkey rsa:4096 -keyout "$SELF_SIGNED_KEY" \
        -out "$SELF_SIGNED_CERT" -days 3650 -nodes \
        -subj "/C=CN/ST=State/L=City/O=Organization/CN=localhost"
    
    # 设置权限
    chmod 600 "$SELF_SIGNED_KEY"
    chmod 644 "$SELF_SIGNED_CERT"
    chown www-data:www-data "$SELF_SIGNED_KEY" "$SELF_SIGNED_CERT"
    
    log_info "✓ 自签证书重新生成完成（有效期10年）"
    
    # 重启服务
    log_info "重启vps-api服务..."
    systemctl restart vps-api
    
    # 验证新证书
    verify_self_signed_cert
}

# 测试HTTPS连接
test_https_connection() {
    log_cert "测试HTTPS连接..."
    
    # 测试本地连接
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/ | grep -q "200"; then
        log_info "✓ 本地HTTPS连接正常"
    else
        log_error "✗ 本地HTTPS连接失败"
        return 1
    fi
    
    # 测试外部连接（如果有公网IP）
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "")
    if [ ! -z "$public_ip" ]; then
        if curl -k -s -o /dev/null -w "%{http_code}" https://$public_ip:8443/ | grep -q "200"; then
            log_info "✓ 外部HTTPS连接正常"
        else
            log_warn "⚠ 外部HTTPS连接失败（可能是防火墙问题）"
        fi
    fi
}

# 显示帮助信息
show_help() {
    echo "SSL证书管理脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  info                   显示证书信息"
    echo "  verify                 验证证书"
    echo "  regenerate             重新生成自签证书"
    echo "  test                   测试HTTPS连接"
    echo "  all                    执行所有检查"
    echo "  -h, --help            显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 info                # 显示证书信息"
    echo "  $0 verify              # 验证证书"
    echo "  $0 regenerate          # 重新生成自签证书"
    echo "  $0 all                 # 执行所有检查"
    echo
}

# 主函数
main() {
    case "${1:-all}" in
        "info")
            show_cert_info
            ;;
        "verify")
            verify_cert
            ;;
        "regenerate")
            regenerate_self_signed_cert
            ;;
        "test")
            test_https_connection
            ;;
        "all")
            echo -e "${BLUE}=== SSL证书管理 ===${NC}"
            echo
            show_cert_info
            echo
            verify_cert
            echo
            test_https_connection
            ;;
        "-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 