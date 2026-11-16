<template>
  <q-page class="flex flex-center q-pa-md">
    <q-card class="q-pa-md" style="width: 100%; max-width: 480px">
      <q-card-section>
        <div class="text-h6">Gruppe gründen</div>
        <div class="text-caption text-grey">
          Eine Gruppe ist deine Gemeinschaft – z. B. ein Freundeskreis oder ein Verein. Darin plant ihr
          anschließend beliebig viele Events (Fußball, Laufen, Padel …).
        </div>
      </q-card-section>

      <q-card-section>
        <q-form class="q-gutter-md" @submit="onSubmit">
          <q-input
            v-model="name"
            label="Name der Gruppe"
            maxlength="60"
            placeholder="z. B. Gruppo Bietigheim"
            :rules="[(val: string) => !!val.trim() || 'Bitte einen Namen eingeben']"
          />
          <q-input v-model="description" label="Beschreibung (optional)" type="textarea" autogrow maxlength="1000" />

          <CitySelect v-model="city" label="Stadt (optional)" @select="onCity" />

          <q-toggle v-model="isPublic" label="Öffentlich – Leute in der Nähe können die Gruppe finden und beitreten" />
          <div v-if="isPublic && !selectedCity" class="nx-note nx-note--info">
            Wähle eine Stadt, damit die Gruppe bei Leuten in der Nähe auftaucht.
          </div>
          <div class="text-caption text-grey">
            Mitglieder lädst du per Link ein – es gibt keine Obergrenze. Events sehen immer nur Mitglieder.
          </div>

          <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>

          <div class="row q-gutter-sm">
            <q-btn label="Abbrechen" flat to="/groups" />
            <q-space />
            <q-btn type="submit" label="Gründen" color="primary" unelevated :loading="loading" />
          </div>
        </q-form>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import CitySelect from '@/components/CitySelect.vue';
import { useGroupsStore } from '@/stores/groups-store';
import { useAuthStore } from '@/stores/auth-store';
import { friendlyError } from '@/utils/errors';
import type { City } from '@/utils/geocode';

const router = useRouter();
const groupsStore = useGroupsStore();
const authStore = useAuthStore();

const name = ref('');
const description = ref('');
const city = ref<string | null>(null);
const selectedCity = ref<City | null>(null);
const myLocation = ref<{ lat: number; lng: number } | null>(null);
const isPublic = ref(false);
const loading = ref(false);
const errorMessage = ref('');

// Stadt aus dem Profil vorbelegen (Name + gespeicherte Stadt-Koordinaten).
onMounted(async () => {
  city.value = authStore.profile?.city ?? null;
  try {
    myLocation.value = await authStore.fetchMyLocation();
    const profileCity = authStore.profile?.city;
    if (myLocation.value && profileCity && !selectedCity.value) {
      city.value = profileCity;
      selectedCity.value = { name: profileCity, ...myLocation.value };
    }
  } catch {
    // Ohne Vorbelegung weiter - die Stadt kann man auch selbst waehlen.
  }
});

function onCity(c: City | null) {
  selectedCity.value = c;
}

async function onSubmit() {
  loading.value = true;
  errorMessage.value = '';
  try {
    // Stadt steht (aus dem Profil) im Feld, die Koordinaten sind aber noch
    // nicht geladen (sehr schnelles Absenden) -> jetzt nachholen.
    if (!selectedCity.value && city.value && city.value === authStore.profile?.city) {
      const loc = myLocation.value ?? (await authStore.fetchMyLocation().catch(() => null));
      if (loc) selectedCity.value = { name: city.value, ...loc };
    }
    const id = await groupsStore.createGroup({
      name: name.value.trim(),
      description: description.value.trim(),
      city: selectedCity.value?.name ?? null,
      lat: selectedCity.value?.lat ?? null,
      lng: selectedCity.value?.lng ?? null,
    });
    if (isPublic.value) await groupsStore.updateGroup(id, { is_public_event: true });
    await router.push(`/groups/${id}`);
  } catch (e) {
    errorMessage.value = friendlyError(e, 'Die Gruppe konnte nicht erstellt werden. Bitte versuche es erneut.');
  } finally {
    loading.value = false;
  }
}
</script>
