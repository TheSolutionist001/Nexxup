<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 720px; margin: 0 auto">
      <div class="nx-display q-pt-lg q-mb-md" style="font-size: 24px">Verwaltung</div>

      <q-tabs
        v-model="tab"
        dense
        no-caps
        align="left"
        active-color="primary"
        indicator-color="primary"
        class="q-mb-md"
        outside-arrows
        mobile-arrows
      >
        <q-tab name="overview" label="Übersicht" />
        <q-tab name="users" :label="`Nutzer (${users.length})`" />
        <q-tab name="groups" :label="`Gruppen (${groups.length})`" />
        <q-tab name="reports" :label="`Meldungen (${reports.length})`" />
        <q-tab name="feedback" :label="`Feedback (${feedback.length})`" />
      </q-tabs>

      <div v-if="loading" class="text-center q-pa-lg">
        <q-spinner size="32px" color="primary" />
      </div>

      <EmptyState
        v-else-if="loadError"
        icon="cloud_off"
        title="Daten konnten nicht geladen werden"
        text="Prüfe deine Internetverbindung und versuche es erneut."
      >
        <q-btn outline color="primary" icon="refresh" label="Erneut versuchen" @click="load" />
      </EmptyState>

      <!-- Uebersicht -->
      <template v-else-if="tab === 'overview'">
        <div v-if="stats" class="nx-stats">
          <div v-for="t in tiles" :key="t.label" class="nx-stat" :class="{ 'nx-stat--alert': t.alert }" @click="t.tab && (tab = t.tab)">
            <q-icon :name="t.icon" size="20px" class="nx-stat__icon" />
            <div class="nx-stat__value">{{ t.value }}</div>
            <div class="nx-stat__label">{{ t.label }}</div>
            <div v-if="t.sub" class="nx-stat__sub">{{ t.sub }}</div>
          </div>
        </div>
        <div class="text-caption text-grey q-mt-md">
          „Aktiv“ = in den letzten 7 Tagen angemeldet. Tippe auf eine Kachel, um zur Liste zu springen.
        </div>
      </template>

      <!-- Nutzer -->
      <template v-else-if="tab === 'users'">
        <q-input v-model="userSearch" dense outlined clearable placeholder="Name, Nutzername, Stadt oder E-Mail" class="q-mb-sm">
          <template #prepend><q-icon name="search" /></template>
        </q-input>
        <EmptyState v-if="filteredUsers.length === 0" icon="person_search" title="Niemand gefunden" />
        <q-list v-else class="nx-group">
          <q-item v-for="u in filteredUsers" :key="u.id">
            <q-item-section avatar>
              <q-avatar size="36px" class="text-weight-bold" :style="avatarStyle(u.id)">
                {{ (u.first_name?.[0] ?? '?').toUpperCase() }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label>
                {{ u.first_name || 'Ohne Namen' }}
                <q-badge v-if="u.is_admin" color="primary" label="Admin" class="q-ml-xs" />
                <q-badge v-if="u.is_banned" color="negative" label="gesperrt" class="q-ml-xs" />
              </q-item-label>
              <q-item-label caption>@{{ u.username }} · {{ u.city || 'ohne Ort' }}</q-item-label>
              <q-item-label caption class="ellipsis">{{ u.email }}</q-item-label>
              <q-item-label caption>
                dabei seit {{ formatDay(u.created_at) }} · zuletzt
                {{ u.last_sign_in_at ? formatDay(u.last_sign_in_at) : 'nie' }} · {{ u.groups_count }} Gruppen ·
                {{ u.posts_count }} Gesuche
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-btn flat round dense icon="more_vert" aria-label="Aktionen">
                <q-menu>
                  <q-list style="min-width: 180px">
                    <q-item v-close-popup clickable @click="ui.showProfile(u.id)">
                      <q-item-section>Profil ansehen</q-item-section>
                    </q-item>
                    <q-item v-if="!u.is_banned && !u.is_admin" v-close-popup clickable @click="onBanUser(u)">
                      <q-item-section class="text-negative">Sperren</q-item-section>
                    </q-item>
                    <q-item v-if="u.is_banned" v-close-popup clickable @click="onUnbanUser(u)">
                      <q-item-section>Entsperren</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-item-section>
          </q-item>
        </q-list>
      </template>

      <!-- Gruppen -->
      <template v-else-if="tab === 'groups'">
        <EmptyState v-if="groups.length === 0" icon="groups" title="Noch keine Gruppen" />
        <q-list v-else class="nx-group">
          <q-item v-for="g in groups" :key="g.id">
            <q-item-section avatar>
              <div class="nx-admin-sport" :style="{ background: sportGradient(g.sport) }">{{ getSport(g.sport).emoji }}</div>
            </q-item-section>
            <q-item-section>
              <q-item-label>
                {{ g.name }}
                <q-badge v-if="g.is_public_event" outline color="primary" label="öffentlich" class="q-ml-xs" />
              </q-item-label>
              <q-item-label caption>
                {{ getSport(g.sport).label }} · {{ g.city || 'ohne Ort' }} · von {{ g.creator_name ?? '?' }}
                <template v-if="g.creator_username">(@{{ g.creator_username }})</template>
              </q-item-label>
              <q-item-label caption>
                {{ g.members_active }}/{{ g.max_members }} dabei
                <template v-if="g.members_waitlist > 0"> · {{ g.members_waitlist }} warten</template>
                · Termin: {{ g.next_meetup_at ? formatDate(g.next_meetup_at) : 'keiner' }} · erstellt {{ formatDay(g.created_at) }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-btn flat round dense icon="delete" color="negative" aria-label="Gruppe löschen" @click="onDeleteGroup(g)" />
            </q-item-section>
          </q-item>
        </q-list>
        <div class="text-caption text-grey q-mt-sm">
          Als Admin siehst du hier alle Gruppen (auch private) mit Kennzahlen – Chat und Treffpunkt bleiben den
          Mitgliedern vorbehalten.
        </div>
      </template>

      <!-- Meldungen -->
      <template v-else-if="tab === 'reports'">
        <EmptyState v-if="reports.length === 0" icon="verified_user" title="Alles ruhig" text="Es gibt keine offenen Meldungen." />
        <div v-else class="column q-gutter-sm">
          <q-card v-for="r in reports" :key="r.report_id" class="q-pa-md">
            <div class="row items-center q-gutter-xs">
              <q-badge :color="kindMeta[r.kind].color" :label="kindMeta[r.kind].label" />
              <q-badge outline color="grey" :label="reasonLabel(r.reason)" />
              <q-badge v-if="r.target_is_banned" color="negative" label="bereits gesperrt" />
              <q-space />
              <span class="text-caption text-grey">{{ formatDate(r.created_at) }}</span>
            </div>
            <div class="q-mt-sm" style="white-space: pre-line; word-break: break-word">
              <template v-if="r.content">„{{ r.content }}“</template>
              <span v-else class="text-grey">(kein Text bzw. bereits gelöscht)</span>
            </div>
            <div class="text-caption text-grey q-mt-xs">
              Von: <b>{{ r.target_user_name ?? 'Unbekannt' }}</b> · gemeldet von {{ r.reporter_name ?? 'Unbekannt' }}
            </div>
            <div class="row q-gutter-sm q-mt-sm">
              <q-btn
                v-if="deleteAction(r)"
                dense flat color="negative" icon="delete" :label="deleteAction(r)!.label"
                @click="onDelete(r)"
              />
              <q-btn
                v-if="r.target_user_id && !r.target_is_banned"
                dense flat color="negative" icon="gavel" label="Nutzer sperren"
                @click="onBan(r)"
              />
              <q-btn
                v-if="r.target_user_id && r.target_is_banned"
                dense flat icon="lock_open" label="Entsperren"
                @click="onUnban(r)"
              />
              <q-space />
              <q-btn dense flat color="primary" icon="done" label="Erledigt" @click="onResolve(r)" />
            </div>
          </q-card>
        </div>
      </template>

      <!-- Feedback -->
      <template v-else>
        <EmptyState v-if="feedback.length === 0" icon="rate_review" title="Noch kein Feedback" text="Rückmeldungen der Tester erscheinen hier." />
        <div v-else class="column q-gutter-sm">
          <q-card v-for="f in feedback" :key="f.id" class="q-pa-md">
            <div class="text-caption text-grey">
              {{ f.user_name ?? 'Gelöschtes Konto' }} · {{ formatDate(f.created_at) }}
              <template v-if="f.page"> · Seite {{ f.page }}</template>
            </div>
            <div class="q-mt-xs" style="white-space: pre-line; word-break: break-word">{{ f.message }}</div>
          </q-card>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import EmptyState from '@/components/EmptyState.vue';
import { useModerationStore } from '@/stores/moderation-store';
import { notifyError, notifySuccess } from '@/utils/notify';
import { useUiStore } from '@/stores/ui-store';
import { getSport, sportGradient } from '@/data/sports';
import { avatarStyle } from '@/utils/avatar';
import {
  reportReasonOptions,
  type AdminFeedback,
  type AdminGroup,
  type AdminOverview,
  type AdminReport,
  type AdminUser,
  type ReportKind,
  type ReportReason,
} from '@/types/report';

const $q = useQuasar();
const moderationStore = useModerationStore();

const ui = useUiStore();

type Tab = 'overview' | 'users' | 'groups' | 'reports' | 'feedback';
const tab = ref<Tab>('overview');
const stats = ref<AdminOverview | null>(null);
const users = ref<AdminUser[]>([]);
const groups = ref<AdminGroup[]>([]);
const userSearch = ref<string | null>('');

const filteredUsers = computed(() => {
  const q = (userSearch.value ?? '').trim().toLowerCase();
  if (!q) return users.value;
  return users.value.filter((u) =>
    [u.first_name, u.username, u.city, u.email].some((v) => (v ?? '').toLowerCase().includes(q)),
  );
});

// Kennzahlen-Kacheln der Uebersicht
const tiles = computed(() => {
  const s = stats.value;
  if (!s) return [];
  const tile = (icon: string, value: number, label: string, sub = '', t: Tab | null = null, alert = false) => ({
    icon, value, label, sub, tab: t, alert,
  });
  return [
    tile('group', s.users_total, 'Nutzer', `${s.users_new_7d} neu · ${s.users_active_7d} aktiv`, 'users'),
    tile('groups', s.groups_total, 'Gruppen', `${s.groups_public} öffentlich · ${s.groups_new_7d} neu`, 'groups'),
    tile('event', s.meetups_upcoming, 'Kommende Termine', `${s.rsvps_yes_upcoming} Zusagen`),
    tile('push_pin', s.posts_active, 'Aktive Gesuche', `${s.posts_new_7d} neu (7 Tage)`),
    tile('chat', s.messages_7d, 'Nachrichten', 'letzte 7 Tage'),
    tile('flag', s.reports_open, 'Offene Meldungen', s.reports_open > 0 ? 'bitte prüfen' : 'alles ruhig', 'reports', s.reports_open > 0),
    tile('rate_review', s.feedback_total, 'Feedback', '', 'feedback'),
    tile('gavel', s.users_banned, 'Gesperrte Konten', '', 'users'),
  ];
});

function formatDay(iso: string): string {
  return new Date(iso).toLocaleDateString('de-DE', { day: 'numeric', month: 'short', year: '2-digit' });
}
const reports = ref<AdminReport[]>([]);
const feedback = ref<AdminFeedback[]>([]);
const loading = ref(true);
const loadError = ref(false);

const kindMeta: Record<ReportKind, { label: string; color: string }> = {
  post: { label: 'Gesuch', color: 'orange' },
  message: { label: 'Nachricht', color: 'blue' },
  group: { label: 'Gruppe', color: 'teal' },
  profile: { label: 'Profil', color: 'purple' },
};

function reasonLabel(reason: ReportReason | null): string {
  if (!reason) return 'ohne Grund';
  return reportReasonOptions.find((o) => o.value === reason)?.label ?? reason;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });
}

