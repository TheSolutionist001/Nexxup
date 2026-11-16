<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 600px; margin: 0 auto">
      <div class="row items-center q-mt-md q-mb-sm">
        <q-btn flat dense icon="arrow_back" :label="backLabel" no-caps @click="goBack" />
        <q-space />
        <q-btn v-if="event && canManage" flat round dense icon="more_vert" aria-label="Optionen">
          <q-menu>
            <q-list style="min-width: 200px">
              <q-item v-close-popup clickable :to="`/events/${eventId}/edit`">
                <q-item-section avatar><q-icon name="edit" /></q-item-section>
                <q-item-section>Bearbeiten</q-item-section>
              </q-item>
              <q-item v-close-popup clickable @click="onDelete">
                <q-item-section avatar><q-icon name="delete" color="negative" /></q-item-section>
                <q-item-section class="text-negative">Event löschen</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>

      <div v-if="loading" class="text-center q-pa-lg"><q-spinner size="32px" color="primary" /></div>

      <EmptyState
        v-else-if="loadError"
        icon="cloud_off"
        title="Event konnte nicht geladen werden"
        text="Prüfe deine Internetverbindung und versuche es erneut."
      >
        <q-btn outline color="primary" icon="refresh" label="Erneut versuchen" @click="load()" />
      </EmptyState>

      <EmptyState
        v-else-if="!event"
        icon="lock"
        title="Event nicht gefunden"
        text="Dieses Event existiert nicht (mehr) oder du hast keinen Zugriff darauf."
      />

      <template v-else>
        <q-card class="nx-detail">
          <div class="nx-detail__cover" :style="{ background: sportGradient(event.sport) }">
            <div class="nx-detail__emoji">{{ sport.emoji }}</div>
            <div class="nx-detail__tags">
              <span class="nx-tag">{{ sport.label }}</span>
              <span v-if="event.skill_level !== 'alle'" class="nx-tag">{{ skillLabel(event.skill_level) }}</span>
              <span v-if="event.audience === 'interested'" class="nx-tag">Nur Interessierte</span>
            </div>
          </div>
          <div class="q-pa-md">
            <div class="text-h6">{{ event.title }}</div>
            <div v-if="groupName" class="text-caption text-grey">
              in
              <router-link v-if="!iAmGuest" :to="`/groups/${event.group_id}`">{{ groupName }}</router-link>
              <template v-else>{{ groupName }}</template>
              <template v-if="iAmGuest"> · du bist als Gast dabei</template>
            </div>
            <div v-if="event.description" class="text-body2 q-mt-sm" style="white-space: pre-line">
              {{ event.description }}
            </div>

            <div class="column q-gutter-xs q-mt-md">
              <div class="row items-center no-wrap">
                <q-icon name="event" size="18px" class="text-primary q-mr-sm" />
                <span :class="{ 'text-grey': !open }">
                  <template v-if="!open">Vorbei: </template>{{ formatMeetup(event.starts_at) }} · {{ durationLabel }}
                  <span v-if="event.repeat_weeks" class="text-grey"> · {{ formatRepeat(event.repeat_weeks) }}</span>
                </span>
                <q-btn
                  v-if="open"
                  flat dense round size="sm" icon="event_available" color="primary" class="q-ml-xs"
                  aria-label="In den Kalender"
                  @click="onCalendar"
                >
                  <q-tooltip>In meinen Kalender übernehmen</q-tooltip>
                </q-btn>
              </div>
              <div v-if="event.fee_cents" class="row items-center no-wrap">
                <q-icon name="payments" size="18px" class="text-primary q-mr-sm" />
                {{ formatEuro(event.fee_cents) }} pro Person
              </div>
              <div class="row items-center no-wrap">
                <q-icon name="groups" size="18px" class="text-primary q-mr-sm" />
                {{ occupancyLabel(event.max_participants, taken, waitlist.length) }}
                <span v-if="left !== null && left > 0" class="text-grey q-ml-xs">· noch {{ left }} frei</span>
              </div>
            </div>
            <div v-if="event.max_participants" class="nx-bar q-mt-sm">
              <span :style="{ width: `${Math.min(100, (taken / event.max_participants) * 100)}%` }" />
            </div>

            <!-- Mein Status + Aktion -->
            <template v-if="open">
              <div v-if="myStatus === 'offered'" class="nx-note nx-note--info q-mt-md">
                <div class="text-weight-bold">Ein Platz ist frei geworden – für dich reserviert!</div>
                <div>Sag innerhalb von {{ minutesLeft }} Min. zu, sonst geht er an die nächste Person.</div>
                <div class="row q-gutter-sm q-mt-sm">
                  <q-btn unelevated color="primary" icon="check" label="Zusagen" :loading="busy" @click="onJoin" />
                  <q-btn flat label="Ablehnen" :disable="busy" @click="onLeave" />
                </div>
              </div>

              <div v-else class="q-mt-md">
                <q-btn
                  v-if="myStatus === null"
                  unelevated
                  rounded
                  color="primary"
                  :icon="isFull ? 'hourglass_empty' : 'check'"
                  :label="isFull ? 'Auf die Warteliste' : 'Bin dabei'"
                  :loading="busy"
                  @click="onJoin"
                />
                <div v-else class="row items-center q-gutter-sm">
                  <q-chip
                    :color="myStatus === 'going' ? 'positive' : 'warning'"
                    text-color="dark"
                    :icon="myStatus === 'going' ? 'check_circle' : 'hourglass_empty'"
                    class="text-weight-bold"
                  >
                    {{ myStatus === 'going' ? 'Du bist dabei' : `Warteliste · Platz ${myWaitPosition}` }}
                  </q-chip>
                  <q-btn
                    flat
                    dense
                    color="negative"
                    :label="myStatus === 'going' ? 'Absagen' : 'Warteliste verlassen'"
                    :loading="busy"
                    @click="onLeave"
                  />
                </div>
                <div v-if="myStatus === 'waitlist'" class="text-caption text-grey q-mt-xs">
                  Wird ein Platz frei, bekommst du eine Benachrichtigung und hast 1 Stunde Zeit zuzusagen.
                </div>
                <div v-if="myStatus === 'going' && event.fee_cents && !canManage" class="text-caption text-grey q-mt-xs">
                  <q-icon :name="iPaid ? 'check_circle' : 'schedule'" size="14px" :color="iPaid ? 'positive' : undefined" />
                  Kosten {{ formatEuro(event.fee_cents) }} ·
                  <b>{{ iPaid ? 'als bezahlt vermerkt' : 'noch offen' }}</b>
                </div>
              </div>
            </template>
          </div>
        </q-card>

        <!-- Treffpunkt -->
        <MeetupPlaceCard v-if="placeForCard" :place="placeForCard" class="q-mt-md" />

        <!-- Teilnehmer -->
        <div class="text-subtitle2 q-mt-md q-mb-xs">
          Dabei ({{ going.length }}<template v-if="event.max_participants">/{{ event.max_participants }}</template>)
        </div>
        <div v-if="going.length === 0" class="text-caption text-grey">Noch niemand – sei die erste Zusage!</div>
        <q-list v-else class="nx-group">
          <q-item v-for="p in going" :key="p.user_id" clickable @click="ui.showProfile(p.user_id)">
            <q-item-section avatar>
              <q-avatar size="32px" class="text-weight-bold" :style="avatarStyle(p.user_id)">
                {{ (p.first_name?.[0] ?? '?').toUpperCase() }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label>
                {{ p.first_name ?? 'Unbekannt' }}
                <q-badge v-if="p.user_id === event.created_by" color="primary" label="Organisator" class="q-ml-xs" />
                <q-badge v-if="p.is_guest" outline color="grey" label="Gast" class="q-ml-xs" />
              </q-item-label>
              <q-item-label v-if="p.username" caption>@{{ p.username }}</q-item-label>
            </q-item-section>
            <q-item-section v-if="canManage" side>
              <div class="row items-center no-wrap">
                <q-checkbox
                  v-if="event.fee_cents"
                  :model-value="paid.includes(p.user_id)"
                  dense
                  color="primary"
                  label="bezahlt"
                  @update:model-value="togglePaid(p.user_id)"
                  @click.stop
                />
                <q-btn
                  v-if="p.user_id !== authStore.user?.id"
                  flat dense round size="sm" icon="person_remove" color="grey" class="q-ml-xs"
                  aria-label="Aus dem Event entfernen"
                  @click.stop="onRemove(p)"
                />
              </div>
            </q-item-section>
          </q-item>
        </q-list>
        <div v-if="canManage && event.fee_cents && going.length > 0" class="text-caption text-grey q-mt-xs">
          {{ paidCount }} von {{ going.length }} bezahlt · {{ formatEuro(paidCount * event.fee_cents) }} · Die
          Bezahlt-Liste siehst nur du; alle anderen sehen nur ihren eigenen Status.
        </div>

        <template v-if="waitlist.length > 0">
          <div class="text-subtitle2 q-mt-md q-mb-xs">Warteliste ({{ waitlist.length }})</div>
          <q-list class="nx-group">
            <q-item v-for="(p, i) in waitlist" :key="p.user_id" clickable @click="ui.showProfile(p.user_id)">
              <q-item-section avatar>
                <q-avatar size="32px" class="nx-btn-soft text-weight-bold">{{ i + 1 }}</q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ p.first_name ?? 'Unbekannt' }}</q-item-label>
                <q-item-label caption>
                  <template v-if="p.status === 'offered'">
                    Platz angeboten · noch {{ offerMinutesLeft(p.offer_expires_at, now) }} Min.
                  </template>
                  <template v-else-if="p.username">@{{ p.username }}</template>
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </template>

        <!-- Gaeste einladen (nur Organisator) -->
        <q-card v-if="canManage && open" flat bordered class="q-pa-md q-mt-md">
          <div class="row items-center no-wrap">
            <div class="col">
              <div class="text-subtitle2">Gäste einladen</div>
              <div class="text-caption text-grey">
                Noch Plätze frei? Lade per Link Leute ein, die nicht in der Gruppe sind. Sie sind nur bei diesem
                Event dabei und werden keine Gruppenmitglieder.
              </div>
            </div>
            <q-toggle :model-value="inviteOn" color="primary" :disable="inviteBusy" @update:model-value="onToggleInvite" />
          </div>
          <div v-if="inviteOn" class="row q-gutter-sm q-mt-sm">
            <q-btn unelevated color="primary" icon="ios_share" label="Einladung teilen" :loading="inviteBusy" @click="onShareInvite" />
          </div>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import EmptyState from '@/components/EmptyState.vue';
