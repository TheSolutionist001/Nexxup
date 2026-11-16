<template>
  <q-page class="q-pa-md">
    <div style="max-width: 600px; margin: 0 auto">
      <div class="row items-center q-mb-sm">
        <q-btn flat dense icon="arrow_back" label="Meine Gruppen" to="/groups" no-caps />
        <q-space />
        <q-btn v-if="group" flat round dense icon="more_vert" aria-label="Optionen">
          <q-menu>
            <q-list style="min-width: 210px">
              <q-item v-if="isMember || isCreator" v-close-popup clickable @click="onShare">
                <q-item-section avatar><q-icon name="ios_share" /></q-item-section>
                <q-item-section>Einladung teilen</q-item-section>
              </q-item>
              <q-item v-if="isCreator" v-close-popup clickable @click="openEdit">
                <q-item-section avatar><q-icon name="edit" /></q-item-section>
                <q-item-section>Gruppe bearbeiten</q-item-section>
              </q-item>
              <q-item v-if="!isCreator" v-close-popup clickable @click="reportOpen = true">
                <q-item-section avatar><q-icon name="flag" /></q-item-section>
                <q-item-section>Gruppe melden</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>
      </div>

      <div v-if="loading" class="text-center q-pa-lg">
        <q-spinner size="32px" color="primary" />
      </div>

      <EmptyState
        v-else-if="loadError"
        icon="cloud_off"
        title="Gruppe konnte nicht geladen werden"
        text="Prüfe deine Internetverbindung und versuche es erneut."
      >
        <q-btn outline color="primary" icon="refresh" label="Erneut versuchen" @click="load()" />
      </EmptyState>

      <EmptyState
        v-else-if="!group"
        icon="lock"
        title="Gruppe nicht gefunden"
        text="Diese Gruppe existiert nicht (mehr) oder du hast keinen Zugriff darauf."
      />

      <template v-else>
        <q-card class="nx-detail">
          <div class="nx-detail__cover" :style="{ background: sportGradient(group.sport) }">
            <div class="nx-detail__emoji">{{ sport.emoji }}</div>
            <div class="nx-detail__tags">
              <span class="nx-tag">{{ sport.label }}</span>
              <span v-if="group.skill_level && group.skill_level !== 'alle'" class="nx-tag">{{ skillLabel(group.skill_level) }}</span>
              <span v-if="group.is_public_event" class="nx-tag">Öffentlich</span>
            </div>
          </div>
          <div class="q-pa-md">
            <div class="text-h6">{{ group.name }}</div>
            <div v-if="group.description" class="text-body2 text-grey q-mt-xs" style="white-space: pre-line">
              {{ group.description }}
            </div>

            <div class="column q-gutter-xs q-mt-md">
              <div class="row items-center no-wrap">
                <q-icon name="event" size="18px" class="text-primary q-mr-sm" />
                <span v-if="group.next_meetup_at" :class="{ 'text-grey': !isUpcoming(group.next_meetup_at) }">
                  <template v-if="!isUpcoming(group.next_meetup_at)">Vorbei: </template>{{ formatMeetup(group.next_meetup_at) }}
                  <span v-if="repeatLabel" class="text-grey"> · {{ repeatLabel }}</span>
                </span>
                <span v-else class="text-grey">Kein Termin eingetragen</span>
                <q-btn
                  v-if="isCreator"
                  flat dense no-caps color="primary" size="sm" class="q-ml-sm"
                  :label="group.next_meetup_at ? 'Ändern' : 'Termin festlegen'"
                  @click="openMeetupDialog"
                />
                <q-btn
                  v-if="(isMember || isCreator) && group.next_meetup_at && isUpcoming(group.next_meetup_at)"
                  flat dense round size="sm" icon="event_available" color="primary" class="q-ml-xs"
                  aria-label="In den Kalender"
                  @click="onCalendar"
                >
                  <q-tooltip>In meinen Kalender übernehmen</q-tooltip>
                </q-btn>
              </div>
              <div v-if="group.city" class="row items-center no-wrap">
                <q-icon name="place" size="18px" class="text-primary q-mr-sm" />{{ group.city }}
              </div>
              <div v-if="group.fee_cents" class="row items-center no-wrap">
                <q-icon name="payments" size="18px" class="text-primary q-mr-sm" />
                {{ formatEuro(group.fee_cents) }} pro Person
              </div>
              <div class="row items-center no-wrap">
                <q-icon name="groups" size="18px" class="text-primary q-mr-sm" />
                {{ activeCount }} von {{ group.max_members }} dabei
              </div>
            </div>
            <div class="nx-bar q-mt-sm">
              <span :style="{ width: `${Math.min(100, (activeCount / group.max_members) * 100)}%` }" />
            </div>

            <MeetupRsvp
              v-if="(isMember || isCreator) && group.next_meetup_at && isUpcoming(group.next_meetup_at)"
              :key="group.next_meetup_at"
              class="q-mt-md"
              :group-id="groupId"
              :meetup-at="group.next_meetup_at"
              :my-id="authStore.user?.id ?? null"
              :can-rsvp="isActiveMember"
              :is-creator="isCreator"
              :fee-cents="group.fee_cents ?? null"
            />
          </div>
        </q-card>

        <!-- Treffpunkt: nur Mitglieder/Ersteller (RLS liefert Fremden nichts) -->
        <template v-if="isMember || isCreator">
          <MeetupPlaceCard v-if="meetupPlace" :place="meetupPlace" class="q-mt-md">
            <q-btn v-if="isCreator" flat no-caps color="primary" label="Ändern" @click="openPlaceDialog" />
          </MeetupPlaceCard>
          <q-card v-else-if="isCreator" flat bordered class="q-pa-md q-mt-md">
            <div class="row items-center no-wrap">
              <q-icon name="place" size="22px" class="text-primary q-mr-sm" />
              <div class="col text-body2 text-grey">Noch kein Treffpunkt festgelegt.</div>
              <q-btn flat no-caps color="primary" label="Festlegen" @click="openPlaceDialog" />
            </div>
          </q-card>
        </template>
        <div v-else class="nx-note nx-note--info q-mt-md">
          Den genauen Treffpunkt siehst du, sobald du der Gruppe beigetreten bist.
        </div>

        <!-- Gruppen-Chat + Umfragen: nur aktive Mitglieder (RLS) -->
        <template v-if="isActiveMember">
          <div ref="chatAnchor" class="text-subtitle2 q-mt-md q-mb-xs">Gruppen-Chat</div>
          <ChatPanel :group-id="groupId" :my-id="authStore.user?.id ?? null" show-names height="380px" />
          <GroupPolls class="q-mt-md" :group-id="groupId" :my-id="authStore.user?.id ?? null" :is-group-creator="isCreator" />
        </template>
        <div v-else-if="isMember" class="nx-note nx-note--info q-mt-md">
          Du stehst auf der Warteliste. Chat und Umfragen siehst du, sobald du nachrückst.
        </div>

        <!-- Einladelink + Mitglieder nur fuer Mitglieder (RLS zeigt Fremden ohnehin keine Namen) -->
        <template v-if="isMember || isCreator">
        <q-card flat bordered class="q-pa-md q-mt-md">
          <div class="text-subtitle2 q-mb-xs">Einladelink</div>
          <div class="row items-center no-wrap">
            <div class="col ellipsis text-caption text-grey">{{ inviteLink }}</div>
            <q-btn flat dense icon="content_copy" @click="copyInvite" aria-label="Link kopieren" />
            <q-btn flat dense icon="ios_share" color="primary" @click="onShare" aria-label="Einladung teilen" />
          </div>
        </q-card>

        <!-- Mitglieder -->
        <div class="text-subtitle2 q-mt-md q-mb-xs">Aktive Mitglieder</div>
        <q-list bordered separator class="rounded-borders">
          <q-item v-for="m in activeMembers" :key="m.id" clickable @click="ui.showProfile(m.user_id)">
            <q-item-section avatar>
              <q-avatar size="32px" class="text-weight-bold" :style="avatarStyle(m.user_id)">
                {{ (m.first_name?.[0] ?? '?').toUpperCase() }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ m.first_name ?? 'Unbekannt' }}</q-item-label>
              <q-item-label caption>{{ memberCaption(m) }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge v-if="m.user_id === group.created_by" color="primary" label="Ersteller" />
              <q-btn
                v-else-if="isCreator"
                flat dense round size="sm" icon="person_remove" color="grey" aria-label="Mitglied entfernen"
                @click.stop="onRemoveMember(m)"
              />
            </q-item-section>
          </q-item>
        </q-list>

        <template v-if="waitlistMembers.length > 0">
          <div class="text-subtitle2 q-mt-md q-mb-xs">Warteliste</div>
          <q-list bordered separator class="rounded-borders">
            <q-item v-for="m in waitlistMembers" :key="m.id" clickable @click="ui.showProfile(m.user_id)">
              <q-item-section avatar>
                <q-avatar class="nx-btn-soft" size="32px">
                  {{ (m.first_name?.[0] ?? '?').toUpperCase() }}
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ m.first_name ?? 'Unbekannt' }}</q-item-label>
                <q-item-label caption>{{ memberCaption(m) }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </template>
        </template>

        <!-- Aktionen -->
        <div class="q-mt-lg">
          <template v-if="isCreator">
            <q-toggle
              :model-value="group.is_public_event"
              label="Als öffentliches Event sichtbar machen"
              @update:model-value="onTogglePublic"
            />
            <q-btn
              flat
              color="negative"
              label="Gruppe löschen"
              class="full-width q-mt-sm"
              no-caps
              @click="onDelete"
            />
          </template>
          <q-btn
            v-else-if="!isMember"
            color="primary"
            unelevated
            label="Mitmachen"
            class="full-width"
            no-caps
            :to="`/groups/join/${groupId}`"
          />
          <q-btn
            v-else
            outline
            color="negative"
            label="Gruppe verlassen"
            class="full-width"
            no-caps
            @click="onLeave"
          />
        </div>
      </template>
    </div>

    <ReportDialog v-model="reportOpen" title="Gruppe melden" @submit="onReport" />

    <!-- Gruppe bearbeiten (nur Ersteller) -->
    <q-dialog v-model="editOpen">
      <q-card style="width: 100%; max-width: 440px">
        <q-form @submit="onSaveEdit">
          <q-card-section><div class="text-h6">Gruppe bearbeiten</div></q-card-section>
          <q-card-section class="q-gutter-md q-pt-none">
            <SportPicker v-model="edit.sport" />
            <q-input v-model="edit.name" label="Name" maxlength="60" :rules="[(v: string) => !!v.trim() || 'Bitte einen Namen eingeben']" />
            <q-input v-model="edit.description" label="Beschreibung" type="textarea" autogrow maxlength="1000" />
            <q-input
              v-model.number="edit.max_members"
              label="Maximale Teilnehmerzahl"
              type="number"
              :hint="`Aktuell ${activeMembers.length} aktiv – kleiner geht nicht. Bei mehr Plätzen rücken Wartende automatisch nach.`"
              :rules="[(v: number) => (v && v >= Math.max(1, activeMembers.length)) || `Mindestens ${Math.max(1, activeMembers.length)}`]"
            />
            <q-select v-model="edit.skill_level" :options="skillLevels" emit-value map-options label="Niveau" />
            <q-input
              v-model="edit.fee"
              label="Kosten pro Person (optional)"
              suffix="€"
              inputmode="decimal"
              placeholder="z. B. 5,00"
              hint="Nur als Merkliste: Du hakst ab, wer bezahlt hat. Die App wickelt keine Zahlungen ab."
              :rules="[(v: string) => parseEuro(v) !== undefined || 'Bitte einen Betrag wie 5 oder 5,50 eingeben']"
            />
          </q-card-section>
          <q-card-actions align="right">
            <q-btn v-close-popup flat no-caps label="Abbrechen" />
            <q-btn type="submit" unelevated no-caps color="primary" label="Speichern" :loading="savingEdit" />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>

    <q-dialog v-model="meetupOpen">
      <q-card style="width: 100%; max-width: 380px">
        <q-card-section>
          <div class="text-h6">Nächster Termin</div>
        </q-card-section>
        <q-card-section>
          <q-input v-model="meetupInput" type="datetime-local" label="Datum und Uhrzeit" stack-label />
          <q-select
            v-model="repeatInput"
            class="q-mt-sm"
            :options="repeatOptions"
            emit-value
            map-options
            label="Wiederholung"
            hint="Bei Wiederholung springt der Termin danach automatisch weiter"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn v-if="group?.next_meetup_at" flat no-caps color="negative" label="Entfernen" @click="saveMeetup(null)" />
          <q-space />
          <q-btn v-close-popup flat no-caps label="Abbrechen" />
          <q-btn unelevated no-caps color="primary" label="Speichern" :disable="!meetupInput" @click="saveMeetup(meetupInput)" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="placeOpen">
      <q-card style="width: 100%; max-width: 420px">
        <q-card-section>
          <div class="text-h6">Treffpunkt</div>
          <div class="text-caption text-grey">Halle, Platz oder Adresse suchen</div>
        </q-card-section>
        <q-card-section>
          <PlaceSelect v-model="placeInput" :near="myLocation" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn v-if="meetupPlace" flat no-caps color="negative" label="Entfernen" @click="savePlace(null)" />
          <q-space />
          <q-btn v-close-popup flat no-caps label="Abbrechen" />
          <q-btn unelevated no-caps color="primary" label="Speichern" :disable="!placeInput" @click="savePlace(placeInput)" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useGroupsStore } from '@/stores/groups-store';
