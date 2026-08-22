import http, { type ApiResponse } from './http'

export interface AdminUser {
  id: number
  account: string
  nickname: string
  role: 'ADMIN' | 'USER'
  status: 'ENABLED' | 'DISABLED'
  createdAt: string
  lastLoginAt?: string
}

export interface CreateUserRequest {
  account: string
  nickname: string
  role: 'ADMIN' | 'USER'
}

export function listUsersApi() {
  return http.get<unknown, ApiResponse<AdminUser[]>>('/admin/users')
}

export function createUserApi(data: CreateUserRequest) {
  return http.post<unknown, ApiResponse<AdminUser>>('/admin/users', data)
}

export function updateUserNicknameApi(id: number, nickname: string) {
  return http.patch<unknown, ApiResponse<AdminUser>>(`/admin/users/${id}/nickname`, { nickname })
}

export function updateUserStatusApi(id: number, status: AdminUser['status']) {
  return http.patch<unknown, ApiResponse<AdminUser>>(`/admin/users/${id}/status`, { status })
}

export function resetUserPasswordApi(id: number) {
  return http.post<unknown, ApiResponse<{ defaultPassword: string }>>(
    `/admin/users/${id}/reset-password`,
  )
}