async function load() {
  loading.value = true;
  try {
    [reports.value, feedback.value, stats.value, users.value, groups.value] = await Promise.all([
      moderationStore.listReports(),
      moderationStore.listFeedback(),
      moderationStore.overview(),
      moderationStore.listUsers(),
      moderationStore.listGroups(),
    ]);
    loadError.value = false;
  } catch {
    loadError.value = true;
  } finally {
    loading.value = false;
  }
}

// Was laesst sich bei dieser Meldung loeschen?
function deleteAction(r: AdminReport): { label: string; run: () => Promise<void> } | null {
  if (r.kind === 'post' && r.reported_post_id) {
    const id = r.reported_post_id;
    return { label: 'Gesuch löschen', run: () => moderationStore.deletePost(id) };
  }
  if (r.kind === 'message' && r.reported_message_id) {
    const id = r.reported_message_id;
    return { label: 'Nachricht löschen', run: () => moderationStore.deleteMessage(id) };
  }
  if (r.kind === 'group' && r.reported_group_id) {
    const id = r.reported_group_id;
    return { label: 'Gruppe löschen', run: () => moderationStore.deleteGroup(id) };
  }
  return null;
}

function confirm(title: string, message: string, action: () => Promise<void>, done: string) {
  $q.dialog({ title, message, cancel: true }).onOk(async () => {
    try {
      await action();
      notifySuccess(done);
      await load();
    } catch {
      notifyError('Die Aktion ist fehlgeschlagen.');
    }
  });
}

