#!/bin/bash

# Ubuntu 22.04 专用安装脚本
# 功能：在Ubuntu 22.04上安装Python 3.11和所有依赖

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_install() {
    echo -e "${BLUE}[INSTALL]${NC} $1"
}

# 检查Ubuntu版本
check_ubuntu_version() {
    log_install "检查Ubuntu版本..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$NAME" == "Ubuntu" && "$VERSION_ID" == "22.04" ]]; then
            log_info "✓ 检测到Ubuntu 22.04"
            return 0
        else
            log_warn "⚠ 当前系统: $NAME $VERSION_ID"
            log_warn "⚠ 此脚本专为Ubuntu 22.04设计"
        fi
    else
        log_warn "⚠ 无法检测系统版本"
    fi
}

# 安装Python 3.11 (Ubuntu 22.04专用)
install_python311_ubuntu22() {
    log_install "安装Python 3.11 (Ubuntu 22.04专用)..."
    
    # 更新包列表
    apt update
    
    # 添加deadsnakes PPA (包含Python 3.11)
    log_info "添加deadsnakes PPA..."
    apt install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt update
    
    # 安装Python 3.11
    log_info "安装Python 3.11..."
    apt install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils
    
    # 安装pip
    log_info "安装pip..."
    apt install -y python3-pip
    
    # 确保pip可用
    python3.11 -m ensurepip --upgrade
    
    # 创建软链接
    ln -sf /usr/bin/python3.11 /usr/bin/python3.11
    ln -sf /usr/bin/pip3 /usr/bin/pip3
    
    log_info "✓ Python 3.11 安装完成"
}

# 安装系统依赖
install_system_deps() {
    log_install "安装系统依赖..."
    
    local deps=(
        "curl"
        "wget"
        "git"
        "jq"
        "openssl"
        "build-essential"
        "zlib1g-dev"
        "libncurses5-dev"
        "libgdbm-dev"
        "libnss3-dev"
        "libssl-dev"
        "libreadline-dev"
        "libffi-dev"
        "libsqlite3-dev"
        "libbz2-dev"
    )
    
    for dep in "${deps[@]}"; do
        log_info "安装 $dep..."
        apt install -y "$dep"
    done
    
    log_info "✓ 系统依赖安装完成"
}

# 安装vnstat
install_vnstat() {
    log_install "安装vnstat..."
    
    apt install -y vnstat
    
    # 启动vnstat服务
    systemctl enable vnstat
    systemctl start vnstat
    
    # 等待vnstat收集初始数据
    log_info "等待vnstat收集初始数据..."
    sleep 10
    
    log_info "✓ vnstat 安装完成"
}

# 验证安装
verify_installation() {
    log_install "验证安装..."
    
    # 检查Python 3.11
    if command -v python3.11 &> /dev/null; then
        local version=$(python3.11 --version 2>&1)
        log_info "✓ Python 3.11: $version"
    else
        log_error "✗ Python 3.11 安装失败"
        return 1
    fi
    
    # 检查pip
    if command -v pip3 &> /dev/null; then
        log_info "✓ pip3 已安装"
    else
        log_error "✗ pip3 安装失败"
        return 1
    fi
    
    # 检查vnstat
    if command -v vnstat &> /dev/null; then
        local vnstat_version=$(vnstat --version | head -n1)
        log_info "✓ vnstat: $vnstat_version"
    else
        log_error "✗ vnstat 安装失败"
        return 1
    fi
    
    # 测试Python功能
    if python3.11 -c "import sys; print('Python 3.11 功能正常')" 2>/dev/null; then
        log_info "✓ Python 3.11 功能正常"
    else
        log_error "✗ Python 3.11 功能异常"
        return 1
    fi
    
    log_info "✓ 所有组件安装成功"
}

# 显示安装信息
show_install_info() {
    log_info "安装完成！"
    echo
    echo "=== 安装信息 ==="
    echo "Python 3.11: $(python3.11 --version 2>&1)"
    echo "pip3: $(pip3 --version 2>&1)"
    echo "vnstat: $(vnstat --version | head -n1)"
    echo
    echo "=== 下一步 ==="
    echo "运行部署脚本: sudo bash scripts/deploy.sh"
    echo
}

# 主函数
main() {
    echo -e "${BLUE}=== Ubuntu 22.04 专用安装脚本 ===${NC}"
    echo
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
    
    # 检查Ubuntu版本
    check_ubuntu_version
    
    # 安装Python 3.11
    install_python311_ubuntu22
    
    # 安装系统依赖
    install_system_deps
    
    # 安装vnstat
    install_vnstat
    
    # 验证安装
    verify_installation
    
    # 显示安装信息
    show_install_info
}

# 显示帮助信息
show_help() {
    echo "Ubuntu 22.04 专用安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help            显示此帮助信息"
    echo
    echo "功能:"
    echo "  - 安装Python 3.11"
    echo "  - 安装系统依赖"
    echo "  - 安装vnstat"
    echo "  - 验证安装结果"
    echo
}

# 解析命令行参数
case "${1:-}" in
    "-h"|"--help")
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac 