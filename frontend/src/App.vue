<template>
  <div id="app">
    <el-container>
      <el-header>
        <div class="header-content">
          <h1>VPS流量监控系统</h1>
          <div class="header-actions">
            <el-button @click="refreshAll" :loading="loading">
              <el-icon><Refresh /></el-icon>
              刷新
            </el-button>
          </div>
        </div>
      </el-header>
      
      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Refresh } from '@element-plus/icons-vue'

const router = useRouter()
const loading = ref(false)

const refreshAll = async () => {
  loading.value = true
  try {
    // 刷新当前页面
    await router.go(0)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
#app {
  height: 100vh;
}

.el-container {
  height: 100%;
}

.el-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  display: flex;
  align-items: center;
  padding: 0 20px;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.header-content h1 {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.el-main {
  padding: 20px;
  background-color: #f5f7fa;
}
</style> 