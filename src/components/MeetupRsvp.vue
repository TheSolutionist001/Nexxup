<template>
  <!-- Zusagen fuer den naechsten Termin (gilt nur fuer dieses Datum).
       Kostet der Termin etwas, haengt hier auch die "Bezahlt"-Merkliste. -->
  <div class="nx-rsvp">
    <div v-if="canRsvp" class="row q-gutter-sm">
      <q-btn
        no-caps
        unelevated
        rounded
        icon="check"
        label="Bin dabei"
        :color="myStatus === 'yes' ? 'primary' : undefined"
        :class="{ 'nx-btn-soft': myStatus !== 'yes' }"
        :loading="saving === 'yes'"
        @click="toggle('yes')"
      />
      <q-btn
        no-caps
        unelevated
        rounded
        icon="close"
        label="Diesmal nicht"
        :class="myStatus === 'no' ? 'nx-btn-no' : 'nx-btn-soft'"
        :loading="saving === 'no'"
        @click="toggle('no')"
      />
    </div>
    <div class="text-caption text-grey q-mt-sm">
      <template v-if="yes.length > 0">
        <q-icon name="check_circle" size="14px" class="text-primary" />
        {{ yes.length }} dabei: {{ yes.map((r) => r.first_name ?? 'Unbekannt').join(', ') }}
      </template>
      <template v-else>Noch keine Zusagen.</template>
      <template v-if="no.length > 0"> · {{ no.length }} abgesagt</template>
    </div>

    <!-- Kosten: Mitglied sieht nur den eigenen Status -->
    <div v-if="feeCents && !isCreator && myStatus === 'yes'" class="nx-pay-own q-mt-sm">
      <q-icon :name="iPaid ? 'check_circle' : 'schedule'" size="16px" :color="iPaid ? 'positive' : undefined" />
      <span>
        Kosten {{ formatEuro(feeCents) }} ·
        <b>{{ iPaid ? 'als bezahlt vermerkt' : 'noch offen' }}</b>
      </span>
    </div>

    <!-- Kosten: Gruppenleiter hakt ab, wer bezahlt hat -->
    <div v-if="feeCents && isCreator" class="nx-pay q-mt-md">
      <div class="row items-center">
        <div class="text-subtitle2 col">Bezahlt ({{ formatEuro(feeCents) }} pro Person)</div>
        <div class="text-caption text-grey">{{ paidCount }} von {{ payers.length }} · {{ formatEuro(paidCount * feeCents) }}</div>
      </div>
      <div v-if="payers.length === 0" class="text-caption text-grey q-mt-xs">
        Sobald jemand „Bin dabei“ wählt, erscheint die Person hier zum Abhaken.
      </div>
      <q-list v-else dense class="q-mt-xs">
        <q-item v-for="p in payers" :key="p.user_id" v-ripple clickable class="q-px-none" @click="togglePaid(p.user_id)">
          <q-item-section side>
            <q-checkbox :model-value="paid.includes(p.user_id)" dense color="primary" @update:model-value="togglePaid(p.user_id)" @click.stop />
          </q-item-section>
          <q-item-section>{{ p.first_name ?? 'Unbekannt' }}</q-item-section>
          <q-item-section side class="text-caption">
            {{ paid.includes(p.user_id) ? 'bezahlt' : 'offen' }}
          </q-item-section>
        </q-item>
      </q-list>
      <div class="text-caption text-grey q-mt-xs">
        Nur du siehst diese Liste. Jedes Mitglied sieht lediglich den eigenen Status.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useGroupsStore } from '@/stores/groups-store';
import { useRealtime } from '@/composables/useRealtime';
import { formatEuro } from '@/utils/money';
import { notifyError } from '@/utils/notify';
import type { MeetupRsvp, RsvpStatus } from '@/types/group';

const props = withDefaults(
  defineProps<{
    groupId: string;
    meetupAt: string;
    myId: string | null;
    canRsvp: boolean;
    isCreator?: boolean;
    feeCents?: number | null;
  }>(),
  { isCreator: false, feeCents: null },
);

const groupsStore = useGroupsStore();
const rsvps = ref<MeetupRsvp[]>([]);
const saving = ref<RsvpStatus | null>(null);
// Wer als bezahlt vermerkt ist (Gruppenleiter: alle; Mitglied: hoechstens man selbst - RLS)
const paid = ref<string[]>([]);

const yes = computed(() => rsvps.value.filter((r) => r.status === 'yes'));
const no = computed(() => rsvps.value.filter((r) => r.status === 'no'));
const myStatus = computed(() => rsvps.value.find((r) => r.user_id === props.myId)?.status ?? null);
const iPaid = computed(() => !!props.myId && paid.value.includes(props.myId));
// Abzuhaken sind alle, die zugesagt haben
const payers = computed(() => yes.value);
const paidCount = computed(() => payers.value.filter((p) => paid.value.includes(p.user_id)).length);

async function load() {
  try {
    rsvps.value = await groupsStore.fetchRsvps(props.groupId, props.meetupAt);
    if (props.feeCents) paid.value = await groupsStore.fetchPaidUserIds(props.groupId, props.meetupAt);
  } catch {
    // Anzeige bleibt leer; Zusagen sind nicht kritisch
  }
}

async function toggle(status: RsvpStatus) {
  saving.value = status;
  try {
    // Nochmal tippen nimmt die Antwort zurueck
    await groupsStore.setRsvp(props.groupId, myStatus.value === status ? null : status);
    await load();
  } catch {
    notifyError('Deine Antwort konnte nicht gespeichert werden.');
  } finally {
    saving.value = null;
  }
}

async function togglePaid(userId: string) {
  const nowPaid = !paid.value.includes(userId);
  // Sofort anzeigen, bei Fehler zuruecknehmen
  paid.value = nowPaid ? [...paid.value, userId] : paid.value.filter((id) => id !== userId);
  try {
    await groupsStore.setPayment(props.groupId, userId, nowPaid);
  } catch {
    notifyError('Der Zahlungsstatus konnte nicht gespeichert werden.');
    await load();
  }
}

useRealtime('meetup_rsvps', `group_id=eq.${props.groupId}`, () => void load());
useRealtime('meetup_payments', `group_id=eq.${props.groupId}`, () => void load());
watch(() => [props.meetupAt, props.feeCents], load);
onMounted(load);
</script>

<style scoped>
.nx-btn-no {
  background: var(--nx-text) !important;
  color: var(--nx-bg) !important;
}
.nx-pay {
  border-top: 1px solid var(--nx-border);
  padding-top: 12px;
}
.nx-pay-own {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--nx-muted);
}
</style>
