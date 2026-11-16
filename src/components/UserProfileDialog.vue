<template>
  <!-- Profil-Karte einer anderen Person: nur oeffentliche Angaben
       (Vorname, Stadt, Ueber mich, Lieblingssportarten). -->
  <q-dialog :model-value="!!ui.profileUserId" position="bottom" @update:model-value="(v) => !v && close()">
    <q-card class="nx-sheet">
      <div v-if="loading" class="text-center q-pa-xl"><q-spinner size="28px" color="primary" /></div>

      <div v-else-if="!profile" class="q-pa-lg text-center text-grey">Profil nicht gefunden.</div>

      <template v-else>
        <q-card-section class="row items-center no-wrap" style="gap: 14px">
          <q-avatar size="56px" class="text-weight-bold" :style="avatarStyle(profile.id)">
            {{ (profile.first_name?.[0] ?? '?').toUpperCase() }}
          </q-avatar>
          <div class="col" style="min-width: 0">
            <div class="nx-display ellipsis" style="font-size: 18px">{{ profile.first_name ?? 'Unbekannt' }}</div>
            <div v-if="profile.username" class="text-caption text-grey">@{{ profile.username }}</div>
            <div v-if="profile.city" class="text-caption text-grey">
              <q-icon name="place" size="14px" /> {{ profile.city }}
            </div>
          </div>
          <q-btn v-close-popup flat round dense icon="close" aria-label="Schließen" />
        </q-card-section>

        <q-card-section v-if="profile.bio || (profile.sports?.length ?? 0) > 0" class="q-pt-none">
          <div v-if="profile.bio" style="white-space: pre-line">{{ profile.bio }}</div>
          <div v-if="(profile.sports?.length ?? 0) > 0" class="row q-gutter-xs q-mt-sm">
            <span v-for="key in profile.sports ?? []" :key="key" class="nx-chip" style="cursor: default">
              <span>{{ getSport(key).emoji }}</span>{{ getSport(key).label }}
            </span>
          </div>
        </q-card-section>

        <q-card-section v-if="!isMe" class="q-pt-none column q-gutter-sm">
          <q-btn
            v-if="!blockedByMe"
            unelevated
            color="primary"
            icon="chat_bubble"
            label="Nachricht schreiben"
            :loading="starting !== null"
            @click="onMessage"
          />
          <div class="row q-gutter-sm">
            <q-btn
              class="col nx-btn-soft"
              unelevated
              :icon="blockedByMe ? 'lock_open' : 'block'"
              :label="blockedByMe ? 'Blockierung aufheben' : 'Blockieren'"
              @click="onToggleBlock"
            />
            <q-btn class="col nx-btn-soft" unelevated icon="flag" label="Melden" @click="reportOpen = true" />
          </div>
        </q-card-section>
      </template>
    </q-card>

    <ReportDialog v-model="reportOpen" title="Nutzer melden" @submit="onReport" />
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import ReportDialog from '@/components/ReportDialog.vue';
import { supabase } from '@/boot/supabase';
import { useAuthStore } from '@/stores/auth-store';
import { useChatStore } from '@/stores/chat-store';
import { useModerationStore } from '@/stores/moderation-store';
import { useUiStore } from '@/stores/ui-store';
import { useStartChat } from '@/composables/useStartChat';
import { getSport } from '@/data/sports';
import { avatarStyle } from '@/utils/avatar';
import { notifyError, notifySuccess } from '@/utils/notify';
import type { PublicProfile } from '@/types/profile';
import type { ReportReason } from '@/types/report';

const $q = useQuasar();
const ui = useUiStore();
const authStore = useAuthStore();
const chatStore = useChatStore();
const moderationStore = useModerationStore();
const { replyTo, starting } = useStartChat();

const profile = ref<PublicProfile | null>(null);
const loading = ref(false);
const blockedByMe = ref(false);
const reportOpen = ref(false);
const isMe = computed(() => ui.profileUserId === authStore.user?.id);

function close() {
  ui.profileUserId = null;
}

watch(
  () => ui.profileUserId,
  async (id) => {
    if (!id) return;
    loading.value = true;
    profile.value = null;
    try {
      const [{ data }, blocked] = await Promise.all([
        supabase.from('public_profiles').select('id, first_name, city, bio, sports, username').eq('id', id).maybeSingle(),
        chatStore.fetchBlocked().catch(() => []),
      ]);
      profile.value = data as PublicProfile | null;
      blockedByMe.value = blocked.some((b) => b.blocked_id === id);
    } finally {
      loading.value = false;
    }
  },
);

async function onMessage() {
  const id = ui.profileUserId;
  if (!id) return;
  await replyTo(id);
  close();
}

function onToggleBlock() {
  const id = ui.profileUserId;
  if (!id) return;
  if (blockedByMe.value) {
    chatStore
      .unblockUser(id)
      .then(() => {
        blockedByMe.value = false;
        notifySuccess('Blockierung aufgehoben');
      })
      .catch(() => notifyError('Das hat nicht geklappt.'));
    return;
  }
  $q.dialog({
    title: `${profile.value?.first_name ?? 'Person'} blockieren?`,
    message:
      'Ihr könnt euch dann nicht mehr schreiben und seht eure Gesuche am Brett gegenseitig nicht mehr. Die Person wird nicht benachrichtigt.',
    cancel: true,
    ok: { label: 'Blockieren', color: 'negative', flat: true },
  }).onOk(async () => {
    try {
      await chatStore.blockUser(id);
      blockedByMe.value = true;
      notifySuccess('Blockiert');
    } catch {
      notifyError('Blockieren hat nicht geklappt.');
    }
  });
}

async function onReport(reason: ReportReason) {
  const id = ui.profileUserId;
  if (!id) return;
  try {
    await moderationStore.reportProfile(id, reason);
    notifySuccess('Danke, die Meldung ist eingegangen.');
  } catch {
    notifyError('Melden fehlgeschlagen. Evtl. schon gemeldet?');
  } finally {
    reportOpen.value = false;
  }
}
</script>

<style scoped>
.nx-sheet {
  width: 100%;
  max-width: 480px;
  border-radius: 24px 24px 0 0 !important;
  padding-bottom: env(safe-area-inset-bottom);
}
</style>
