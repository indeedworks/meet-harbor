<template>
  <div class="page-stack">
    <div class="toolbar">
      <el-button type="primary" :icon="Plus" @click="openCreate">创建用户</el-button>
    </div>

    <el-card shadow="never">
      <el-table v-loading="loading" :data="users" size="large">
        <el-table-column prop="account" label="登录账号" min-width="140" />
        <el-table-column prop="nickname" label="昵称" min-width="140" />
        <el-table-column prop="role" label="角色" width="110">
          <template #default="{ row }">
            <el-tag :type="row.role === 'ADMIN' ? 'warning' : 'info'">
              {{ roleText(row.role) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="row.status === 'ENABLED' ? 'success' : 'danger'">
              {{ statusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" min-width="190" />
        <el-table-column prop="lastLoginAt" label="最近登录" min-width="190">
          <template #default="{ row }">{{ row.lastLoginAt ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openEdit(row)">改昵称</el-button>
            <el-button text type="primary" @click="resetPassword(row)">重置密码</el-button>
            <el-button
              text
              :type="row.status === 'ENABLED' ? 'danger' : 'success'"
              @click="toggleStatus(row)"
            >
              {{ row.status === 'ENABLED' ? '禁用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="editingUser ? '修改昵称' : '创建用户'" width="420px">
      <el-form :model="form" label-position="top">
        <el-form-item v-if="!editingUser" label="登录账号">
          <el-input v-model="form.account" />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="form.nickname" />
        </el-form-item>
        <el-form-item v-if="!editingUser" label="角色">
          <el-select v-model="form.role" class="full-width">
            <el-option label="普通用户" value="USER" />
            <el-option label="管理员" value="ADMIN" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveUser">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import {
  createUserApi,
  listUsersApi,
  resetUserPasswordApi,
  updateUserNicknameApi,
  updateUserStatusApi,
  type AdminUser,
} from '../../api/adminUsers'

const loading = ref(false)
const saving = ref(false)
const dialogVisible = ref(false)
const editingUser = ref<AdminUser>()
const users = ref<AdminUser[]>([])
const form = reactive({
  account: '',
  nickname: '',
  role: 'USER' as AdminUser['role'],
})

function roleText(role: AdminUser['role']) {
  return role === 'ADMIN' ? '管理员' : '普通用户'
}

function statusText(status: AdminUser['status']) {
  return status === 'ENABLED' ? '启用' : '禁用'
}

async function loadUsers() {
  loading.value = true
  try {
    const response = await listUsersApi()
    users.value = response.data
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingUser.value = undefined
  form.account = ''
  form.nickname = ''
  form.role = 'USER'
  dialogVisible.value = true
}

function openEdit(user: AdminUser) {
  editingUser.value = user
  form.account = user.account
  form.nickname = user.nickname
  form.role = user.role
  dialogVisible.value = true
}

async function saveUser() {
  saving.value = true
  try {
    if (editingUser.value) {
      await updateUserNicknameApi(editingUser.value.id, form.nickname)
      ElMessage.success('昵称已更新')
    } else {
      await createUserApi({
        account: form.account,
        nickname: form.nickname,
        role: form.role,
      })
      ElMessage.success('用户已创建')
    }
    dialogVisible.value = false
    await loadUsers()
  } finally {
    saving.value = false
  }
}

async function toggleStatus(user: AdminUser) {
  const nextStatus = user.status === 'ENABLED' ? 'DISABLED' : 'ENABLED'
  await updateUserStatusApi(user.id, nextStatus)
  ElMessage.success(nextStatus === 'ENABLED' ? '用户已启用' : '用户已禁用')
  await loadUsers()
}

async function resetPassword(user: AdminUser) {
  const response = await resetUserPasswordApi(user.id)
  await ElMessageBox.alert(`默认密码：${response.data.defaultPassword}`, `已重置 ${user.nickname} 的密码`, {
    confirmButtonText: '知道了',
  })
}

onMounted(loadUsers)
</script>

<style scoped>
.page-stack {
  display: grid;
  gap: 16px;
}

.toolbar {
  display: flex;
  justify-content: flex-end;
}

.full-width {
  width: 100%;
}
</style>

