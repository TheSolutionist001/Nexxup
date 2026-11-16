<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 520px; margin: 0 auto">
      <q-btn flat dense icon="arrow_back" label="Zurück" class="q-mt-md" @click="router.back()" />
      <div class="nx-display q-mt-sm q-mb-md" style="font-size: 22px">
        {{ isEdit ? 'Event bearbeiten' : 'Event planen' }}
      </div>

      <div v-if="loading" class="text-center q-pa-lg"><q-spinner size="32px" color="primary" /></div>

      <EmptyState
        v-else-if="notAllowed"
        icon="lock"
        title="Hier kannst du kein Event anlegen"
        text="In dieser Gruppe dürfen nur ausgewählte Mitglieder Events organisieren."
      />

      <q-form v-else class="q-gutter-md" @submit="onSubmit">
        <div>
          <div class="text-caption text-grey q-mb-xs">Sportart</div>
          <SportPicker v-model="form.sport" />
        </div>

        <q-input
          v-model="form.title"
          label="Titel"
          maxlength="80"
          placeholder="z. B. Fußball am Freitag"
          :rules="[(v: string) => !!v.trim() || 'Bitte einen Titel eingeben']"
        />
        <q-input v-model="form.description" label="Beschreibung (optional)" type="textarea" autogrow maxlength="1000" />

        <q-input
          v-model="form.startsAt"
          label="Beginn"
          type="datetime-local"
          stack-label
          :rules="[
            (v: string) => !!v || 'Bitte Datum und Uhrzeit wählen',
            (v: string) => isEdit || new Date(v) > new Date() || 'Der Termin liegt in der Vergangenheit',
          ]"
        />
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <q-select v-model="form.duration" :options="durationOptions" emit-value map-options label="Dauer" />
          </div>
          <div class="col-6">
            <q-select v-model="form.repeatWeeks" :options="repeatOptions" emit-value map-options label="Wiederholung" />
          </div>
        </div>

        <q-input
          v-model="form.max"
          label="Plätze (leer = unbegrenzt)"
          type="number"
          inputmode="numeric"
          hint="Ist das Event voll, gibt es eine Warteliste. Sagt jemand ab, bekommt die nächste Person den Platz für 1 Stunde angeboten."
          :rules="[(v: string) => v === '' || v === null || (Number(v) >= 1 && Number(v) <= 1000) || 'Zwischen 1 und 1000']"
        />

        <q-select v-model="form.skill" :options="skillLevels" emit-value map-options label="Niveau" />

        <PlaceSelect v-model="place" label="Treffpunkt (optional)" :near="myLocation" />

        <q-input
          v-model="form.fee"
          label="Kosten pro Person (optional)"
          suffix="€"
          inputmode="decimal"
          placeholder="z. B. 5,00"
          hint="Nur als Merkliste: Du hakst ab, wer bezahlt hat. Die App wickelt keine Zahlungen ab."
          :rules="[(v: string) => parseEuro(v) !== undefined || 'Bitte einen Betrag wie 5 oder 5,50 eingeben']"
        />

        <div>
          <div class="text-caption text-grey q-mb-xs">Wer soll das Event sehen?</div>
          <q-btn-toggle
            v-model="form.audience"
            class="nx-toggle"
            spread
            unelevated
            no-caps
            toggle-color="primary"
            toggle-text-color="dark"
            :options="[
              { label: 'Alle Mitglieder', value: 'all' },
              { label: 'Nur Interessierte', value: 'interested' },
            ]"
          />
          <div class="text-caption text-grey q-mt-xs">
            <template v-if="form.audience === 'all'">Alle in der Gruppe sehen das Event und werden benachrichtigt.</template>
            <template v-else>
              Nur Mitglieder, die „{{ getSport(form.sport).label }}“ in ihren Sportarten im Profil haben.
            </template>
          </div>
        </div>

        <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>

        <div class="row q-gutter-sm">
          <q-btn flat label="Abbrechen" @click="router.back()" />
          <q-space />
          <q-btn type="submit" unelevated color="primary" :label="isEdit ? 'Speichern' : 'Event anlegen'" :loading="saving" />
        </div>
      </q-form>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import EmptyState from '@/components/EmptyState.vue';
