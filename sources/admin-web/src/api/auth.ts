import http, { type ApiResponse } from './http'

export interface LoginRequest {
  account: string
  password: string
}

export interface LoginResponse {
  accessToken: string
  expiresAt: string
  account: string
  nickname: string
  role: string
}

export function loginApi(data: LoginRequest) {
  return http.post<unknown, ApiResponse<LoginResponse>>('/auth/login', data)
}
