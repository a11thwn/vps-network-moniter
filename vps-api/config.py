"""
VPS端API服务配置文件
包含服务器配置、API Key、SSL证书等参数
"""

import os
from typing import Optional

# VPS API服务配置
VPS_CONFIG = {
    # 服务器配置
    "host": "0.0.0.0",  # 监听所有IP地址
    "port": 8443,        # HTTPS端口
    
    # API认证配置
    "api_key": "your-secret-api-key-here",  # 请修改为安全的API Key
    
    # vnstat配置
    "vnstat_path": "/usr/bin/vnstat",  # vnstat命令路径
    
    # SSL证书配置 (HTTPS支持)
    "ssl_keyfile": "/path/to/private.key",   # 私钥文件路径
    "ssl_certfile": "/path/to/certificate.crt",  # 证书文件路径
    
    # 安全配置
    "allowed_ips": [],  # 允许访问的IP列表 (空列表表示允许所有IP)
    
    # 日志配置
    "log_level": "INFO",
    "log_file": "/var/log/vps-traffic-api.log",
    
    # 性能配置
    "request_timeout": 30,  # 请求超时时间(秒)
    "max_connections": 100,  # 最大连接数
}

# 环境变量覆盖配置
def load_config_from_env():
    """从环境变量加载配置"""
    global VPS_CONFIG
    
    # 服务器配置
    if os.getenv("VPS_HOST"):
        VPS_CONFIG["host"] = os.getenv("VPS_HOST")
    if os.getenv("VPS_PORT"):
        VPS_CONFIG["port"] = int(os.getenv("VPS_PORT"))
    
    # API Key
    if os.getenv("VPS_API_KEY"):
        VPS_CONFIG["api_key"] = os.getenv("VPS_API_KEY")
    
    # vnstat路径
    if os.getenv("VNSTAT_PATH"):
        VPS_CONFIG["vnstat_path"] = os.getenv("VNSTAT_PATH")
    
    # SSL证书
    if os.getenv("SSL_KEYFILE"):
        VPS_CONFIG["ssl_keyfile"] = os.getenv("SSL_KEYFILE")
    if os.getenv("SSL_CERTFILE"):
        VPS_CONFIG["ssl_certfile"] = os.getenv("SSL_CERTFILE")
    
    # 允许的IP
    if os.getenv("ALLOWED_IPS"):
        VPS_CONFIG["allowed_ips"] = os.getenv("ALLOWED_IPS").split(",")

# 加载环境变量配置
load_config_from_env()

# 配置验证
def validate_config():
    """验证配置的有效性"""
    errors = []
    
    # 检查vnstat路径
    if not os.path.exists(VPS_CONFIG["vnstat_path"]):
        errors.append(f"vnstat not found at {VPS_CONFIG['vnstat_path']}")
    
    # 检查SSL证书文件 (如果配置了HTTPS)
    if VPS_CONFIG.get("ssl_keyfile") and not os.path.exists(VPS_CONFIG["ssl_keyfile"]):
        errors.append(f"SSL key file not found: {VPS_CONFIG['ssl_keyfile']}")
    
    if VPS_CONFIG.get("ssl_certfile") and not os.path.exists(VPS_CONFIG["ssl_certfile"]):
        errors.append(f"SSL cert file not found: {VPS_CONFIG['ssl_certfile']}")
    
    # 检查API Key
    if not VPS_CONFIG["api_key"] or VPS_CONFIG["api_key"] == "your-secret-api-key-here":
        errors.append("Please set a secure API key")
    elif len(VPS_CONFIG["api_key"]) < 32:
        errors.append("API key should be at least 32 characters long")
    
    return errors

# 获取SSL配置
def get_ssl_config():
    """获取SSL配置，如果证书文件不存在则返回None"""
    if (VPS_CONFIG.get("ssl_keyfile") and 
        VPS_CONFIG.get("ssl_certfile") and
        os.path.exists(VPS_CONFIG["ssl_keyfile"]) and
        os.path.exists(VPS_CONFIG["ssl_certfile"])):
        return {
            "ssl_keyfile": VPS_CONFIG["ssl_keyfile"],
            "ssl_certfile": VPS_CONFIG["ssl_certfile"]
        }
    return None 