<template>
  <q-page class="q-pa-md">
    <div style="max-width: 600px; margin: 0 auto">
      <div class="row items-center q-mb-sm">
        <q-btn flat dense icon="arrow_back" label="Meine Gruppen" to="/groups" no-caps />
        <q-space />
        <q-btn v-if="group" flat round dense icon="more_vert" aria-label="Optionen">
          <q-menu>
            <q-list style="min-width: 210px">
              <q-item v-if="isMember" v-close-popup clickable @click="onShare">
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
        <!-- Kopf: die Gruppe ist eine neutrale Gemeinschaft -->
        <q-card class="nx-ghead">
          <div class="row items-center no-wrap q-pa-md" style="gap: 14px">
            <div class="nx-ghead__icon" :style="avatarStyle(group.id)">{{ group.name[0]?.toUpperCase() }}</div>
            <div class="col" style="min-width: 0">
              <div class="nx-display" style="font-size: 19px; line-height: 1.2">{{ group.name }}</div>
              <div class="text-caption text-grey q-mt-xs">
                <q-icon name="groups" size="14px" /> {{ memberCount }} {{ memberCount === 1 ? 'Mitglied' : 'Mitglieder' }}
                <template v-if="group.city"> · <q-icon name="place" size="14px" /> {{ group.city }}</template>
                <template v-if="group.is_public_event"> · öffentlich</template>
              </div>
            </div>
          </div>
          <div v-if="group.description" class="q-px-md q-pb-md" style="white-space: pre-line">
            {{ group.description }}
          </div>
        </q-card>

        <!-- Noch kein Mitglied (oeffentliche Gruppe) -->
        <template v-if="!isMember">
          <div class="nx-note nx-note--info q-mt-md">
            Tritt bei, um die Events der Gruppe zu sehen, zuzusagen und mitzuschreiben.
          </div>
          <q-btn color="primary" unelevated label="Mitmachen" class="full-width q-mt-md" :to="`/groups/join/${groupId}`" />
        </template>

        <template v-else>
          <!-- Events -->
          <div class="row items-center q-mt-lg q-mb-xs">
            <div class="nx-section__title col">Events</div>
            <q-btn
              v-if="canOrganize"
              unelevated
              color="primary"
              dense
              padding="6px 12px"
              icon="add"
              label="Event planen"
              :to="`/groups/${groupId}/events/new`"
            />
          </div>

          <q-btn-toggle
            :model-value="myFilter"
            class="nx-toggle q-mb-sm"
            spread
            unelevated
            no-caps
            dense
            toggle-color="primary"
            toggle-text-color="dark"
            :options="[
              { label: 'Alle Events', value: 'all' },
              { label: 'Nur meine Interessen', value: 'interests' },
            ]"
            @update:model-value="onFilter"
          />
          <div v-if="myFilter === 'interests' && mySportsCount === 0" class="nx-note nx-note--warning q-mb-sm">
            Du hast noch keine Sportarten im <router-link to="/profile">Profil</router-link> gewählt – so siehst du
            gerade keine Events.
          </div>

          <div v-if="events.length > 0" class="column q-gutter-sm">
            <EventCard v-for="e in events" :key="e.id" :event="e" />
          </div>
          <q-card v-else class="q-pa-md text-center">
            <div class="text-body2 text-grey">
              {{
                myFilter === 'interests'
                  ? 'Gerade kein Event zu deinen Interessen.'
                  : 'Noch kein Event geplant.'
              }}
            </div>
            <q-btn
              v-if="canOrganize"
              flat
              color="primary"
              icon="add"
              label="Erstes Event planen"
              class="q-mt-xs"
              :to="`/groups/${groupId}/events/new`"
            />
            <div v-else class="text-caption text-grey q-mt-xs">
              In dieser Gruppe planen ausgewählte Mitglieder die Events.
            </div>
          </q-card>

          <!-- Gruppen-Chat + Umfragen -->
          <div ref="chatAnchor" class="nx-section__title q-mt-lg q-mb-xs">Gruppen-Chat</div>
          <ChatPanel :group-id="groupId" :my-id="authStore.user?.id ?? null" show-names height="360px" />
          <GroupPolls class="q-mt-md" :group-id="groupId" :my-id="authStore.user?.id ?? null" :is-group-creator="isCreator" />

          <!-- Einladelink -->
          <q-card flat bordered class="q-pa-md q-mt-md">
            <div class="text-subtitle2 q-mb-xs">Einladelink zur Gruppe</div>
            <div class="row items-center no-wrap">
              <div class="col ellipsis text-caption text-grey">{{ inviteLink }}</div>
              <q-btn flat dense icon="content_copy" aria-label="Link kopieren" @click="copyInvite" />
              <q-btn flat dense icon="ios_share" color="primary" aria-label="Einladung teilen" @click="onShare" />
            </div>
          </q-card>

          <!-- Mitglieder -->
          <div class="text-subtitle2 q-mt-md q-mb-xs">Mitglieder ({{ members.length }})</div>
          <q-list class="nx-group">
            <q-item v-for="m in members" :key="m.id" clickable @click="ui.showProfile(m.user_id)">
              <q-item-section avatar>
                <q-avatar size="32px" class="text-weight-bold" :style="avatarStyle(m.user_id)">
                  {{ (m.first_name?.[0] ?? '?').toUpperCase() }}
                </q-avatar>
              </q-item-section>
              <q-item-section>
                <q-item-label>
                  {{ m.first_name ?? 'Unbekannt' }}
                  <q-badge v-if="m.user_id === group.created_by" color="primary" label="Ersteller" class="q-ml-xs" />
                  <q-badge
                    v-else-if="group.event_creation === 'selected' && m.can_organize"
                    outline
                    color="primary"
                    label="Organisator"
                    class="q-ml-xs"
                  />
                </q-item-label>
                <q-item-label caption>{{ memberCaption(m) }}</q-item-label>
              </q-item-section>
              <q-item-section v-if="isCreator && m.user_id !== group.created_by" side>
                <q-btn flat dense round size="sm" icon="more_vert" aria-label="Mitglied verwalten" @click.stop>
                  <q-menu>
                    <q-list style="min-width: 230px">
                      <q-item
                        v-if="group.event_creation === 'selected'"
                        v-close-popup
                        clickable
                        @click="onToggleOrganizer(m)"
                      >
                        <q-item-section avatar><q-icon :name="m.can_organize ? 'event_busy' : 'event_available'" /></q-item-section>
                        <q-item-section>
                          {{ m.can_organize ? 'Darf keine Events mehr planen' : 'Darf Events planen' }}
                        </q-item-section>
                      </q-item>
                      <q-item v-close-popup clickable @click="onRemoveMember(m)">
                        <q-item-section avatar><q-icon name="person_remove" color="negative" /></q-item-section>
                        <q-item-section class="text-negative">Aus der Gruppe entfernen</q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-btn>
              </q-item-section>
            </q-item>
          </q-list>

          <!-- Einstellungen des Erstellers -->
          <template v-if="isCreator">
            <div class="text-subtitle2 q-mt-lg q-mb-xs">Einstellungen</div>
            <q-list class="nx-group">
              <q-item>
                <q-item-section>
                  <q-item-label>Wer darf Events planen?</q-item-label>
                  <q-item-label caption>
                    {{
                      group.event_creation === 'all'
                        ? 'Alle Mitglieder können Events anlegen.'
                        : 'Nur du und Mitglieder, die du in der Liste oben freischaltest.'
                    }}
                  </q-item-label>
                  <q-btn-toggle
                    :model-value="group.event_creation"
                    class="nx-toggle q-mt-sm"
                    spread
                    unelevated
                    no-caps
                    dense
                    toggle-color="primary"
                    toggle-text-color="dark"
                    :options="[
                      { label: 'Alle Mitglieder', value: 'all' },
                      { label: 'Nur Ausgewählte', value: 'selected' },
                    ]"
                    @update:model-value="onEventCreation"
                  />
                </q-item-section>
              </q-item>
              <q-item>
                <q-item-section>
                  <q-item-label>Öffentlich auffindbar</q-item-label>
                  <q-item-label caption>
                    Leute in der Nähe finden die Gruppe unter „Entdecken“ und können beitreten. Events sehen nur
                    Mitglieder.
                  </q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-toggle :model-value="group.is_public_event" color="primary" @update:model-value="onTogglePublic" />
                </q-item-section>
              </q-item>
            </q-list>
            <q-btn flat color="negative" label="Gruppe löschen" class="full-width q-mt-md" @click="onDelete" />
          </template>
          <q-btn v-else outline color="negative" label="Gruppe verlassen" class="full-width q-mt-lg" @click="onLeave" />
        </template>
      </template>
    </div>

    <ReportDialog v-model="reportOpen" title="Gruppe melden" @submit="onReport" />

    <!-- Gruppe bearbeiten (nur Ersteller) -->
    <q-dialog v-model="editOpen">
      <q-card style="width: 100%; max-width: 440px">
        <q-form @submit="onSaveEdit">
          <q-card-section><div class="text-h6">Gruppe bearbeiten</div></q-card-section>
          <q-card-section class="q-gutter-md q-pt-none">
            <q-input v-model="edit.name" label="Name" maxlength="60" :rules="[(v: string) => !!v.trim() || 'Bitte einen Namen eingeben']" />
            <q-input v-model="edit.description" label="Beschreibung" type="textarea" autogrow maxlength="1000" />
          </q-card-section>
          <q-card-actions align="right">
            <q-btn v-close-popup flat label="Abbrechen" />
            <q-btn type="submit" unelevated color="primary" label="Speichern" :loading="savingEdit" />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import ChatPanel from '@/components/ChatPanel.vue';
