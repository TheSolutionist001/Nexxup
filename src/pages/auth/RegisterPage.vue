<template>
  <div class="flex flex-center column q-pa-md" style="min-height: 100vh">
    <NexxupLogo :size="96" wordmark class="q-mb-xl" />
    <q-card v-if="!registered" class="q-pa-lg" style="width: 100%; max-width: 360px">
      <q-card-section>
        <div class="text-h6">Konto erstellen</div>
        <div class="text-caption text-grey">Andere sehen nur deinen Vornamen und deine Stadt.</div>
      </q-card-section>

      <q-card-section>
        <q-form class="q-gutter-md" @submit="onSubmit">
          <q-input
            v-model="firstName"
            label="Vorname"
            maxlength="40"
            autocomplete="given-name"
            :rules="[(val: string) => !!val.trim() || 'Bitte Vorname eingeben']"
          />
          <q-input
            v-model="email"
            type="email"
            label="E-Mail"
            :rules="[(val: string) => !!val || 'Bitte E-Mail eingeben']"
          />
          <q-input
            v-model="password"
            type="password"
            label="Passwort"
            autocomplete="new-password"
            :rules="[(val: string) => (!!val && val.length >= 8) || 'Mindestens 8 Zeichen']"
          />
          <q-input
            v-model="password2"
            type="password"
            label="Passwort wiederholen"
            autocomplete="new-password"
            lazy-rules
            :rules="[(val: string) => val === password || 'Die Passwörter stimmen nicht überein']"
          />
          <q-select
            v-model="gender"
            :options="genderOptions"
            label="Geschlecht"
            emit-value
            map-options
          />
          <CitySelect v-model="city" @select="onCity" />
          <div v-if="cityError" class="text-negative text-caption">{{ cityError }}</div>

          <q-checkbox v-model="accepted" dense class="text-caption" style="align-items: flex-start">
            <span>
              Ich bin mindestens {{ MIN_AGE }} Jahre alt und akzeptiere die
              <!-- In neuem Tab oeffnen, damit die Eingaben im Formular nicht verloren gehen -->
              <a href="#/legal/regeln" target="_blank" rel="noopener" @click.stop>Community-Regeln</a> und die
              <a href="#/legal/datenschutz" target="_blank" rel="noopener" @click.stop>Datenschutzerklärung</a>.
            </span>
          </q-checkbox>

          <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>

          <q-btn
            type="submit"
            label="Registrieren"
            color="primary"
            class="full-width"
            unelevated
            :loading="loading"
            :disable="!accepted"
          />
        </q-form>
      </q-card-section>

      <q-card-section class="text-center text-caption">
        Schon ein Konto?
        <router-link :to="{ path: '/login', query: route.query }" class="text-primary">Einloggen</router-link>
      </q-card-section>
    </q-card>

    <q-card v-else class="q-pa-lg text-center" style="width: 100%; max-width: 360px">
      <q-card-section>
        <div class="text-h6">Fast geschafft</div>
        <p class="text-body2 q-mt-md">
          Wir haben eine E-Mail an <strong>{{ email }}</strong> geschickt. Bitte bestätige
          dein Konto über den Link darin, bevor du dich einloggst.
        </p>
      </q-card-section>
      <q-card-section>
        <router-link to="/login" class="text-primary">Zum Login</router-link>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { MIN_AGE } from '@/data/legal';
import CitySelect from '@/components/CitySelect.vue';
import NexxupLogo from '@/components/NexxupLogo.vue';
import { useAuthStore } from '@/stores/auth-store';
import { genderOptions, type Gender } from '@/types/profile';
import type { City } from '@/utils/geocode';
import { getAuthErrorMessage } from '@/utils/auth-errors';

const router = useRouter();
const route = useRoute();
const accepted = ref(false);
const authStore = useAuthStore();

const firstName = ref('');
const email = ref('');
const password = ref('');
const password2 = ref('');
const gender = ref<Gender>('keine_angabe');
const city = ref<string | null>(null);
const selectedCity = ref<City | null>(null);
const loading = ref(false);
const errorMessage = ref('');
const cityError = ref('');
const registered = ref(false);

function onCity(c: City | null) {
  selectedCity.value = c;
  cityError.value = '';
}

async function onSubmit() {
  cityError.value = '';
  if (!selectedCity.value) {
    cityError.value = 'Bitte eine Stadt auswählen.';
    return;
  }
  loading.value = true;
  errorMessage.value = '';
  try {
    const { needsEmailConfirmation } = await authStore.signUp({
      email: email.value,
      password: password.value,
      firstName: firstName.value.trim(),
      gender: gender.value,
      city: selectedCity.value.name,
      lat: selectedCity.value.lat,
      lng: selectedCity.value.lng,
    });
    if (needsEmailConfirmation) {
      // E-Mail-Bestaetigung ist aktiv: Hinweis anzeigen, kein Auto-Login.
      registered.value = true;
    } else {
      // Bestaetigung aus: Nutzer ist sofort eingeloggt -> Standort setzen, weiter.
      await authStore.setLocation(selectedCity.value.lat, selectedCity.value.lng);
      const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/';
      await router.push(redirect.startsWith('/') ? redirect : '/');
    }
  } catch (error) {
    errorMessage.value = getAuthErrorMessage(error);
  } finally {
    loading.value = false;
  }
}
</script>
