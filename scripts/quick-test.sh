#!/bin/bash

# 快速测试脚本
# 功能：快速验证VPS流量监控系统的基本功能

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== VPS流量监控系统快速测试 ===${NC}"
echo

# 1. 检查vnstat
echo "1. 检查vnstat..."
if command -v vnstat &> /dev/null; then
    echo -e "${GREEN}✓ vnstat已安装${NC}"
    vnstat --version | head -n1
else
    echo -e "${RED}✗ vnstat未安装${NC}"
    exit 1
fi
echo

# 2. 检查API服务
echo "2. 检查API服务..."
if systemctl is-active --quiet vps-api; then
    echo -e "${GREEN}✓ vps-api服务正在运行${NC}"
else
    echo -e "${YELLOW}⚠ vps-api服务未运行，正在启动...${NC}"
    systemctl start vps-api
    sleep 3
    
    # 检查启动是否成功
    if ! systemctl is-active --quiet vps-api; then
        echo -e "${RED}✗ 服务启动失败，查看错误日志:${NC}"
        journalctl -u vps-api --no-pager -n 10
        echo
        echo -e "${YELLOW}尝试运行修复脚本...${NC}"
        if [ -f "scripts/fix-config.sh" ]; then
            bash scripts/fix-config.sh
        else
            echo -e "${RED}修复脚本不存在，请重新部署${NC}"
        fi
        exit 1
    fi
fi
echo

# 3. 检查端口
echo "3. 检查端口监听..."
if ss -tlnp | grep -q ":8443"; then
    echo -e "${GREEN}✓ 8443端口正在监听${NC}"
else
    echo -e "${RED}✗ 8443端口未监听${NC}"
    echo "尝试检查服务状态..."
    systemctl status vps-api --no-pager
    echo
    echo "查看服务日志:"
    journalctl -u vps-api --no-pager -n 20
    echo
    echo "尝试手动启动服务..."
    systemctl restart vps-api
    sleep 3
    systemctl status vps-api --no-pager
    exit 1
fi
echo

# 4. 获取API Key
echo "4. 获取API Key..."
if [ -f "/opt/vps-network-moniter/vps-api/config.py" ]; then
    API_KEY=$(grep -o 'api_key.*=.*"[^"]*"' /opt/vps-network-moniter/vps-api/config.py | cut -d'"' -f2)
    if [ "$API_KEY" != "your-secret-api-key-here" ]; then
        echo -e "${GREEN}✓ API Key已配置${NC}"
    else
        echo -e "${RED}✗ API Key未配置${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ 配置文件不存在${NC}"
    exit 1
fi
echo

# 5. 测试API连接
echo "5. 测试API连接..."
response=$(curl -k -s -H "Authorization: Bearer $API_KEY" https://localhost:8443/status)
if echo "$response" | grep -q "success"; then
    echo -e "${GREEN}✓ API连接正常${NC}"
else
    echo -e "${RED}✗ API连接失败${NC}"
    echo "响应: $response"
    exit 1
fi
echo

# 6. 测试vnstat数据
echo "6. 测试vnstat数据..."
if vnstat --json &> /dev/null; then
    echo -e "${GREEN}✓ vnstat数据正常${NC}"
    
    # 显示接口信息
    interfaces=$(vnstat --json | jq -r '.interfaces[].name' 2>/dev/null || echo "eth0")
    echo "网络接口: $interfaces"
else
    echo -e "${RED}✗ vnstat数据异常${NC}"
    exit 1
fi
echo

# 7. 显示测试结果
echo -e "${GREEN}=== 测试完成！系统运行正常 ===${NC}"
echo
echo "=== 可用命令 ==="
echo "查看服务状态: systemctl status vps-api"
echo "查看服务日志: journalctl -u vps-api -f"
echo "测试API: curl -k -H 'Authorization: Bearer $API_KEY' https://localhost:8443/traffic"
echo "查看vnstat: vnstat --json"
echo
echo "=== 下一步 ==="
echo "1. 配置Workers代理"
echo "2. 部署前端"
echo "3. 访问监控页面" 