import EmptyState from '@/components/EmptyState.vue';
import EventCard from '@/components/EventCard.vue';
import GroupPolls from '@/components/GroupPolls.vue';
import ReportDialog from '@/components/ReportDialog.vue';
import { useAuthStore } from '@/stores/auth-store';
import { useEventsStore } from '@/stores/events-store';
import { useGroupsStore } from '@/stores/groups-store';
import { useModerationStore } from '@/stores/moderation-store';
import { useUiStore } from '@/stores/ui-store';
import { useRealtime } from '@/composables/useRealtime';
import { avatarStyle } from '@/utils/avatar';
import { friendlyError } from '@/utils/errors';
import { notifyError, notifySuccess } from '@/utils/notify';
import { shareOrCopy } from '@/utils/share';
import type { GroupEvent } from '@/types/event';
import type { Group, GroupMemberWithName } from '@/types/group';
import type { ReportReason } from '@/types/report';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const groupsStore = useGroupsStore();
const eventsStore = useEventsStore();
const authStore = useAuthStore();
const moderationStore = useModerationStore();
const ui = useUiStore();

const groupId = route.params.id as string;
const group = ref<Group | null>(null);
const members = ref<GroupMemberWithName[]>([]);
const events = ref<GroupEvent[]>([]);
const loading = ref(true);
const loadError = ref(false);
// Nicht-Mitglieder (oeffentliche Gruppe) sehen keine Namen, nur die Anzahl.
const publicCount = ref(0);