import MeetupPlaceCard from '@/components/MeetupPlaceCard.vue';
import { supabase } from '@/boot/supabase';
import { useAuthStore } from '@/stores/auth-store';
import { useEventsStore } from '@/stores/events-store';
import { useUiStore } from '@/stores/ui-store';
import { useRealtime } from '@/composables/useRealtime';
import { getSport, skillLabel, sportGradient } from '@/data/sports';
import { avatarStyle } from '@/utils/avatar';
import { friendlyError } from '@/utils/errors';
import { findConflicts, isEventOpen, occupancyLabel, offerMinutesLeft, spotsLeft } from '@/utils/events';
import { formatMeetup, formatRepeat } from '@/utils/format';
import { downloadIcs } from '@/utils/ics';
import { formatEuro } from '@/utils/money';
import { notifyError, notifySuccess } from '@/utils/notify';
import { appUrl, shareOrCopy } from '@/utils/share';
import type { Place } from '@/utils/geocode';
import type { EventParticipant, EventRow } from '@/types/event';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();
const eventsStore = useEventsStore();
const ui = useUiStore();

const eventId = route.params.id as string;
const event = ref<EventRow | null>(null);
const groupName = ref<string | null>(null);
const participants = ref<EventParticipant[]>([]);
const paid = ref<string[]>([]);
const canManage = ref(false);
const inviteOn = ref(false);
const inviteBusy = ref(false);
const loading = ref(true);
const loadError = ref(false);
const busy = ref(false);

