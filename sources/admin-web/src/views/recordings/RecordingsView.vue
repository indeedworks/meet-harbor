<template>
  <div class="page-stack">
    <el-card shadow="never">
      <el-table v-loading="loading" :data="recordings" size="large">
        <el-table-column prop="meetingTopic" label="会议主题" min-width="160" />
        <el-table-column prop="meetingNo" label="会议号" width="130" />
        <el-table-column label="状态" width="130">
          <template #default="{ row }">
            <el-tag :type="statusType(row.status)">{{ statusText(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="fileName" label="文件名" min-width="200">
          <template #default="{ row }">{{ row.fileName ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="文件大小" width="120">
          <template #default="{ row }">{{ formatBytes(row.fileSizeBytes) }}</template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" min-width="190" />
        <el-table-column prop="expiredAt" label="过期时间" min-width="190">
          <template #default="{ row }">{{ row.expiredAt ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" :disabled="row.status !== 'COMPLETED'" @click="downloadRecording(row)">下载</el-button>
            <el-button text type="danger" @click="deleteRecording(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  deleteRecordingApi,
  downloadRecordingApi,
  listRecordingsApi,
  type AdminRecording,
} from '../../api/adminRecordings'

const loading = ref(false)
const recordings = ref<AdminRecording[]>([])

function statusType(status: string) {
  const map: Record<string, 'success' | 'warning' | 'danger' | 'info'> = {
    COMPLETED: 'success',
    PROCESSING: 'warning',
    FAILED: 'danger',
    DELETED: 'info',
  }
  return map[status] ?? 'info'
}

function statusText(status: string) {
  const map: Record<string, string> = {
    RECORDING: '录制中',
    PROCESSING: '处理中',
    COMPLETED: '完成',
    FAILED: '失败',
    EXPIRED: '已过期',
    DELETED: '已删除',
  }
  return map[status] ?? status
}

function formatBytes(bytes: number) {
  if (!bytes) return '-'
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
}

async function loadRecordings() {
  loading.value = true
  try {
    const response = await listRecordingsApi()
    recordings.value = response.data
  } finally {
    loading.value = false
  }
}

async function deleteRecording(recording: AdminRecording) {
  await ElMessageBox.confirm(`确定删除「${recording.meetingTopic}」的录制文件吗？`, '删除录制', {
    confirmButtonText: '删除',
    cancelButtonText: '取消',
    type: 'warning',
  })
  await deleteRecordingApi(recording.id)
  ElMessage.success('录制已删除')
  await loadRecordings()
}

async function downloadRecording(recording: AdminRecording) {
  const blob = await downloadRecordingApi(recording.id)
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = recording.fileName ?? `meeting-${recording.meetingNo}.mp4`
  link.click()
  URL.revokeObjectURL(url)
}

onMounted(loadRecordings)
</script>

<style scoped>
.page-stack {
  display: grid;
  gap: 16px;
}
</style>