function onDelete(r: AdminReport) {
  const action = deleteAction(r);
  if (!action) return;
  confirm(action.label, 'Der Inhalt wird für alle endgültig gelöscht. Fortfahren?', action.run, 'Gelöscht.');
}

function onBan(r: AdminReport) {
  const id = r.target_user_id;
  if (!id) return;
  confirm(
    'Nutzer sperren',
    `${r.target_user_name ?? 'Diese Person'} wird gesperrt. Gesuche, Nachrichten und eigene Gruppen werden entfernt. Fortfahren?`,
    () => moderationStore.banUser(id),
    'Nutzer gesperrt.',
  );
}

function onUnban(r: AdminReport) {
  const id = r.target_user_id;
  if (!id) return;
  confirm('Entsperren', `${r.target_user_name ?? 'Diese Person'} kann sich wieder anmelden.`, () => moderationStore.unbanUser(id), 'Entsperrt.');
}

function onBanUser(u: AdminUser) {
  confirm(
    'Nutzer sperren',
    `${u.first_name} (@${u.username}) wird gesperrt. Gesuche, Nachrichten und eigene Gruppen werden entfernt. Fortfahren?`,
    () => moderationStore.banUser(u.id),
    'Nutzer gesperrt.',
  );
}

function onUnbanUser(u: AdminUser) {
  confirm('Entsperren', `${u.first_name} (@${u.username}) kann sich wieder anmelden.`, () => moderationStore.unbanUser(u.id), 'Entsperrt.');
}