// Uhr fuer die Restzeit von Angeboten (jede halbe Minute neu berechnen)
const now = ref(new Date());
const timer = setInterval(() => (now.value = new Date()), 30_000);
onBeforeUnmount(() => clearInterval(timer));

const myId = computed(() => authStore.user?.id ?? null);
const sport = computed(() => getSport(event.value?.sport));
const going = computed(() => participants.value.filter((p) => p.status === 'going'));
// Warteliste in Reihenfolge; wer gerade ein Angebot hat, steht vorn
const waitlist = computed(() =>
  participants.value
    .filter((p) => p.status !== 'going')
    .sort((a, b) => Number(b.status === 'offered') - Number(a.status === 'offered')),
);
// Belegte Plaetze: Zusagen + reservierte Angebote
const taken = computed(() => participants.value.filter((p) => p.status !== 'waitlist').length);
const left = computed(() => spotsLeft(event.value?.max_participants ?? null, taken.value));
const isFull = computed(() => left.value === 0);
const me = computed(() => participants.value.find((p) => p.user_id === myId.value) ?? null);
const myStatus = computed(() => me.value?.status ?? null);
const iAmGuest = computed(() => me.value?.is_guest ?? false);
const myWaitPosition = computed(() => waitlist.value.findIndex((p) => p.user_id === myId.value) + 1);
const minutesLeft = computed(() => offerMinutesLeft(me.value?.offer_expires_at ?? null, now.value));
const open = computed(() => (event.value ? isEventOpen(event.value, now.value) : false));
const iPaid = computed(() => !!myId.value && paid.value.includes(myId.value));
const paidCount = computed(() => going.value.filter((p) => paid.value.includes(p.user_id)).length);