import { useAuthStore } from '@/stores/auth-store';
import { useRealtime } from '@/composables/useRealtime';
import EmptyState from '@/components/EmptyState.vue';
import MeetupPlaceCard from '@/components/MeetupPlaceCard.vue';
import PlaceSelect from '@/components/PlaceSelect.vue';
import ChatPanel from '@/components/ChatPanel.vue';
import GroupPolls from '@/components/GroupPolls.vue';
import MeetupRsvp from '@/components/MeetupRsvp.vue';
import ReportDialog from '@/components/ReportDialog.vue';
import SportPicker from '@/components/SportPicker.vue';
import { useModerationStore } from '@/stores/moderation-store';
import { useUiStore } from '@/stores/ui-store';
import { friendlyError } from '@/utils/errors';
import { downloadIcs } from '@/utils/ics';
import { avatarStyle } from '@/utils/avatar';
import { formatEuro, parseEuro } from '@/utils/money';
import { shareOrCopy } from '@/utils/share';
import type { ReportReason } from '@/types/report';
import { repeatOptions } from '@/data/repeat';
import type { Place } from '@/utils/geocode';
import { notifyError, notifySuccess } from '@/utils/notify';
import { getSport, skillLabel, skillLevels, sportGradient } from '@/data/sports';
import { formatMeetup, formatRepeat, isUpcoming } from '@/utils/format';
import type { Group, GroupMemberWithName } from '@/types/group';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const groupsStore = useGroupsStore();
const authStore = useAuthStore();
const moderationStore = useModerationStore();
const ui = useUiStore();

