import http, { type ApiResponse } from './http'

export interface SystemHealth {
  status: string
  serverTime: string
}

export interface SystemOverview {
  currentMeetingCount: number
  currentOnlineUserCount: number
  currentRecordingTaskCount: number
  recordingFileBytes: number
  totalStorageBytes: number
  usedStorageBytes: number
  freeStorageBytes: number
  recordingUsedBytes: number
  expiringRecordingCount: number
  cpuUsagePercent: number
  memoryUsagePercent: number
  diskUsagePercent: number
  bandwidthBytesPerSecond: number
  mediaServiceStatus: string
  recordingServiceStatus: string
  signalingServiceStatus: string
  serverTime: string
}

export function getSystemHealth() {
  return http.get<unknown, ApiResponse<SystemHealth>>('/system/health')
}

export function getSystemOverview() {
  return http.get<unknown, ApiResponse<SystemOverview>>('/admin/system/overview')
}

