<template>
  <el-container class="admin-shell">
    <el-aside class="sidebar" width="232px">
      <div class="brand">远程会议后台</div>
      <el-menu router :default-active="route.path" class="menu">
        <el-menu-item index="/">
          <el-icon><DataBoard /></el-icon>
          <span>系统概览</span>
        </el-menu-item>
        <el-menu-item index="/users">
          <el-icon><User /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
        <el-menu-item index="/meetings">
          <el-icon><VideoPlay /></el-icon>
          <span>会议管理</span>
        </el-menu-item>
        <el-menu-item index="/recordings">
          <el-icon><Files /></el-icon>
          <span>录制管理</span>
        </el-menu-item>
        <el-menu-item index="/operation-logs">
          <el-icon><Document /></el-icon>
          <span>操作日志</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="topbar">
        <div>
          <h1 class="page-title">{{ pageTitle }}</h1>
          <span class="muted">{{ pageSubtitle }}</span>
        </div>
        <el-dropdown>
          <el-button text>
            <el-icon><UserFilled /></el-icon>
            {{ auth.nickname || auth.account }}
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item @click="logout">退出登录</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>

      <el-main class="content">
        <RouterView />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { DataBoard, Document, Files, User, UserFilled, VideoPlay } from '@element-plus/icons-vue'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const pageTitle = computed(() => {
  const titles: Record<string, string> = {
    '/': '系统概览',
    '/users': '用户管理',
    '/meetings': '会议管理',
    '/recordings': '录制管理',
    '/operation-logs': '操作日志',
  }
  return titles[route.path] ?? '远程会议后台'
})
const pageSubtitle = computed(() => {
  const subtitles: Record<string, string> = {
    '/': '会议、录制和服务状态',
    '/users': '创建用户、维护账号状态和重置密码',
    '/meetings': '查看在线会议和历史会议',
    '/recordings': '查看、下载和删除录制文件',
    '/operation-logs': '查看敏感操作审计记录',
  }
  return subtitles[route.path] ?? '远程会议系统'
})

function logout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<style scoped>
.admin-shell {
  min-height: 100vh;
}

.sidebar {
  border-right: 1px solid #e5e7eb;
  background: #ffffff;
}

.brand {
  height: 64px;
  display: flex;
  align-items: center;
  padding: 0 20px;
  border-bottom: 1px solid #e5e7eb;
  font-size: 18px;
  font-weight: 700;
  color: #111827;
}

.menu {
  border-right: 0;
}

.topbar {
  height: 72px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e5e7eb;
  background: #ffffff;
}

.content {
  padding: 24px;
}
</style>