const me = computed(() => members.value.find((m) => m.user_id === authStore.user?.id) ?? null);
const isMember = computed(() => me.value !== null);
const isCreator = computed(() => group.value?.created_by === authStore.user?.id);
const memberCount = computed(() => (isMember.value ? members.value.length : publicCount.value));
const myFilter = computed(() => me.value?.event_filter ?? 'all');
const mySportsCount = computed(() => authStore.profile?.sports?.length ?? 0);
// Darf ich hier Events anlegen? (Die Datenbank prueft das beim Speichern noch einmal.)
const canOrganize = computed(
  () => isCreator.value || (isMember.value && (group.value?.event_creation === 'all' || me.value?.can_organize === true)),
);

// Aus der Nachrichten-Uebersicht (?chat=1) direkt zum Gruppen-Chat springen
const chatAnchor = ref<HTMLElement | null>(null);

const inviteLink = computed(() => `${window.location.origin}${window.location.pathname}#/groups/join/${groupId}`);

// silent = true bei Live-Aktualisierungen: kein Ladebalken, damit die Seite nicht flackert.
async function load(silent = false) {
  if (!silent) loading.value = true;
  try {
    group.value = await groupsStore.fetchGroup(groupId);
    if (group.value) {
      members.value = await groupsStore.fetchMembers(groupId);
      const member = members.value.some((m) => m.user_id === authStore.user?.id);
      if (member) {
        events.value = await eventsStore.fetchMyEvents(groupId);
      } else {
        events.value = [];
        publicCount.value = await groupsStore.fetchActiveCount(groupId);
      }
    }
    loadError.value = false;
  } catch {
    // Bei stillen Live-Aktualisierungen die bisherigen Daten stehen lassen.
    if (!silent) loadError.value = true;
  } finally {
    if (!silent) loading.value = false;
  }
}

