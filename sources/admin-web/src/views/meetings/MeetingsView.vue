<template>
  <div class="page-stack">
    <el-card shadow="never">
      <template #header>当前在线会议</template>
      <el-table v-loading="loading" :data="onlineMeetings" size="large">
        <el-table-column prop="topic" label="会议主题" min-width="160" />
        <el-table-column prop="meetingNo" label="会议号" width="130" />
        <el-table-column prop="hostName" label="主持人" width="120" />
        <el-table-column prop="participantCount" label="人数" width="90" />
        <el-table-column label="屏幕共享" width="110">
          <template #default="{ row }">
            <el-tag :type="row.screenSharing ? 'success' : 'info'">
              {{ row.screenSharing ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="录制" width="90">
          <template #default="{ row }">
            <el-tag :type="row.recording ? 'danger' : 'info'">
              {{ row.recording ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="startedAt" label="开始时间" min-width="190" />
        <el-table-column label="持续时长" width="120">
          <template #default="{ row }">{{ formatDuration(row.durationSeconds) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <el-popconfirm
              title="确定强制停止该会议吗？"
              confirm-button-text="停止"
              cancel-button-text="取消"
              confirm-button-type="danger"
              @confirm="forceStop(row)"
            >
              <template #reference>
                <el-button type="danger" size="small" :loading="stoppingMeetingNo === row.meetingNo">
                  强制停止
                </el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card shadow="never">
      <template #header>历史会议</template>
      <el-table v-loading="loading" :data="historyMeetings" size="large">
        <el-table-column prop="topic" label="会议主题" min-width="160" />
        <el-table-column prop="meetingNo" label="会议号" width="130" />
        <el-table-column prop="creatorName" label="创建人" width="120" />
        <el-table-column prop="startedAt" label="开始时间" min-width="190" />
        <el-table-column prop="endedAt" label="结束时间" min-width="190" />
        <el-table-column prop="participantCount" label="参会人数" width="110" />
        <el-table-column label="有录制" width="100">
          <template #default="{ row }">
            <el-tag :type="row.hasRecording ? 'success' : 'info'">
              {{ row.hasRecording ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag type="info">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import {
  forceStopMeetingApi,
  listHistoryMeetingsApi,
  listOnlineMeetingsApi,
  type HistoryMeeting,
  type OnlineMeeting,
} from '../../api/adminMeetings'

const loading = ref(false)
const stoppingMeetingNo = ref('')
const onlineMeetings = ref<OnlineMeeting[]>([])
const historyMeetings = ref<HistoryMeeting[]>([])

function formatDuration(seconds: number) {
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return `${minutes}分${rest}秒`
}

async function refreshMeetings() {
  loading.value = true
  try {
    const [online, history] = await Promise.all([listOnlineMeetingsApi(), listHistoryMeetingsApi()])
    onlineMeetings.value = online.data
    historyMeetings.value = history.data
  } finally {
    loading.value = false
  }
}

async function forceStop(row: OnlineMeeting) {
  stoppingMeetingNo.value = row.meetingNo
  try {
    const response = await forceStopMeetingApi(row.meetingNo)
    ElMessage.success(`已停止会议 ${response.data.meetingNo}，关闭 ${response.data.closedSessions} 个在线会话`)
    await refreshMeetings()
  } finally {
    stoppingMeetingNo.value = ''
  }
}

onMounted(async () => {
  await refreshMeetings()
})
</script>

<style scoped>
.page-stack {
  display: grid;
  gap: 16px;
}
</style>
