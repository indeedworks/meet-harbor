import http, { type ApiResponse } from './http'

export interface OnlineMeeting {
  topic: string
  meetingNo: string
  hostName: string
  participantCount: number
  screenSharing: boolean
  recording: boolean
  startedAt: string
  durationSeconds: number
}

export interface HistoryMeeting {
  topic: string
  meetingNo: string
  creatorName: string
  startedAt: string
  endedAt: string
  participantCount: number
  hasRecording: boolean
  status: string
}

export interface ForceStopMeetingResult {
  meetingNo: string
  status: string
  closedSessions: number
  endedAt: string
}

export function listOnlineMeetingsApi() {
  return http.get<unknown, ApiResponse<OnlineMeeting[]>>('/admin/meetings/online')
}

export function listHistoryMeetingsApi() {
  return http.get<unknown, ApiResponse<HistoryMeeting[]>>('/admin/meetings/history')
}

export function forceStopMeetingApi(meetingNo: string) {
  return http.post<unknown, ApiResponse<ForceStopMeetingResult>>(
    `/admin/meetings/${meetingNo}/force-stop`,
  )
}