const groupId = route.params.id as string;
const group = ref<Group | null>(null);
const members = ref<GroupMemberWithName[]>([]);
const loading = ref(true);
const loadError = ref(false);

const activeMembers = computed(() => members.value.filter((m) => m.status === 'active'));
const waitlistMembers = computed(() => members.value.filter((m) => m.status === 'waitlist'));
const isCreator = computed(() => group.value?.created_by === authStore.user?.id);
const isMember = computed(() => members.value.some((m) => m.user_id === authStore.user?.id));
const isActiveMember = computed(() =>
  members.value.some((m) => m.user_id === authStore.user?.id && m.status === 'active'),
);
const repeatLabel = computed(() => formatRepeat(group.value?.meetup_repeat_weeks));
// Aus der Nachrichten-Uebersicht (?chat=1) direkt zum Gruppen-Chat springen
const chatAnchor = ref<HTMLElement | null>(null);
const sport = computed(() => getSport(group.value?.sport));
// Nicht-Mitglieder (oeffentliche Gruppe) sehen keine Namen, nur die Anzahl.
const publicCount = ref(0);
const activeCount = computed(() => (isMember.value ? activeMembers.value.length : publicCount.value));

// Termin bearbeiten (nur Ersteller; RLS erlaubt Updates nur dem Ersteller)
const meetupOpen = ref(false);
const meetupInput = ref('');
const repeatInput = ref<number | null>(null);

function toLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function openMeetupDialog() {
  meetupInput.value = group.value?.next_meetup_at ? toLocalInput(group.value.next_meetup_at) : '';
  repeatInput.value = group.value?.meetup_repeat_weeks ?? null;
  meetupOpen.value = true;
}

async function saveMeetup(value: string | null) {
  const iso = value ? new Date(value).toISOString() : null;
  try {
    await groupsStore.updateMeetup(groupId, iso, repeatInput.value);
    if (group.value) {
      group.value.next_meetup_at = iso;
      group.value.meetup_repeat_weeks = iso ? repeatInput.value : null;
    }
    meetupOpen.value = false;
    notifySuccess(iso ? 'Termin gespeichert' : 'Termin entfernt');
  } catch {
    notifyError('Der Termin konnte nicht gespeichert werden.');
  }
}
// Treffpunkt (nur fuer Mitglieder/Ersteller lesbar; aendern nur Ersteller)
const meetupPlace = ref<Place | null>(null);
const placeOpen = ref(false);
const placeInput = ref<Place | null>(null);
const myLocation = ref<{ lat: number; lng: number } | null>(null);

async function openPlaceDialog() {
  placeInput.value = meetupPlace.value;
  placeOpen.value = true;
  if (!myLocation.value) {
    try {
      myLocation.value = await authStore.fetchMyLocation();
    } catch {
      // Suche funktioniert auch ohne Gewichtung.
    }
  }
}

