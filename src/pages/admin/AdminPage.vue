<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 720px; margin: 0 auto">
      <div class="nx-display q-pt-lg q-mb-md" style="font-size: 24px">Moderation</div>

      <q-tabs v-model="tab" dense no-caps align="left" active-color="primary" indicator-color="primary" class="q-mb-md">
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
import { ref, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import EmptyState from '@/components/EmptyState.vue';
import { useModerationStore } from '@/stores/moderation-store';
import { notifyError, notifySuccess } from '@/utils/notify';
import {
  reportReasonOptions,
  type AdminFeedback,
  type AdminReport,
  type ReportKind,
  type ReportReason,
} from '@/types/report';

const $q = useQuasar();
const moderationStore = useModerationStore();

const tab = ref<'reports' | 'feedback'>('reports');
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
    [reports.value, feedback.value] = await Promise.all([
      moderationStore.listReports(),
      moderationStore.listFeedback(),
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
