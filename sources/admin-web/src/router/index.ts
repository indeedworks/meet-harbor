import { createRouter, createWebHistory } from 'vue-router'
import AdminLayout from '../layouts/AdminLayout.vue'
import LoginView from '../views/login/LoginView.vue'
import DashboardView from '../views/dashboard/DashboardView.vue'
import UsersView from '../views/users/UsersView.vue'
import MeetingsView from '../views/meetings/MeetingsView.vue'
import RecordingsView from '../views/recordings/RecordingsView.vue'
import OperationLogsView from '../views/logs/OperationLogsView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: LoginView,
    },
    {
      path: '/',
      component: AdminLayout,
      children: [
        {
          path: '',
          name: 'dashboard',
          component: DashboardView,
        },
        {
          path: 'users',
          name: 'users',
          component: UsersView,
        },
        {
          path: 'meetings',
          name: 'meetings',
          component: MeetingsView,
        },
        {
          path: 'recordings',
          name: 'recordings',
          component: RecordingsView,
        },
        {
          path: 'operation-logs',
          name: 'operation-logs',
          component: OperationLogsView,
        },
      ],
    },
  ],
})

router.beforeEach((to) => {
  const token = localStorage.getItem('access_token')
  if (to.name !== 'login' && !token) {
    return { name: 'login' }
  }
  if (to.name === 'login' && token) {
    return { name: 'dashboard' }
  }
  return true
})

export default router