async function savePlace(value: Place | null) {
  try {
    await groupsStore.saveMeetupPlace(groupId, value);
    meetupPlace.value = value;
    placeOpen.value = false;
    notifySuccess(value ? 'Treffpunkt gespeichert' : 'Treffpunkt entfernt');
  } catch {
    notifyError('Der Treffpunkt konnte nicht gespeichert werden.');
  }
}

const inviteLink = computed(() => `${window.location.origin}${window.location.pathname}#/groups/join/${groupId}`);

// Eigener Status vor dem letzten Laden - dient dem Vergleich beim Nachruecken.
const myStatus = ref<string | null>(null);

// silent = true bei Live-Aktualisierungen: kein Ladebalken, damit die Seite
// beim automatischen Nachladen nicht flackert.
async function load(silent = false) {
  if (!silent) loading.value = true;
  try {
    group.value = await groupsStore.fetchGroup(groupId);
    if (group.value) {
      members.value = await groupsStore.fetchMembers(groupId);
      const memberOrCreator =
        group.value.created_by === authStore.user?.id ||
        members.value.some((m) => m.user_id === authStore.user?.id);
      if (memberOrCreator) {
        meetupPlace.value = await groupsStore.fetchMeetupPlace(groupId);
      } else {
        meetupPlace.value = null;
        publicCount.value = await groupsStore.fetchActiveCount(groupId);
      }
    }

    // Statuswechsel erkennen: waitlist -> active bedeutet, ich bin nachgerueckt.
    // Bewusst ueber den Vorher/Nachher-Vergleich der geladenen Daten, denn im
    // Live-Ereignis liefert Postgres standardmaessig nur den Primaerschluessel
    // des alten Datensatzes - der alte Status waere dort nicht enthalten.
    const previous = myStatus.value;
    const current = members.value.find((m) => m.user_id === authStore.user?.id)?.status ?? null;
    myStatus.value = current;

    if (silent && previous === 'waitlist' && current === 'active') {
      $q.notify({
        message: 'Du bist nachgerückt und jetzt aktives Mitglied!',
        color: 'positive',
        icon: 'celebration',
        timeout: 8000,
      });
    }
    loadError.value = false;
  } catch {
    // Bei stillen Live-Aktualisierungen die bisherigen Daten stehen lassen.
    if (!silent) loadError.value = true;
  } finally {
    if (!silent) loading.value = false;
  }
}

// Live-Updates: Mitglieder dieser Gruppe beobachten (Beitritt, Austritt, Nachruecken).
useRealtime('group_members', `group_id=eq.${groupId}`, () => {
  void load(true);
});

// Treffpunkt-Aenderungen des Erstellers live uebernehmen.
useRealtime('group_meetup_places', `group_id=eq.${groupId}`, () => {
  void load(true);
});

// Einladung ueber das Teilen-Menue des Handys (sonst Link kopieren)
async function onShare() {
  const result = await shareOrCopy({
    title: group.value?.name ?? 'Nexxup',
    text: `Mach mit bei „${group.value?.name ?? 'meiner Gruppe'}“ auf Nexxup:`,
    url: inviteLink.value,
  });
  if (result === 'copied') notifySuccess('Einladelink kopiert');
  else if (result === 'failed') notifyError('Teilen nicht möglich. Bitte den Link von Hand kopieren.');
}

// Termin als Kalender-Datei (funktioniert mit Apple-, Google- und Outlook-Kalender)
function onCalendar() {
  if (!group.value?.next_meetup_at) return;
  downloadIcs(
    {
      uid: `${groupId}-${group.value.next_meetup_at}`,
      title: `${sport.value.label}: ${group.value.name}`,
      start: new Date(group.value.next_meetup_at),
      location: meetupPlace.value ? [meetupPlace.value.name, meetupPlace.value.address].filter(Boolean).join(', ') : group.value.city,
      description: `Nexxup-Gruppe „${group.value.name}“ – ${inviteLink.value}`,
      repeatWeeks: group.value.meetup_repeat_weeks ?? null,
    },
    'nexxup-termin.ics',
  );
}

