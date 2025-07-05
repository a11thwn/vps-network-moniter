#!/bin/bash

# Python版本检查脚本
# 功能：检查Python 3.11安装状态

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

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

# 检查Python版本
check_python_version() {
    log_check "检查Python版本..."
    
    # 检查python3.11
    if command -v python3.11 &> /dev/null; then
        local version=$(python3.11 --version 2>&1)
        log_info "✓ Python 3.11 已安装: $version"
        
        # 检查pip
        if command -v pip3 &> /dev/null; then
            log_info "✓ pip3 已安装"
        else
            log_warn "⚠ pip3 未安装"
        fi
        
        return 0
    else
        log_error "✗ Python 3.11 未安装"
        return 1
    fi
}

# 检查Python路径
check_python_path() {
    log_check "检查Python路径..."
    
    local python_paths=(
        "/usr/bin/python3.11"
        "/usr/local/bin/python3.11"
        "/opt/vps-traffic-monitor/venv/bin/python"
    )
    
    for path in "${python_paths[@]}"; do
        if [ -f "$path" ]; then
            log_info "✓ 找到Python: $path"
            "$path" --version 2>/dev/null || log_warn "⚠ $path 无法执行"
        fi
    done
}

# 检查虚拟环境
check_venv() {
    log_check "检查虚拟环境..."
    
    local venv_path="/opt/vps-traffic-monitor/venv"
    
    if [ -d "$venv_path" ]; then
        log_info "✓ 虚拟环境存在: $venv_path"
        
        if [ -f "$venv_path/bin/python" ]; then
            local version=$("$venv_path/bin/python" --version 2>&1)
            log_info "✓ 虚拟环境Python版本: $version"
        else
            log_error "✗ 虚拟环境Python不存在"
        fi
        
        if [ -f "$venv_path/bin/pip" ]; then
            log_info "✓ 虚拟环境pip存在"
        else
            log_error "✗ 虚拟环境pip不存在"
        fi
    else
        log_warn "⚠ 虚拟环境不存在: $venv_path"
    fi
}

# 检查依赖包
check_dependencies() {
    log_check "检查Python依赖包..."
    
    local venv_path="/opt/vps-traffic-monitor/venv"
    
    if [ -f "$venv_path/bin/python" ]; then
        local required_packages=("fastapi" "uvicorn" "pydantic")
        
        for package in "${required_packages[@]}"; do
            if "$venv_path/bin/python" -c "import $package" 2>/dev/null; then
                log_info "✓ $package 已安装"
            else
                log_error "✗ $package 未安装"
            fi
        done
    else
        log_error "✗ 无法检查依赖包，虚拟环境Python不存在"
    fi
}

# 安装Python 3.11
install_python311() {
    log_check "安装Python 3.11..."
    
    # 更新包列表
    apt update
    
    # 尝试从包管理器安装
    if apt install -y python3.11 python3.11-venv python3.11-dev python3-pip; then
        log_info "✓ 通过包管理器安装成功"
        return 0
    fi
    
    log_warn "⚠ 包管理器安装失败，尝试源码编译..."
    
    # 安装编译依赖
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
    ln -sf /usr/local/bin/pip3.11 /usr/bin/pip3
    
    # 确保pip可用
    python3.11 -m ensurepip --upgrade
    
    log_info "✓ 源码编译安装成功"
}

# 显示帮助信息
show_help() {
    echo "Python版本检查脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  check                  检查Python版本"
    echo "  install                安装Python 3.11"
    echo "  all                    执行所有检查"
    echo "  -h, --help            显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 check               # 检查Python版本"
    echo "  $0 install             # 安装Python 3.11"
    echo "  $0 all                 # 执行所有检查"
    echo
}

# 主函数
main() {
    case "${1:-all}" in
        "check")
            check_python_version
            check_python_path
            check_venv
            check_dependencies
            ;;
        "install")
            install_python311
            ;;
        "all")
            echo -e "${BLUE}=== Python版本检查 ===${NC}"
            echo
            check_python_version
            echo
            check_python_path
            echo
            check_venv
            echo
            check_dependencies
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