// Live: Mitglieder, Gruppen-Einstellungen, Events und Zusagen dieser Gruppe
useRealtime('group_members', `group_id=eq.${groupId}`, () => void load(true));
useRealtime('groups', `id=eq.${groupId}`, () => void load(true));
useRealtime('group_events', `group_id=eq.${groupId}`, () => void load(true));
useRealtime('event_participants', null, () => void load(true));

function memberCaption(m: GroupMemberWithName): string {
  return [m.username ? `@${m.username}` : null, m.city].filter(Boolean).join(' · ');
}

async function onFilter(value: 'all' | 'interests') {
  try {
    await groupsStore.setMyEventFilter(groupId, value);
    await load(true);
  } catch {
    notifyError('Die Einstellung konnte nicht gespeichert werden.');
  }
}

async function onEventCreation(value: 'all' | 'selected') {
  try {
    await groupsStore.updateGroup(groupId, { event_creation: value });
    if (group.value) group.value.event_creation = value;
  } catch {
    notifyError('Die Einstellung konnte nicht gespeichert werden.');
  }
}

async function onToggleOrganizer(m: GroupMemberWithName) {
  try {
    await groupsStore.setMemberOrganizer(groupId, m.user_id, !m.can_organize);
    await load(true);
  } catch {
    notifyError('Das hat nicht geklappt.');
  }
}

async function onTogglePublic(value: boolean) {
  try {
    await groupsStore.updateGroup(groupId, { is_public_event: value });
    if (group.value) group.value.is_public_event = value;
  } catch {
    notifyError('Die Einstellung konnte nicht gespeichert werden.');
  }
}

// Einladung ueber das Teilen-Menue des Handys (sonst Link kopieren)
async function onShare() {
  const result = await shareOrCopy({
    title: group.value?.name ?? 'Nexxup',
    text: `Komm in die Gruppe „${group.value?.name ?? ''}“ auf Nexxup:`,
    url: inviteLink.value,
  });
  if (result === 'copied') notifySuccess('Einladelink kopiert');
  else if (result === 'failed') notifyError('Teilen nicht möglich. Bitte den Link von Hand kopieren.');
}

async function copyInvite() {
  try {
    await navigator.clipboard.writeText(inviteLink.value);
    notifySuccess('Einladelink kopiert');
  } catch {
    notifyError('Kopieren nicht möglich. Bitte den Link von Hand markieren und kopieren.');
  }
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
const edit = reactive({ name: '', description: '' });
function openEdit() {
  if (!group.value) return;
  edit.name = group.value.name;
  edit.description = group.value.description ?? '';
  editOpen.value = true;
}
async function onSaveEdit() {
  savingEdit.value = true;
  try {
    await groupsStore.updateGroup(groupId, { name: edit.name.trim(), description: edit.description.trim() || null });
    editOpen.value = false;
    notifySuccess('Gruppe gespeichert');
    await load(true);
  } catch (e) {
    notifyError(friendlyError(e, 'Die Gruppe konnte nicht gespeichert werden.'));
  } finally {
    savingEdit.value = false;
  }
}

function onRemoveMember(m: GroupMemberWithName) {
  $q.dialog({
    title: 'Mitglied entfernen',
    message: `${m.first_name ?? 'Diese Person'} aus der Gruppe entfernen? Zusagen in kommenden Events entfallen.`,
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

function onLeave() {
  $q.dialog({
    title: 'Gruppe verlassen',
    message: 'Möchtest du diese Gruppe wirklich verlassen? Deine Zusagen in kommenden Events entfallen.',
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
    message: 'Die Gruppe wird samt Events, Chat und Umfragen endgültig gelöscht. Fortfahren?',
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
  if (route.query.chat && isMember.value) {
    await nextTick();
    chatAnchor.value?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
});
</script>

<style scoped>
.nx-ghead {
  border-radius: 22px;
}
.nx-ghead__icon {
  width: 60px;
  height: 60px;
  border-radius: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Unbounded Variable', sans-serif;
  font-size: 26px;
  font-weight: 700;
  flex-shrink: 0;
}
.nx-toggle {
  border-radius: 14px;
  overflow: hidden;
  background: var(--nx-surface);
  border: 1px solid var(--nx-border);
}
</style>
