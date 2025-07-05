"""
VPS端API服务启动脚本
包含配置验证、SSL支持和错误处理
"""

import uvicorn
import sys
import os
from config import VPS_CONFIG, validate_config, get_ssl_config

def main():
    """主启动函数"""
    print("=== VPS Traffic Monitor API ===")
    
    # 验证配置
    print("正在验证配置...")
    errors = validate_config()
    
    if errors:
        print("配置错误:")
        for error in errors:
            print(f"  - {error}")
        print("\n请修复上述错误后重新启动服务。")
        sys.exit(1)
    
    print("配置验证通过!")
    
    # 获取SSL配置
    ssl_config = get_ssl_config()
    if ssl_config:
        print(f"启用HTTPS模式，端口: {VPS_CONFIG['port']}")
        print(f"SSL证书: {ssl_config['ssl_certfile']}")
        print(f"SSL私钥: {ssl_config['ssl_keyfile']}")
    else:
        print(f"启用HTTP模式，端口: {VPS_CONFIG['port']}")
        print("注意: 未配置SSL证书，将使用HTTP协议")
    
    print(f"API Key: {VPS_CONFIG['api_key'][:8]}...")
    print(f"vnstat路径: {VPS_CONFIG['vnstat_path']}")
    print("\n启动服务...")
    
    # 启动服务器
    try:
        uvicorn.run(
            "main:app",
            host=VPS_CONFIG["host"],
            port=VPS_CONFIG["port"],
            ssl_keyfile=ssl_config["ssl_keyfile"] if ssl_config else None,
            ssl_certfile=ssl_config["ssl_certfile"] if ssl_config else None,
            reload=False,  # 生产环境关闭热重载
            access_log=True,
            log_level=VPS_CONFIG["log_level"].lower()
        )
    except KeyboardInterrupt:
        print("\n服务已停止")
    except Exception as e:
        print(f"启动服务时发生错误: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 