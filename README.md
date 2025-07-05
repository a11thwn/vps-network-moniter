# VPS流量监控系统

一个基于vnstat的VPS流量监控系统，支持多节点监控、实时数据展示和历史流量统计。

## 系统架构

```
VPS节点 (Python API + vnstat) → Cloudflare Workers (代理) → Vue前端 (展示)
```

### 技术栈
- **VPS端**: Python + FastAPI + vnstat
- **代理层**: Cloudflare Workers
- **前端**: Vue 3 + Element Plus + ECharts
- **通信**: HTTPS + API Key认证

## 功能特性

- ✅ 多VPS节点流量监控
- ✅ 实时流量数据展示
- ✅ 历史流量统计图表
- ✅ HTTPS安全访问
- ✅ API Key认证
- ✅ 响应式Web界面
- ✅ 自动数据刷新

## 快速开始

### 1. VPS端部署

#### 安装依赖
```bash
# 创建Python虚拟环境
python3.11 -m venv venv
source venv/bin/activate

# 安装依赖
cd vps-api
pip install -r requirements.txt
```

#### 配置SSL证书
```bash
# 使用Let's Encrypt获取免费SSL证书
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 证书文件位置
# /etc/letsencrypt/live/your-domain.com/privkey.pem
# /etc/letsencrypt/live/your-domain.com/fullchain.pem
```

#### 修改配置
编辑 `vps-api/config.py`:
```python
VPS_CONFIG = {
    "host": "0.0.0.0",
    "port": 8443,
    "api_key": "your-secure-api-key",  # 修改为安全的API Key
    "vnstat_path": "/usr/bin/vnstat",
    "ssl_keyfile": "/etc/letsencrypt/live/your-domain.com/privkey.pem",
    "ssl_certfile": "/etc/letsencrypt/live/your-domain.com/fullchain.pem",
}
```

#### 启动服务
```bash
# 开发模式
python start.py

# 生产模式 (使用systemd)
sudo cp vps-api.service /etc/systemd/system/
sudo systemctl enable vps-api
sudo systemctl start vps-api
```

### 2. Cloudflare Workers部署

#### 安装Wrangler
```bash
npm install -g wrangler
wrangler login
```

#### 配置节点信息
编辑 `workers/wrangler.toml`:
```toml
[vars]
NODES_CONFIG = '''
{
  "node1": {
    "name": "VPS Node 1",
    "url": "https://your-vps1-domain.com:8443",
    "api_key": "your-secure-api-key"
  },
  "node2": {
    "name": "VPS Node 2", 
    "url": "https://your-vps2-domain.com:8443",
    "api_key": "your-secure-api-key"
  }
}
'''
```

#### 部署Workers
```bash
cd workers
npm install
wrangler deploy
```

### 3. 前端部署

#### 安装依赖
```bash
cd frontend
npm install
```

#### 配置API地址
编辑 `frontend/src/api/config.ts`:
```typescript
export const API_BASE_URL = 'https://your-workers-domain.workers.dev'
```

#### 开发模式
```bash
npm run dev
```

#### 生产部署
```bash
npm run build
# 部署到Cloudflare Pages或其他静态托管服务
```

## API接口

### VPS端API (需要API Key认证)

```
GET /                    # 服务状态
GET /traffic            # 获取流量数据
GET /traffic/realtime   # 获取实时流量
GET /traffic/history    # 获取历史流量 (参数: period=d/m/h)
GET /interfaces         # 获取网络接口信息
GET /status             # 获取服务状态
```

### Workers代理API

```
GET /api/nodes                    # 获取所有节点列表
GET /api/nodes/{nodeId}/traffic  # 获取指定节点流量
GET /api/nodes/{nodeId}/traffic/realtime  # 获取实时流量
GET /api/nodes/{nodeId}/traffic/history   # 获取历史流量
GET /api/nodes/{nodeId}/interfaces        # 获取接口信息
GET /api/nodes/{nodeId}/status            # 获取节点状态
GET /api/nodes/status                     # 获取所有节点状态
```

## 安全配置

### 1. API Key安全
- 使用强密码生成API Key
- 定期更换API Key
- 不同节点使用不同的API Key

### 2. SSL证书
- 使用Let's Encrypt免费证书
- 配置自动续期
- 强制HTTPS访问

### 3. 防火墙配置
```bash
# 只允许Cloudflare IP访问
sudo ufw allow from 173.245.48.0/20 to any port 8443
sudo ufw allow from 103.21.244.0/22 to any port 8443
# 添加更多Cloudflare IP段...
```

## 监控和维护

### 1. 服务监控
```bash
# 检查服务状态
sudo systemctl status vps-api

# 查看日志
sudo journalctl -u vps-api -f

# 检查vnstat状态
vnstat --version
```

### 2. 数据备份
```bash
# 备份vnstat数据
sudo cp -r /var/lib/vnstat /backup/vnstat-$(date +%Y%m%d)
```

### 3. 性能优化
- 配置nginx反向代理
- 启用gzip压缩
- 设置缓存策略

## 故障排除

### 常见问题

1. **vnstat命令失败**
   ```bash
   # 检查vnstat安装
   which vnstat
   vnstat --version
   
   # 检查权限
   sudo chown -R vnstat:vnstat /var/lib/vnstat
   ```

2. **SSL证书问题**
   ```bash
   # 检查证书文件
   sudo ls -la /etc/letsencrypt/live/your-domain.com/
   
   # 测试证书
   openssl s_client -connect your-domain.com:8443
   ```

3. **API连接失败**
   ```bash
   # 测试API连接
   curl -H "Authorization: Bearer your-api-key" \
        https://your-domain.com:8443/status
   ```

## 开发指南

### 项目结构
```
vps-network-monitor/
├── vps-api/           # VPS端API服务
├── workers/           # Cloudflare Workers
├── frontend/          # Vue前端
├── scripts/           # 工具脚本
└── docs/             # 文档
```

### 开发环境
- Python 3.11+
- Node.js 18+
- vnstat 2.x

### 贡献指南
1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

## 许可证

MIT License

## 支持

如有问题，请提交Issue或联系维护者。 