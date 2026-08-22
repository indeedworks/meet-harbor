import http, { type ApiResponse } from './http'

export interface AdminRecording {
  id: number
  meetingTopic: string
  meetingNo: string
  status: string
  fileName?: string
  fileSizeBytes: number
  createdAt: string
  expiredAt?: string
}

export function listRecordingsApi() {
  return http.get<unknown, ApiResponse<AdminRecording[]>>('/admin/recordings')
}

export function deleteRecordingApi(id: number) {
  return http.delete<unknown, ApiResponse<void>>(`/admin/recordings/${id}`)
}

