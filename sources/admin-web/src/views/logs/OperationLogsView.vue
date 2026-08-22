<template>
  <el-card shadow="never">
    <el-table v-loading="loading" :data="logs" size="large">
      <el-table-column prop="createdAt" label="时间" min-width="190" />
      <el-table-column prop="operatorAccount" label="操作人" width="130">
        <template #default="{ row }">{{ row.operatorAccount ?? '-' }}</template>
      </el-table-column>
      <el-table-column prop="action" label="操作" width="170">
        <template #default="{ row }">
          <el-tag type="info">{{ actionText(row.action) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="targetType" label="对象类型" width="120">
        <template #default="{ row }">{{ row.targetType ?? '-' }}</template>
      </el-table-column>
      <el-table-column prop="targetId" label="对象 ID" width="110">
        <template #default="{ row }">{{ row.targetId ?? '-' }}</template>
      </el-table-column>
      <el-table-column prop="clientIp" label="IP" min-width="140">
        <template #default="{ row }">{{ row.clientIp ?? '-' }}</template>
      </el-table-column>
      <el-table-column prop="detail" label="详情" min-width="220">
        <template #default="{ row }">{{ row.detail ?? '-' }}</template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { listOperationLogsApi, type OperationLog } from '../../api/operationLogs'

const loading = ref(false)
const logs = ref<OperationLog[]>([])

function actionText(action: string) {
  const map: Record<string, string> = {
    LOGIN: '登录',
    CREATE_USER: '创建用户',
    UPDATE_USER: '修改用户',
    DISABLE_USER: '禁用用户',
    ENABLE_USER: '启用用户',
    RESET_PASSWORD: '重置密码',
    CHANGE_PASSWORD: '修改密码',
    DELETE_RECORDING: '删除录制',
  }
  return map[action] ?? action
}

onMounted(async () => {
  loading.value = true
  try {
    const response = await listOperationLogsApi()
    logs.value = response.data
  } finally {
    loading.value = false
  }
})
</script>

