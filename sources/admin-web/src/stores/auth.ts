import { defineStore } from 'pinia'
import { loginApi, type LoginRequest } from '../api/auth'

interface AuthState {
  token: string
  account: string
  nickname: string
  role: string
}

export const useAuthStore = defineStore('auth', {
  state: (): AuthState => ({
    token: localStorage.getItem('access_token') ?? '',
    account: localStorage.getItem('account') ?? '',
    nickname: localStorage.getItem('nickname') ?? '',
    role: localStorage.getItem('role') ?? '',
  }),
  actions: {
    async login(payload: LoginRequest) {
      const response = await loginApi(payload)
      const user = response.data
      this.token = user.accessToken
      this.account = user.account
      this.nickname = user.nickname
      this.role = user.role
      localStorage.setItem('access_token', user.accessToken)
      localStorage.setItem('account', user.account)
      localStorage.setItem('nickname', user.nickname)
      localStorage.setItem('role', user.role)
    },
    logout() {
      this.token = ''
      this.account = ''
      this.nickname = ''
      this.role = ''
      localStorage.removeItem('access_token')
      localStorage.removeItem('account')
      localStorage.removeItem('nickname')
      localStorage.removeItem('role')
    },
  },
})

