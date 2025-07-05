/**
 * Cloudflare Workers 代理服务
 * 功能：转发vnstat数据请求到各VPS节点，提供统一的API接口
 */

import { Router } from 'itty-router';

// 定义接口类型
interface NodeConfig {
  name: string;
  url: string;
  api_key: string;
}

interface NodesConfig {
  [key: string]: NodeConfig;
}

interface ApiResponse {
  status: string;
  data?: any;
  error?: string;
  timestamp: string;
}

// 创建路由器
const router = Router();

// CORS处理函数
function handleCORS(request: Request): Response | null {
  const origin = request.headers.get('Origin');
  const allowedOrigins = env.ALLOWED_ORIGINS || '*';
  
  const headers = new Headers({
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  });

  if (allowedOrigins === '*' || (origin && allowedOrigins.includes(origin))) {
    headers.set('Access-Control-Allow-Origin', origin || '*');
  }

  if (request.method === 'OPTIONS') {
    return new Response(null, { headers });
  }

  return null;
}

// 获取节点配置
function getNodesConfig(): NodesConfig {
  try {
    return JSON.parse(env.NODES_CONFIG || '{}');
  } catch (error) {
    console.error('Failed to parse NODES_CONFIG:', error);
    return {};
  }
}

// 代理请求到VPS节点
async function proxyToNode(nodeId: string, endpoint: string): Promise<Response> {
  const nodes = getNodesConfig();
  const node = nodes[nodeId];
  
  if (!node) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: `Node ${nodeId} not found`,
        timestamp: new Date().toISOString()
      }),
      {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  try {
    const url = `${node.url}${endpoint}`;
    const timeout = parseInt(env.REQUEST_TIMEOUT || '30') * 1000;
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${node.api_key}`,
        'Content-Type': 'application/json',
        'User-Agent': 'VPS-Traffic-Monitor-Worker/1.0'
      },
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error(`Error proxying to node ${nodeId}:`, error);
    
    return new Response(
      JSON.stringify({
        status: 'error',
        error: `Failed to connect to node ${nodeId}: ${error.message}`,
        timestamp: new Date().toISOString()
      }),
      {
        status: 502,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

// 获取所有节点列表
router.get('/api/nodes', async (request: Request) => {
  const nodes = getNodesConfig();
  const nodeList = Object.keys(nodes).map(id => ({
    id,
    name: nodes[id].name,
    url: nodes[id].url
  }));

  return new Response(
    JSON.stringify({
      status: 'success',
      data: nodeList,
      timestamp: new Date().toISOString()
    }),
    {
      headers: { 'Content-Type': 'application/json' }
    }
  );
});

// 获取指定节点的流量数据
router.get('/api/nodes/:nodeId/traffic', async (request: Request) => {
  const nodeId = request.params?.nodeId;
  if (!nodeId) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: 'Node ID is required',
        timestamp: new Date().toISOString()
      }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return proxyToNode(nodeId, '/traffic');
});

// 获取指定节点的实时流量
router.get('/api/nodes/:nodeId/traffic/realtime', async (request: Request) => {
  const nodeId = request.params?.nodeId;
  if (!nodeId) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: 'Node ID is required',
        timestamp: new Date().toISOString()
      }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return proxyToNode(nodeId, '/traffic/realtime');
});

// 获取指定节点的历史流量
router.get('/api/nodes/:nodeId/traffic/history', async (request: Request) => {
  const nodeId = request.params?.nodeId;
  const url = new URL(request.url);
  const period = url.searchParams.get('period') || 'd';
  
  if (!nodeId) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: 'Node ID is required',
        timestamp: new Date().toISOString()
      }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return proxyToNode(nodeId, `/traffic/history?period=${period}`);
});

// 获取指定节点的接口信息
router.get('/api/nodes/:nodeId/interfaces', async (request: Request) => {
  const nodeId = request.params?.nodeId;
  if (!nodeId) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: 'Node ID is required',
        timestamp: new Date().toISOString()
      }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return proxyToNode(nodeId, '/interfaces');
});

// 获取指定节点的状态
router.get('/api/nodes/:nodeId/status', async (request: Request) => {
  const nodeId = request.params?.nodeId;
  if (!nodeId) {
    return new Response(
      JSON.stringify({
        status: 'error',
        error: 'Node ID is required',
        timestamp: new Date().toISOString()
      }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  return proxyToNode(nodeId, '/status');
});

// 获取所有节点的状态
router.get('/api/nodes/status', async (request: Request) => {
  const nodes = getNodesConfig();
  const statusPromises = Object.keys(nodes).map(async (nodeId) => {
    try {
      const response = await proxyToNode(nodeId, '/status');
      const data = await response.json();
      return {
        nodeId,
        name: nodes[nodeId].name,
        status: data.status === 'success' ? 'online' : 'offline',
        data: data.data || data.error
      };
    } catch (error) {
      return {
        nodeId,
        name: nodes[nodeId].name,
        status: 'offline',
        error: error.message
      };
    }
  });

  const results = await Promise.all(statusPromises);

  return new Response(
    JSON.stringify({
      status: 'success',
      data: results,
      timestamp: new Date().toISOString()
    }),
    {
      headers: { 'Content-Type': 'application/json' }
    }
  );
});

// 404处理
router.all('*', () => {
  return new Response(
    JSON.stringify({
      status: 'error',
      error: 'Not found',
      timestamp: new Date().toISOString()
    }),
    {
      status: 404,
      headers: { 'Content-Type': 'application/json' }
    }
  );
});

// 主处理函数
export default {
  async fetch(request: Request, env: any, ctx: any): Promise<Response> {
    // 处理CORS
    const corsResponse = handleCORS(request);
    if (corsResponse) {
      return corsResponse;
    }

    try {
      // 路由请求
      return await router.handle(request, env, ctx);
    } catch (error) {
      console.error('Worker error:', error);
      
      return new Response(
        JSON.stringify({
          status: 'error',
          error: 'Internal server error',
          timestamp: new Date().toISOString()
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }
  }
}; 