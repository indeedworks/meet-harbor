import http, { type ApiResponse } from './http'

export interface OperationLog {
  id: number
  operatorAccount?: string
  action: string
  targetType?: string
  targetId?: number
  clientIp?: string
  userAgent?: string
  detail?: string
  createdAt: string
}

export function listOperationLogsApi() {
  return http.get<unknown, ApiResponse<OperationLog[]>>('/admin/operation-logs')
}

