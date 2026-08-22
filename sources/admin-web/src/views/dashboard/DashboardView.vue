<template>
  <div class="dashboard">
    <el-row :gutter="16">
      <el-col v-for="item in stats" :key="item.label" :xs="24" :sm="12" :lg="6">
        <el-card shadow="never" class="stat-card">
          <span class="stat-label">{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16">
      <el-col :xs="24" :lg="12">
        <el-card shadow="never">
          <template #header>系统运行状态</template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="CPU 使用率">
              {{ overview?.cpuUsagePercent ?? 0 }}%
            </el-descriptions-item>
            <el-descriptions-item label="内存使用率">
              {{ overview?.memoryUsagePercent ?? 0 }}%
            </el-descriptions-item>
            <el-descriptions-item label="磁盘使用率">
              {{ overview?.diskUsagePercent ?? 0 }}%
            </el-descriptions-item>
            <el-descriptions-item label="带宽">
              {{ formatBytes(overview?.bandwidthBytesPerSecond ?? 0) }}/s
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <el-col :xs="24" :lg="12">
        <el-card shadow="never">
          <template #header>服务状态</template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="业务服务">
              <el-tag :type="health?.status === 'UP' ? 'success' : 'danger'">
                {{ health?.status ?? 'UNKNOWN' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="媒体服务">
              <el-tag :type="overview?.mediaServiceStatus === 'UP' ? 'success' : 'danger'">
                {{ overview?.mediaServiceStatus ?? 'UNKNOWN' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="录制服务">
              <el-tag :type="overview?.recordingServiceStatus === 'UP' ? 'success' : 'danger'">
                {{ overview?.recordingServiceStatus ?? 'UNKNOWN' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="信令服务">
              <el-tag :type="overview?.signalingServiceStatus === 'UP' ? 'success' : 'danger'">
                {{ overview?.signalingServiceStatus ?? 'UNKNOWN' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="服务器时间">
              {{ overview?.serverTime ?? health?.serverTime ?? '-' }}
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never">
      <template #header>存储空间</template>
      <el-row :gutter="16">
        <el-col :xs="24" :sm="12" :lg="6">
          <div class="storage-item">
            <span>总空间</span>
            <strong>{{ formatBytes(overview?.totalStorageBytes ?? 0) }}</strong>
          </div>
        </el-col>
        <el-col :xs="24" :sm="12" :lg="6">
          <div class="storage-item">
            <span>已用空间</span>
            <strong>{{ formatBytes(overview?.usedStorageBytes ?? 0) }}</strong>
          </div>
        </el-col>
        <el-col :xs="24" :sm="12" :lg="6">
          <div class="storage-item">
            <span>剩余空间</span>
            <strong>{{ formatBytes(overview?.freeStorageBytes ?? 0) }}</strong>
          </div>
        </el-col>
        <el-col :xs="24" :sm="12" :lg="6">
          <div class="storage-item">
            <span>即将清理</span>
            <strong>{{ overview?.expiringRecordingCount ?? 0 }}</strong>
          </div>
        </el-col>
      </el-row>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  getSystemHealth,
  getSystemOverview,
  type SystemHealth,
  type SystemOverview,
} from '../../api/system'

const health = ref<SystemHealth>()
const overview = ref<SystemOverview>()

const stats = computed(() => [
  { label: '当前会议数', value: String(overview.value?.currentMeetingCount ?? 0) },
  { label: '在线人数', value: String(overview.value?.currentOnlineUserCount ?? 0) },
  { label: '录制任务', value: String(overview.value?.currentRecordingTaskCount ?? 0) },
  { label: '录制占用', value: formatBytes(overview.value?.recordingFileBytes ?? 0) },
])

function formatBytes(bytes: number) {
  if (!bytes) return '0 B'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
}

onMounted(async () => {
  const [healthResponse, overviewResponse] = await Promise.all([
    getSystemHealth(),
    getSystemOverview(),
  ])
  health.value = healthResponse.data
  overview.value = overviewResponse.data
})
</script>

<style scoped>
.dashboard {
  display: grid;
  gap: 16px;
}

.stat-card {
  min-height: 112px;
}

.stat-card :deep(.el-card__body) {
  display: grid;
  gap: 12px;
}

.stat-label,
.storage-item span {
  color: #6b7280;
  font-size: 14px;
}

strong {
  color: #111827;
  font-size: 30px;
  line-height: 1;
}

.storage-item {
  min-height: 86px;
  display: grid;
  align-content: center;
  gap: 10px;
  padding: 16px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fbfcff;
}

.storage-item strong {
  font-size: 24px;
}
</style>