// Gruppe melden (fuer Nicht-Ersteller)
const reportOpen = ref(false);
async function onReport(reason: ReportReason) {
  try {
    await moderationStore.report('group', groupId, reason);
    notifySuccess('Danke, die Meldung ist eingegangen.');
  } catch {
    notifyError('Melden fehlgeschlagen. Evtl. schon gemeldet?');
  } finally {
    reportOpen.value = false;
  }
}

// Gruppe bearbeiten (nur Ersteller)
const editOpen = ref(false);
const savingEdit = ref(false);
const edit = reactive({ name: '', description: '', max_members: 10, skill_level: 'alle', sport: 'sonstiges', fee: '' });
function openEdit() {
  if (!group.value) return;
  edit.name = group.value.name;
  edit.description = group.value.description ?? '';
  edit.max_members = group.value.max_members;
  edit.skill_level = group.value.skill_level ?? 'alle';
  edit.sport = group.value.sport;
  edit.fee = group.value.fee_cents ? (group.value.fee_cents / 100).toFixed(2).replace('.', ',') : '';
  editOpen.value = true;
}
async function onSaveEdit() {
  savingEdit.value = true;
  try {
    await groupsStore.updateGroup(groupId, {
      name: edit.name.trim(),
      description: edit.description.trim() || null,
      max_members: edit.max_members,
      skill_level: edit.skill_level,
      sport: edit.sport,
      fee_cents: parseEuro(edit.fee) ?? null,
    });
    editOpen.value = false;
    notifySuccess('Gruppe gespeichert');
    await load(true);
  } catch (e) {
    notifyError(friendlyError(e, 'Die Gruppe konnte nicht gespeichert werden.'));
  } finally {
    savingEdit.value = false;
  }
}

// Zweite Zeile in der Mitgliederliste: Nutzername (eindeutig) und Stadt
function memberCaption(m: GroupMemberWithName): string {
  return [m.username ? `@${m.username}` : null, m.city].filter(Boolean).join(' · ');
}

function onRemoveMember(m: GroupMemberWithName) {
  $q.dialog({
    title: 'Mitglied entfernen',
    message: `${m.first_name ?? 'Diese Person'} aus der Gruppe entfernen? Wer auf der Warteliste steht, rückt automatisch nach.`,
    cancel: true,
    ok: { label: 'Entfernen', color: 'negative', flat: true },
  }).onOk(async () => {
    try {
      await groupsStore.removeMember(groupId, m.user_id);
      await load(true);
    } catch {
      notifyError('Das Mitglied konnte nicht entfernt werden.');
    }
  });
}

async function copyInvite() {
  try {
    await navigator.clipboard.writeText(inviteLink.value);
    notifySuccess('Einladelink kopiert');
  } catch {
    notifyError('Kopieren nicht möglich. Bitte den Link von Hand markieren und kopieren.');
  }
}

async function onTogglePublic(value: boolean) {
  try {
    await groupsStore.togglePublic(groupId, value);
    if (group.value) group.value.is_public_event = value;
  } catch {
    notifyError('Die Einstellung konnte nicht gespeichert werden.');
  }
}

function onLeave() {
  $q.dialog({
    title: 'Gruppe verlassen',
    message: 'Möchtest du diese Gruppe wirklich verlassen?',
    cancel: true,
  }).onOk(async () => {
    try {
      await groupsStore.leaveGroup(groupId);
      await router.push('/groups');
    } catch {
      notifyError('Austritt fehlgeschlagen. Bitte versuche es erneut.');
    }
  });
}

function onDelete() {
  $q.dialog({
    title: 'Gruppe löschen',
    message: 'Die Gruppe wird endgültig gelöscht. Fortfahren?',
    cancel: true,
  }).onOk(async () => {
    try {
      await groupsStore.deleteGroup(groupId);
      await router.push('/groups');
    } catch {
      notifyError('Die Gruppe konnte nicht gelöscht werden.');
    }
  });
}

onMounted(async () => {
  await load();
  if (route.query.chat && isActiveMember.value) {
    await nextTick();
    chatAnchor.value?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
});

// Termin-Aenderungen (z. B. automatisches Weiterschieben) live uebernehmen
useRealtime('groups', `id=eq.${groupId}`, () => {
  void load(true);
});
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
  gap: 6px;
}
</style>
