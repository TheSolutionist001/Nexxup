<template>
  <div class="flex flex-center column q-pa-md" style="min-height: 100vh">
    <NexxupLogo :size="96" wordmark class="q-mb-xl" />
    <q-card class="q-pa-lg" style="width: 100%; max-width: 360px">
      <q-card-section>
        <div class="text-h6">Neues Passwort</div>
        <div class="text-caption text-grey">Wähle ein neues Passwort für dein Konto.</div>
      </q-card-section>
      <q-card-section>
        <q-form class="q-gutter-md" @submit="onSubmit">
          <q-input
            v-model="password"
            :type="show ? 'text' : 'password'"
            label="Neues Passwort"
            autocomplete="new-password"
            :rules="[(val: string) => (!!val && val.length >= 8) || 'Mindestens 8 Zeichen']"
          >
            <template #append>
              <q-icon :name="show ? 'visibility_off' : 'visibility'" class="cursor-pointer" @click="show = !show" />
            </template>
          </q-input>
          <q-input
            v-model="password2"
            :type="show ? 'text' : 'password'"
            label="Neues Passwort wiederholen"
            autocomplete="new-password"
            lazy-rules
            :rules="[(val: string) => val === password || 'Die Passwörter stimmen nicht überein']"
          />
          <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>
          <q-btn type="submit" label="Passwort speichern" color="primary" class="full-width" unelevated :loading="loading" />
          <q-btn flat label="Abbrechen" class="full-width" to="/" />
        </q-form>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import NexxupLogo from '@/components/NexxupLogo.vue';
import { useAuthStore } from '@/stores/auth-store';
import { getAuthErrorMessage } from '@/utils/auth-errors';
import { notifySuccess } from '@/utils/notify';

const router = useRouter();
const authStore = useAuthStore();
const password = ref('');
const password2 = ref('');
const show = ref(false);
const loading = ref(false);
const errorMessage = ref('');

async function onSubmit() {
  loading.value = true;
  errorMessage.value = '';
  try {
    await authStore.updatePassword(password.value);
    notifySuccess('Passwort geändert');
    await router.push('/');
  } catch (error) {
    errorMessage.value = getAuthErrorMessage(error);
  } finally {
    loading.value = false;
  }
}
</script>
