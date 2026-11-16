<template>
  <!-- Einladung als Gast: nur fuer dieses eine Event, keine Gruppenmitgliedschaft -->
  <q-page class="flex flex-center q-pa-md">
    <q-card class="nx-invite">
      <div v-if="loading" class="text-center q-pa-xl"><q-spinner size="32px" color="primary" /></div>

      <EmptyState
        v-else-if="!preview"
        icon="link_off"
        title="Einladung ungültig"
        text="Dieser Einladelink funktioniert nicht (mehr). Bitte frag nach einem neuen Link."
      >
        <q-btn outline color="primary" label="Zur Startseite" to="/" />
      </EmptyState>

      <template v-else>
        <div class="nx-invite__cover" :style="{ background: sportGradient(preview.sport) }">
          <div class="nx-invite__emoji">{{ getSport(preview.sport).emoji }}</div>
        </div>
        <q-card-section>
          <div class="text-caption text-grey">
            {{ preview.organizer_name ?? 'Jemand' }} lädt dich ein · {{ preview.group_name }}
          </div>
          <div class="text-h6">{{ preview.title }}</div>
          <div class="column q-gutter-xs q-mt-sm">
            <div><q-icon name="event" size="18px" class="text-primary q-mr-sm" />{{ formatMeetup(preview.starts_at) }}</div>
            <div v-if="preview.place_name">
              <q-icon name="place" size="18px" class="text-primary q-mr-sm" />{{ preview.place_name }}
            </div>
            <div v-if="preview.fee_cents">
              <q-icon name="payments" size="18px" class="text-primary q-mr-sm" />{{ formatEuro(preview.fee_cents) }} pro Person
            </div>
            <div>
              <q-icon name="groups" size="18px" class="text-primary q-mr-sm" />
              {{ occupancyLabel(preview.max_participants, preview.going_count, 0) }}
            </div>
          </div>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <div class="nx-note nx-note--info q-mb-md">
            Du bist als Gast nur bei diesem Event dabei – du wirst kein Mitglied der Gruppe.
          </div>
          <div v-if="errorMessage" class="text-negative text-caption q-mb-sm">{{ errorMessage }}</div>
          <q-btn
            v-if="preview.my_status"
            unelevated color="primary" class="full-width" label="Zum Event" :to="`/events/${eventId}`"
          />
          <q-btn
            v-else
            unelevated
            color="primary"
            class="full-width"
            :label="isFull ? 'Auf die Warteliste' : 'Bin dabei'"
            :loading="joining"
            @click="onJoin"
          />
        </q-card-section>
      </template>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import EmptyState from '@/components/EmptyState.vue';
import { useEventsStore } from '@/stores/events-store';
import { getSport, sportGradient } from '@/data/sports';
import { friendlyError } from '@/utils/errors';
import { occupancyLabel } from '@/utils/events';
import { formatMeetup } from '@/utils/format';
import { formatEuro } from '@/utils/money';
import { notifySuccess } from '@/utils/notify';
import type { EventInvitePreview } from '@/types/event';

const route = useRoute();
const router = useRouter();
const eventsStore = useEventsStore();

const eventId = route.params.id as string;
const token = route.params.token as string;
const preview = ref<EventInvitePreview | null>(null);
const loading = ref(true);
const joining = ref(false);
const errorMessage = ref('');

const isFull = computed(
  () => preview.value?.max_participants != null && preview.value.going_count >= preview.value.max_participants,
);

onMounted(async () => {
  try {
    preview.value = await eventsStore.fetchInvitePreview(eventId, token);
  } catch {
    preview.value = null;
  } finally {
    loading.value = false;
  }
});

async function onJoin() {
  joining.value = true;
  errorMessage.value = '';
  try {
    const status = await eventsStore.joinAsGuest(eventId, token);
    notifySuccess(status === 'going' ? 'Du bist dabei!' : 'Du stehst auf der Warteliste.');
    await router.replace(`/events/${eventId}`);
  } catch (e) {
    const msg = (e as { message?: string }).message ?? '';
    errorMessage.value = msg.includes('invite_invalid')
      ? 'Dieser Einladelink funktioniert nicht mehr.'
      : msg.includes('event_over')
        ? 'Dieses Event ist schon vorbei.'
        : friendlyError(e, 'Die Zusage hat nicht geklappt. Bitte versuche es erneut.');
  } finally {
    joining.value = false;
  }
}
</script>

<style scoped>
.nx-invite {
  width: 100%;
  max-width: 420px;
  overflow: hidden;
  border-radius: 22px;
}
.nx-invite__cover {
  position: relative;
  height: 120px;
  overflow: hidden;
}
.nx-invite__emoji {
  position: absolute;
  right: 16px;
  bottom: -14px;
  font-size: 96px;
  line-height: 1;
}
</style>