import PlaceSelect from '@/components/PlaceSelect.vue';
import SportPicker from '@/components/SportPicker.vue';
import { supabase } from '@/boot/supabase';
import { useAuthStore } from '@/stores/auth-store';
import { useEventsStore } from '@/stores/events-store';
import { repeatOptions } from '@/data/repeat';
import { getSport, skillLevels } from '@/data/sports';
import { friendlyError } from '@/utils/errors';
import { toLocalInput } from '@/utils/events';
import { parseEuro } from '@/utils/money';
import { notifySuccess } from '@/utils/notify';
import type { Place } from '@/utils/geocode';
import type { EventAudience, EventInput } from '@/types/event';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const eventsStore = useEventsStore();

// Zwei Wege hierher: /groups/:groupId/events/new  oder  /events/:id/edit
const eventId = (route.params.id as string | undefined) ?? null;
const isEdit = eventId !== null;
const groupId = ref((route.params.groupId as string | undefined) ?? '');

const loading = ref(true);
const saving = ref(false);
const notAllowed = ref(false);
const errorMessage = ref('');
const place = ref<Place | null>(null);
const myLocation = ref<{ lat: number; lng: number } | null>(null);

const form = reactive({
  sport: 'sonstiges',
  title: '',
  description: '',
  startsAt: '',
  duration: 90,
  repeatWeeks: null as number | null,
  max: '' as string | number | null,
  skill: 'alle',
  fee: '',
  audience: 'all' as EventAudience,
});

const durationOptions = [
  { label: '1 Stunde', value: 60 },
  { label: '1,5 Stunden', value: 90 },
  { label: '2 Stunden', value: 120 },
  { label: '3 Stunden', value: 180 },
  { label: 'Halber Tag', value: 300 },
  { label: 'Ganzer Tag', value: 600 },
];

onMounted(async () => {
  try {
    if (isEdit) {
      const e = await eventsStore.fetchEvent(eventId);
      if (!e) {
        notAllowed.value = true;
        return;
      }
      groupId.value = e.group_id;
      form.sport = e.sport;
      form.title = e.title;
      form.description = e.description ?? '';
      form.startsAt = toLocalInput(e.starts_at);
      form.duration = e.duration_minutes;
      form.repeatWeeks = e.repeat_weeks;
      form.max = e.max_participants ?? '';
      form.skill = e.skill_level;
      form.fee = e.fee_cents ? (e.fee_cents / 100).toFixed(2).replace('.', ',') : '';
      form.audience = e.audience;
      if (e.place_name && e.place_lat !== null && e.place_lng !== null) {
        place.value = { name: e.place_name, address: e.place_address ?? '', lat: e.place_lat, lng: e.place_lng };
      }
    } else {
      const { data } = await supabase.rpc('can_organize_events', { p_group_id: groupId.value });
      notAllowed.value = !data;
    }
    myLocation.value = await authStore.fetchMyLocation().catch(() => null);
  } finally {
    loading.value = false;
  }
});

async function onSubmit() {
  if (!authStore.user) return;
  saving.value = true;
  errorMessage.value = '';
  const input: EventInput = {
    title: form.title.trim(),
    description: form.description.trim() || null,
    sport: form.sport,
    skill_level: form.skill,
    // datetime-local liefert Ortszeit ohne Zone -> als lokale Zeit interpretieren
    starts_at: new Date(form.startsAt).toISOString(),
    duration_minutes: form.duration,
    max_participants: form.max === '' || form.max === null ? null : Number(form.max),
    fee_cents: parseEuro(form.fee) ?? null,
    audience: form.audience,
    place_name: place.value?.name.slice(0, 200) ?? null,
    place_address: place.value?.address?.slice(0, 300) ?? null,
    place_lat: place.value?.lat ?? null,
    place_lng: place.value?.lng ?? null,
    repeat_weeks: form.repeatWeeks,
  };
  try {
    if (isEdit) {
      await eventsStore.updateEvent(eventId, input);
      notifySuccess('Event gespeichert');
      await router.replace(`/events/${eventId}`);
    } else {
      const id = await eventsStore.createEvent(groupId.value, authStore.user.id, input);
      notifySuccess('Event angelegt');
      await router.replace(`/events/${id}`);
    }
  } catch (e) {
    errorMessage.value = friendlyError(e, 'Das Event konnte nicht gespeichert werden. Bitte versuche es erneut.');
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.nx-toggle {
  border-radius: 14px;
  overflow: hidden;
  background: var(--nx-surface);
  border: 1px solid var(--nx-border);
}
</style>