const durationLabel = computed(() => {
  const m = event.value?.duration_minutes ?? 0;
  if (m < 60) return `${m} Min.`;
  const h = m / 60;
  return `${String(h).replace('.', ',')} Std.`;
});

const placeForCard = computed<Place | null>(() => {
  const e = event.value;
  if (!e?.place_name || e.place_lat === null || e.place_lng === null) return null;
  return { name: e.place_name, address: e.place_address ?? '', lat: e.place_lat, lng: e.place_lng };
});

const backLabel = computed(() => (iAmGuest.value || !groupName.value ? 'Zurück' : groupName.value));
function goBack() {
  if (event.value && !iAmGuest.value) void router.push(`/groups/${event.value.group_id}`);
  else void router.push('/');
}

async function load(silent = false) {
  if (!silent) loading.value = true;
  try {
    event.value = await eventsStore.fetchEvent(eventId);
    if (event.value) {
      const [people, name, manage, paidIds] = await Promise.all([
        eventsStore.fetchParticipants(eventId),
        eventsStore.fetchGroupName(eventId),
        supabase.rpc('can_manage_event', { p_event_id: eventId }),
        event.value.fee_cents ? eventsStore.fetchPaidUserIds(eventId) : Promise.resolve([]),
      ]);
      participants.value = people;
      groupName.value = name;
      canManage.value = Boolean(manage.data);
      paid.value = paidIds;
      if (canManage.value) inviteOn.value = await eventsStore.hasInvite(eventId);
    }
    loadError.value = false;
  } catch {
    if (!silent) loadError.value = true;
  } finally {
    if (!silent) loading.value = false;
  }
}

// Zusagen - vorher auf Terminueberschneidungen pruefen
async function onJoin() {
  if (!event.value) return;
  const target = event.value;
  try {
    const mine = await eventsStore.fetchMyEvents();
    const conflicts = findConflicts(target, mine);
    if (conflicts.length > 0) {
      // Reiner Text (kein HTML): Titel stammen von Nutzern
      const list = conflicts.map((c) => `• ${c.title} (${formatMeetup(c.starts_at)})`).join('\n');
      const ok = await new Promise<boolean>((resolve) => {
        $q.dialog({
          title: 'Terminüberschneidung',
          message: `Zur gleichen Zeit hast du schon zugesagt:\n\n${list}\n\nTrotzdem zusagen?`,
          class: 'nx-dialog-pre',
          cancel: { label: 'Abbrechen', flat: true },
          ok: { label: 'Trotzdem zusagen', color: 'primary', unelevated: true },
        })
          .onOk(() => resolve(true))
          .onCancel(() => resolve(false))
          .onDismiss(() => resolve(false));
      });
      if (!ok) return;
    }
  } catch {
    // Pruefung nicht moeglich -> Zusage trotzdem erlauben
  }
  busy.value = true;
  try {
    const status = await eventsStore.joinEvent(eventId);
    notifySuccess(status === 'going' ? 'Du bist dabei!' : 'Du stehst auf der Warteliste.');
    await load(true);
  } catch (e) {
    const msg = (e as { message?: string }).message ?? '';
    notifyError(msg.includes('event_over') ? 'Dieses Event ist schon vorbei.' : friendlyError(e, 'Die Zusage hat nicht geklappt.'));
  } finally {
    busy.value = false;
  }
}

function onLeave() {
  const wasGoing = myStatus.value === 'going';
  const run = async () => {
    busy.value = true;
    try {
      await eventsStore.leaveEvent(eventId);
      await load(true);
      // Gaeste verlieren mit der Absage den Zugriff auf das Event
      if (!event.value) await router.push('/');
    } catch {
      notifyError('Das hat nicht geklappt. Bitte versuche es erneut.');
    } finally {
      busy.value = false;
    }
  };
  if (!wasGoing) {
    void run();
    return;
  }
  $q.dialog({
    title: 'Absagen?',
    message: 'Dein Platz wird frei und der nächsten Person auf der Warteliste angeboten.',
    cancel: { label: 'Doch nicht', flat: true },
    ok: { label: 'Absagen', color: 'negative', flat: true },
  }).onOk(() => void run());
}

