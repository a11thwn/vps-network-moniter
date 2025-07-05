#!/bin/bash

# VPS流量监控系统测试脚本
# 功能：测试API服务的各项功能是否正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
API_BASE_URL="https://localhost:8443"
API_KEY=""

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# 获取API Key
get_api_key() {
    if [ -f "/opt/vps-network-moniter/vps-api/config.py" ]; then
        API_KEY=$(grep -o 'api_key.*=.*"[^"]*"' /opt/vps-network-moniter/vps-api/config.py | cut -d'"' -f2)
        if [ "$API_KEY" = "your-secret-api-key-here" ]; then
            log_error "API Key未配置，请先运行部署脚本"
            exit 1
        fi
    else
        log_error "配置文件不存在，请先运行部署脚本"
        exit 1
    fi
}

# 测试vnstat安装
test_vnstat() {
    log_test "测试vnstat安装..."
    
    if command -v vnstat &> /dev/null; then
        log_info "✓ vnstat已安装"
        vnstat --version | head -n1
        
        # 检查vnstat服务状态
        if systemctl is-active --quiet vnstat; then
            log_info "✓ vnstat服务正在运行"
        else
            log_warn "⚠ vnstat服务未运行，正在启动..."
            systemctl start vnstat
        fi
        
        # 测试vnstat命令
        if vnstat --json &> /dev/null; then
            log_info "✓ vnstat命令正常工作"
        else
            log_error "✗ vnstat命令失败"
            return 1
        fi
    else
        log_error "✗ vnstat未安装"
        return 1
    fi
}

# 测试API服务状态
test_api_service() {
    log_test "测试API服务状态..."
    
    if systemctl is-active --quiet vps-api; then
        log_info "✓ vps-api服务正在运行"
    else
        log_error "✗ vps-api服务未运行"
        log_info "启动服务..."
        systemctl start vps-api
        sleep 3
    fi
    
    # 检查端口监听
    if netstat -tlnp | grep -q ":8443"; then
        log_info "✓ API服务正在监听8443端口"
    else
        log_error "✗ API服务未监听8443端口"
        return 1
    fi
}

# 测试HTTPS连接
test_https() {
    log_test "测试HTTPS连接..."
    
    # 检查是否使用自签证书
    if [ -f "/opt/vps-network-moniter/ssl/certificate.crt" ]; then
        log_info "检测到自签证书"
        
        # 测试自签证书
        if openssl s_client -connect localhost:8443 -servername localhost < /dev/null 2>/dev/null | grep -q "Certificate chain"; then
            log_info "✓ 自签SSL证书有效"
        else
            log_warn "⚠ 自签SSL证书可能有问题，但继续测试..."
        fi
    else
        log_info "检测到Let's Encrypt证书"
        
        # 测试Let's Encrypt证书
        if openssl s_client -connect localhost:8443 -servername localhost < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
            log_info "✓ Let's Encrypt SSL证书有效"
        else
            log_warn "⚠ Let's Encrypt SSL证书可能有问题，但继续测试..."
        fi
    fi
    
    # 测试HTTPS连接
    if curl -k -s -o /dev/null -w "%{http_code}" "$API_BASE_URL/" | grep -q "200"; then
        log_info "✓ HTTPS连接正常"
    else
        log_error "✗ HTTPS连接失败"
        return 1
    fi
}

# 测试API接口
test_api_endpoints() {
    log_test "测试API接口..."
    
    local endpoints=(
        "/"
        "/traffic"
        "/traffic/realtime"
        "/traffic/history"
        "/interfaces"
        "/status"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log_info "测试接口: $endpoint"
        
        response=$(curl -k -s -H "Authorization: Bearer $API_KEY" "$API_BASE_URL$endpoint")
        http_code=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $API_KEY" "$API_BASE_URL$endpoint")
        
        if [ "$http_code" = "200" ]; then
            log_info "✓ $endpoint 接口正常"
            
            # 解析JSON响应
            if echo "$response" | jq . &> /dev/null; then
                log_info "✓ JSON格式正确"
            else
                log_warn "⚠ JSON格式可能有问题"
            fi
        else
            log_error "✗ $endpoint 接口失败 (HTTP $http_code)"
            echo "响应: $response"
        fi
        
        echo
    done
}

# 测试vnstat数据
test_vnstat_data() {
    log_test "测试vnstat数据..."
    
    # 测试基本vnstat命令
    if vnstat --json &> /dev/null; then
        log_info "✓ vnstat --json 命令正常"
        
        # 显示接口信息
        interfaces=$(vnstat --json | jq -r '.interfaces[].name' 2>/dev/null || echo "eth0")
        log_info "检测到的网络接口: $interfaces"
        
        # 测试实时数据
        if vnstat -l --json &> /dev/null; then
            log_info "✓ vnstat实时数据正常"
        else
            log_warn "⚠ vnstat实时数据可能有问题"
        fi
        
        # 测试历史数据
        if vnstat -d --json &> /dev/null; then
            log_info "✓ vnstat历史数据正常"
        else
            log_warn "⚠ vnstat历史数据可能有问题"
        fi
    else
        log_error "✗ vnstat命令失败"
        return 1
    fi
}

# 测试防火墙配置
test_firewall() {
    log_test "测试防火墙配置..."
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "✓ UFW防火墙已启用"
            
            # 检查8443端口规则
            if ufw status | grep -q "8443"; then
                log_info "✓ 8443端口规则已配置"
            else
                log_warn "⚠ 8443端口规则可能未配置"
            fi
        else
            log_warn "⚠ UFW防火墙未启用"
        fi
    else
        log_warn "⚠ UFW未安装"
    fi
}

# 显示测试结果
show_results() {
    log_info "测试完成！"
    echo
    echo "=== 测试结果 ==="
    echo "API地址: $API_BASE_URL"
    echo "API Key: ${API_KEY:0:8}..."
    echo
    echo "=== 手动测试命令 ==="
    echo "测试服务状态:"
    echo "curl -k -H 'Authorization: Bearer $API_KEY' $API_BASE_URL/status"
    echo
    echo "测试流量数据:"
    echo "curl -k -H 'Authorization: Bearer $API_KEY' $API_BASE_URL/traffic"
    echo
    echo "测试实时流量:"
    echo "curl -k -H 'Authorization: Bearer $API_KEY' $API_BASE_URL/traffic/realtime"
    echo
    echo "=== 服务管理 ==="
    echo "查看服务状态: systemctl status vps-api"
    echo "查看服务日志: journalctl -u vps-api -f"
    echo "重启服务: systemctl restart vps-api"
    echo
}

# 主函数
main() {
    log_info "开始测试VPS流量监控API服务..."
    echo
    
    # 获取API Key
    get_api_key
    
    # 运行各项测试
    test_vnstat
    test_api_service
    test_https
    test_api_endpoints
    test_vnstat_data
    test_firewall
    
    show_results
}

# 显示帮助信息
show_help() {
    echo "VPS流量监控系统测试脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -u, --url URL        指定API地址 (默认: https://localhost:8443)"
    echo "  -k, --key KEY        指定API Key"
    echo "  -h, --help           显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 -u https://your-domain.com:8443"
    echo "  $0 -k your-api-key"
    echo
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            API_BASE_URL="$2"
            shift 2
            ;;
        -k|--key)
            API_KEY="$2"
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

# 检查jq是否安装
if ! command -v jq &> /dev/null; then
    log_warn "jq未安装，正在安装..."
    apt update && apt install -y jq
fi

# 运行主函数
main 