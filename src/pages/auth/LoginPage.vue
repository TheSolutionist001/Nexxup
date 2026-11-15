<template>
  <div class="flex flex-center column q-pa-md" style="min-height: 100vh">
    <NexxupLogo :size="132" wordmark tagline class="q-mb-xl" />
    <q-card class="q-pa-lg" style="width: 100%; max-width: 360px">
      <q-card-section>
        <div class="text-h6">Willkommen zurück</div>
        <div class="text-caption text-grey">Melde dich mit deiner E-Mail an.</div>
      </q-card-section>

      <q-card-section v-if="authStore.bannedNotice">
        <div class="nx-note nx-note--negative">Dein Konto wurde gesperrt.</div>
      </q-card-section>

      <q-card-section>
        <q-form class="q-gutter-md" @submit="onSubmit">
          <q-input
            v-model="email"
            type="email"
            label="E-Mail"
            autocomplete="email"
            :rules="[(val: string) => !!val || 'Bitte E-Mail eingeben']"
          />
          <q-input
            v-model="password"
            type="password"
            label="Passwort"
            autocomplete="current-password"
            :rules="[(val: string) => !!val || 'Bitte Passwort eingeben']"
          />
          <div class="text-right" style="margin-top: 0">
            <a href="#" class="text-caption" @click.prevent="onForgot">Passwort vergessen?</a>
          </div>

          <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>

          <q-btn
            type="submit"
            label="Einloggen"
            color="primary"
            class="full-width"
            unelevated
            :loading="loading"
          />
        </q-form>
      </q-card-section>

      <q-card-section class="text-center text-caption">
        Noch kein Konto?
        <router-link :to="{ path: '/register', query: route.query }" class="text-primary">Registrieren</router-link>
      </q-card-section>
    </q-card>
    <LegalLinks class="q-mt-lg" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import LegalLinks from '@/components/LegalLinks.vue';
import { notifyError, notifySuccess } from '@/utils/notify';
import NexxupLogo from '@/components/NexxupLogo.vue';
import { useAuthStore } from '@/stores/auth-store';
import { getAuthErrorMessage } from '@/utils/auth-errors';

const router = useRouter();
const route = useRoute();
const $q = useQuasar();
const authStore = useAuthStore();

const email = ref('');
const password = ref('');
const loading = ref(false);
const errorMessage = ref('');

async function onSubmit() {
  loading.value = true;
  errorMessage.value = '';
  try {
    await authStore.signIn(email.value, password.value);
    // Zurueck zum eigentlichen Ziel (z. B. Einladelink), sonst zur Startseite
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/';
    await router.push(redirect.startsWith('/') ? redirect : '/');
  } catch (error) {
    errorMessage.value = getAuthErrorMessage(error);
  } finally {
    loading.value = false;
  }
}

// "Passwort vergessen": schickt einen Link per E-Mail. Aus Sicherheitsgruenden
// verraet die Meldung nicht, ob es zu der Adresse ein Konto gibt.
function onForgot() {
  $q.dialog({
    title: 'Passwort vergessen',
    message: 'Gib deine E-Mail-Adresse ein. Wir schicken dir einen Link, mit dem du ein neues Passwort setzen kannst.',
    prompt: { model: email.value, type: 'email', isValid: (v: string) => /.+@.+\..+/.test(v) },
    cancel: true,
    ok: { label: 'Link senden', color: 'primary', unelevated: true },
  }).onOk(async (address: string) => {
    try {
      await authStore.sendPasswordReset(address.trim());
      notifySuccess('Falls es ein Konto zu dieser Adresse gibt, ist die E-Mail unterwegs.');
    } catch (error) {
      notifyError(getAuthErrorMessage(error));
    }
  });
}
</script>