function onRemove(p: EventParticipant) {
  $q.dialog({
    title: 'Aus dem Event entfernen',
    message: `${p.first_name ?? 'Diese Person'} aus dem Event entfernen? Der Platz wird der Warteliste angeboten.`,
    cancel: true,
    ok: { label: 'Entfernen', color: 'negative', flat: true },
  }).onOk(async () => {
    try {
      await eventsStore.removeParticipant(eventId, p.user_id);
      await load(true);
    } catch {
      notifyError('Das hat nicht geklappt.');
    }
  });
}

async function togglePaid(userId: string) {
  const nowPaid = !paid.value.includes(userId);
  paid.value = nowPaid ? [...paid.value, userId] : paid.value.filter((id) => id !== userId);
  try {
    await eventsStore.setPaid(eventId, userId, nowPaid);
  } catch {
    notifyError('Der Zahlungsstatus konnte nicht gespeichert werden.');
    await load(true);
  }
}

async function onToggleInvite(value: boolean) {
  inviteBusy.value = true;
  try {
    await eventsStore.setInvite(eventId, value);
    inviteOn.value = value;
    if (!value) notifySuccess('Einladelink abgeschaltet – er funktioniert nicht mehr.');
  } catch {
    notifyError('Das hat nicht geklappt.');
  } finally {
    inviteBusy.value = false;
  }
}

async function onShareInvite() {
  if (!event.value) return;
  inviteBusy.value = true;
  try {
    // Das Kennwort des Links bekommt nur der Organisator
    const token = await eventsStore.setInvite(eventId, true);
    if (!token) throw new Error('kein Link');
    const result = await shareOrCopy({
      title: event.value.title,
      text: `Lust auf „${event.value.title}“ am ${formatMeetup(event.value.starts_at)}? Sag hier zu:`,
      url: `${appUrl()}#/events/invite/${eventId}/${token}`,
    });
    if (result === 'copied') notifySuccess('Einladelink kopiert');
    else if (result === 'failed') notifyError('Teilen nicht möglich.');
  } catch {
    notifyError('Der Einladelink konnte nicht erstellt werden.');
  } finally {
    inviteBusy.value = false;
  }
}

function onCalendar() {
  const e = event.value;
  if (!e) return;
  downloadIcs(
    {
      uid: e.id,
      title: `${sport.value.label}: ${e.title}`,
      start: new Date(e.starts_at),
      durationMinutes: e.duration_minutes,
      location: [e.place_name, e.place_address].filter(Boolean).join(', ') || null,
      description: `Nexxup-Event – ${appUrl()}#/events/${e.id}`,
      repeatWeeks: e.repeat_weeks,
    },
    'nexxup-event.ics',
  );
}

function onDelete() {
  $q.dialog({
    title: 'Event löschen',
    message: 'Das Event wird samt Zusagen und Warteliste für alle endgültig gelöscht. Fortfahren?',
    cancel: true,
    ok: { label: 'Löschen', color: 'negative', flat: true },
  }).onOk(async () => {
    const groupId = event.value?.group_id;
    try {
      await eventsStore.deleteEvent(eventId);
      await router.replace(groupId ? `/groups/${groupId}` : '/');
    } catch {
      notifyError('Das Event konnte nicht gelöscht werden.');
    }
  });
}

// Live: Zusagen, Absagen, Angebote, Aenderungen am Event
useRealtime('event_participants', `event_id=eq.${eventId}`, () => void load(true));
useRealtime('group_events', `id=eq.${eventId}`, () => void load(true));

onMounted(() => load());
</script>

<style scoped>
.nx-detail {
  overflow: hidden;
  border-radius: 22px;
}
.nx-detail__cover {
  position: relative;
  height: 150px;
  overflow: hidden;
}
.nx-detail__emoji {
  position: absolute;
  right: 18px;
  bottom: -16px;
  font-size: 110px;
  line-height: 1;
  filter: drop-shadow(0 6px 16px rgba(0, 0, 0, 0.35));
}
.nx-detail__tags {
  position: absolute;
  left: 14px;
  top: 14px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
</style>
