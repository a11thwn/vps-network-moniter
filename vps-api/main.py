"""
VPS端流量监控API服务
功能：提供vnstat数据的HTTP API接口，支持HTTPS访问和API Key认证
"""

import uvicorn
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import subprocess
import json
import time
from datetime import datetime
import logging
from typing import Dict, Any, Optional
import os
from config import VPS_CONFIG

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建FastAPI应用
app = FastAPI(
    title="VPS Traffic Monitor API",
    description="提供vnstat流量数据的API服务",
    version="1.0.0"
)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key认证
security = HTTPBearer()

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)) -> bool:
    """验证API Key"""
    if credentials.credentials != VPS_CONFIG["api_key"]:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True

def get_vnstat_data(command_args: list) -> Dict[str, Any]:
    """执行vnstat命令并返回JSON数据"""
    try:
        # 构建完整命令
        cmd = [VPS_CONFIG["vnstat_path"]] + command_args + ["--json"]
        
        # 执行命令
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            logger.error(f"vnstat command failed: {result.stderr}")
            raise HTTPException(status_code=500, detail="Failed to get vnstat data")
        
        # 解析JSON数据
        data = json.loads(result.stdout)
        return data
        
    except subprocess.TimeoutExpired:
        logger.error("vnstat command timeout")
        raise HTTPException(status_code=500, detail="vnstat command timeout")
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse vnstat JSON: {e}")
        raise HTTPException(status_code=500, detail="Invalid vnstat data format")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/")
async def root():
    """根路径，返回服务状态"""
    return {
        "status": "running",
        "service": "VPS Traffic Monitor API",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/traffic")
async def get_traffic_data(verified: bool = Depends(verify_api_key)):
    """获取当前流量数据"""
    try:
        data = get_vnstat_data([])
        return {
            "status": "success",
            "data": data,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting traffic data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/traffic/realtime")
async def get_realtime_traffic(verified: bool = Depends(verify_api_key)):
    """获取实时流量数据"""
    try:
        # 使用-l参数获取实时数据
        data = get_vnstat_data(["-l"])
        return {
            "status": "success",
            "data": data,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting realtime traffic: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/traffic/history")
async def get_history_traffic(
    period: str = "d",  # d=day, m=month, h=hour
    verified: bool = Depends(verify_api_key)
):
    """获取历史流量数据"""
    try:
        # 根据period参数获取不同时间段的数据
        if period == "d":
            data = get_vnstat_data(["-d"])
        elif period == "m":
            data = get_vnstat_data(["-m"])
        elif period == "h":
            data = get_vnstat_data(["-h"])
        else:
            raise HTTPException(status_code=400, detail="Invalid period parameter")
        
        return {
            "status": "success",
            "data": data,
            "period": period,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting history traffic: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/interfaces")
async def get_interfaces(verified: bool = Depends(verify_api_key)):
    """获取所有网络接口信息"""
    try:
        data = get_vnstat_data([])
        interfaces = []
        
        if "interfaces" in data:
            for interface in data["interfaces"]:
                interfaces.append({
                    "name": interface.get("name"),
                    "alias": interface.get("alias"),
                    "created": interface.get("created")
                })
        
        return {
            "status": "success",
            "interfaces": interfaces,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting interfaces: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/status")
async def get_status(verified: bool = Depends(verify_api_key)):
    """获取服务状态和vnstat状态"""
    try:
        # 检查vnstat是否可用
        result = subprocess.run([VPS_CONFIG["vnstat_path"], "--version"], 
                              capture_output=True, text=True)
        
        vnstat_status = "available" if result.returncode == 0 else "unavailable"
        
        return {
            "status": "success",
            "service": "running",
            "vnstat_status": vnstat_status,
            "vnstat_version": result.stdout.strip() if result.returncode == 0 else None,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # 启动服务器，支持HTTPS
    uvicorn.run(
        "main:app",
        host=VPS_CONFIG["host"],
        port=VPS_CONFIG["port"],
        ssl_keyfile=VPS_CONFIG.get("ssl_keyfile"),
        ssl_certfile=VPS_CONFIG.get("ssl_certfile"),
        reload=True
    ) 