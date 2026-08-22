<template>
  <main class="login-page">
    <section class="login-panel">
      <div class="login-copy">
        <h1>远程会议管理后台</h1>
        <p>管理在线会议、录制文件、用户账号和系统运行状态。</p>
      </div>

      <el-form class="login-form" :model="form" label-position="top" @submit.prevent="submit">
        <el-form-item label="登录账号">
          <el-input v-model="form.account" size="large" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input
            v-model="form.password"
            size="large"
            type="password"
            autocomplete="current-password"
            show-password
          />
        </el-form-item>
        <el-button :loading="loading" type="primary" size="large" native-type="submit" class="submit">
          登录
        </el-button>
      </el-form>
    </section>
  </main>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const auth = useAuthStore()
const loading = ref(false)
const form = reactive({
  account: 'admin',
  password: '',
})

async function submit() {
  loading.value = true
  try {
    await auth.login(form)
    router.push({ name: 'dashboard' })
  } catch {
    ElMessage.error('登录失败，请检查账号和密码')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background:
    linear-gradient(135deg, rgba(21, 94, 117, 0.12), transparent 40%),
    #f6f7fb;
}

.login-panel {
  width: min(920px, 100%);
  display: grid;
  grid-template-columns: 1fr 380px;
  gap: 32px;
  align-items: center;
  padding: 40px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #ffffff;
  box-shadow: 0 18px 50px rgba(15, 23, 42, 0.08);
}

.login-copy h1 {
  margin: 0 0 12px;
  color: #111827;
  font-size: 34px;
  line-height: 1.2;
  font-weight: 750;
}

.login-copy p {
  max-width: 420px;
  margin: 0;
  color: #6b7280;
  font-size: 16px;
  line-height: 1.7;
}

.login-form {
  padding: 24px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fbfcff;
}

.submit {
  width: 100%;
}

@media (max-width: 760px) {
  .login-panel {
    grid-template-columns: 1fr;
    padding: 24px;
  }

  .login-copy h1 {
    font-size: 28px;
  }
}
</style>