function onDeleteGroup(g: AdminGroup) {
  confirm(
    'Gruppe löschen',
    `„${g.name}“ wird samt Chat, Umfragen und Mitgliedschaften für alle endgültig gelöscht. Fortfahren?`,
    () => moderationStore.deleteGroup(g.id),
    'Gruppe gelöscht.',
  );
}

async function onResolve(r: AdminReport) {
  try {
    await moderationStore.resolveReport(r.report_id);
    reports.value = reports.value.filter((x) => x.report_id !== r.report_id);
  } catch {
    notifyError('Die Meldung konnte nicht abgeschlossen werden.');
  }
}

onMounted(load);
</script>

<style scoped>
.nx-stats {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 10px;
}
.nx-stat {
  border-radius: 18px;
  background: var(--nx-surface);
  border: 1px solid var(--nx-border);
  padding: 14px;
  cursor: pointer;
}
.nx-stat--alert {
  border-color: var(--nx-accent);
}
.nx-stat__icon {
  color: var(--nx-accent-text);
}
.nx-stat__value {
  font-family: 'Unbounded Variable', sans-serif;
  font-size: 26px;
  font-weight: 700;
  line-height: 1.2;
  margin-top: 6px;
}
.nx-stat__label {
  font-weight: 600;
}
.nx-stat__sub {
  font-size: 12px;
  color: var(--nx-muted);
}
.nx-admin-sport {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
}
</style>
