<template>
  <!-- Nachrichtenverlauf + Eingabe. Fuer Direkt-Chats (threadId) und
       Gruppen-Chats (groupId). Wer was lesen/schreiben darf, entscheidet die
       Datenbank (RLS) - hier wird nur angezeigt. -->
  <div class="nx-chat" :style="{ height }">
    <div ref="scrollEl" class="nx-chat__list">
      <div v-if="loading" class="text-center q-pa-lg">
        <q-spinner size="28px" color="primary" />
      </div>
      <div v-else-if="loadError" class="text-center text-grey q-pa-lg">
        Nachrichten konnten nicht geladen werden.
        <div><q-btn flat no-caps color="primary" label="Erneut versuchen" @click="load()" /></div>
      </div>
      <div v-else-if="messages.length === 0" class="text-center text-grey q-pa-lg">
        {{ emptyText }}
      </div>
      <template v-else>
        <div
          v-for="m in messages"
          :key="m.id"
          class="nx-msg"
          :class="m.sender_id === myId ? 'nx-msg--mine' : 'nx-msg--theirs'"
        >
          <div
            v-if="showNames && m.sender_id !== myId"
            class="nx-msg__name cursor-pointer"
            @click="ui.showProfile(m.sender_id)"
          >
            {{ m.sender_first_name ?? 'Unbekannt' }}
          </div>
          <div class="nx-msg__bubble" :class="{ 'cursor-pointer': m.sender_id !== myId }">
            {{ m.body }}
            <!-- Fremde Nachricht antippen: melden (Pflicht fuer die App-Stores) -->
            <q-menu v-if="m.sender_id !== myId" touch-position>
              <q-list style="min-width: 190px">
                <q-item v-close-popup clickable @click="ui.showProfile(m.sender_id)">
                  <q-item-section avatar><q-icon name="person" /></q-item-section>
                  <q-item-section>Profil ansehen</q-item-section>
                </q-item>
                <q-item v-close-popup clickable @click="openReport(m.id)">
                  <q-item-section avatar><q-icon name="flag" /></q-item-section>
                  <q-item-section>Nachricht melden</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </div>
          <div class="nx-msg__time">{{ formatChatTime(m.created_at) }}</div>
        </div>
      </template>
    </div>

    <div v-if="canWrite" class="nx-chat__input">
      <q-input
        v-model="draft"
        dense
        outlined
        autogrow
        maxlength="2000"
        placeholder="Nachricht schreiben …"
        class="col"
        input-style="max-height: 120px"
        @keydown.enter.exact.prevent="send"
      />
      <q-btn
        round
        unelevated
        color="primary"
        text-color="dark"
        icon="send"
        aria-label="Senden"
        :loading="sending"
        :disable="!draft.trim()"
        @click="send"
      />
    </div>
    <div v-else-if="disabledText" class="nx-chat__disabled">{{ disabledText }}</div>

    <ReportDialog v-model="reportOpen" title="Nachricht melden" @submit="onReport" />
  </div>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue';
import { useChatStore } from '@/stores/chat-store';
import { useRealtime } from '@/composables/useRealtime';
import { formatChatTime } from '@/utils/format';
import ReportDialog from '@/components/ReportDialog.vue';
import { useModerationStore } from '@/stores/moderation-store';
import { useUiStore } from '@/stores/ui-store';
import { friendlyError } from '@/utils/errors';
import { notifyError, notifySuccess } from '@/utils/notify';
import type { ChatMessageView } from '@/types/chat';
import type { ReportReason } from '@/types/report';

const props = withDefaults(
  defineProps<{
    threadId?: string;
    groupId?: string;
    myId: string | null;
    canWrite?: boolean;
    showNames?: boolean;
    height?: string;
    emptyText?: string;
    disabledText?: string;
  }>(),
  { canWrite: true, showNames: false, height: '420px', emptyText: 'Noch keine Nachrichten. Sag Hallo!', disabledText: '' },
);

const chatStore = useChatStore();
const moderationStore = useModerationStore();
const ui = useUiStore();

// Nachricht melden: danach ist sie fuer mich ausgeblendet, die Moderation prueft.
const reportOpen = ref(false);
const reportMessageId = ref<string | null>(null);
function openReport(id: string) {
  reportMessageId.value = id;
  reportOpen.value = true;
}
async function onReport(reason: ReportReason) {
  if (!reportMessageId.value) return;
  try {
    await moderationStore.report('message', reportMessageId.value, reason);
    notifySuccess('Danke, die Meldung ist eingegangen.');
    await load(true);
  } catch {
    notifyError('Melden fehlgeschlagen. Evtl. schon gemeldet?');
  } finally {
    reportOpen.value = false;
  }
}
const target = props.threadId ? { threadId: props.threadId } : { groupId: props.groupId ?? '' };

const messages = ref<ChatMessageView[]>([]);
const loading = ref(true);
const loadError = ref(false);
const draft = ref('');
const sending = ref(false);
const scrollEl = ref<HTMLDivElement | null>(null);

async function scrollToBottom() {
  await nextTick();
  if (scrollEl.value) scrollEl.value.scrollTop = scrollEl.value.scrollHeight;
}

async function load(silent = false) {
  if (!silent) loading.value = true;
  try {
    messages.value = await chatStore.fetchMessages(target);
    loadError.value = false;
    void chatStore.markRead(target);
    await scrollToBottom();
  } catch {
    if (!silent) loadError.value = true;
  } finally {
    if (!silent) loading.value = false;
  }
}

async function send() {
  const text = draft.value.trim();
  if (!text || sending.value) return;
  sending.value = true;
  try {
    await chatStore.sendMessage(target, text);
    draft.value = '';
    await load(true);
  } catch (e) {
    notifyError(friendlyError(e, 'Die Nachricht konnte nicht gesendet werden.'));
  } finally {
    sending.value = false;
  }
}

// Neue Nachrichten live (RLS: es kommen nur Nachrichten an, die ich lesen darf)
useRealtime(
  'chat_messages',
  props.threadId ? `thread_id=eq.${props.threadId}` : `group_id=eq.${props.groupId}`,
  () => void load(true),
);

onMounted(() => load());

defineExpose({ reload: () => load(true) });
</script>

<style scoped>
.nx-chat {
  display: flex;
  flex-direction: column;
  min-height: 260px;
  border-radius: 20px;
  background: var(--nx-surface);
  border: 1px solid var(--nx-border);
  overflow: hidden;
}
.nx-chat__list {
  flex: 1;
  overflow-y: auto;
  padding: 14px 12px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.nx-msg {
  display: flex;
  flex-direction: column;
  max-width: 80%;
}
.nx-msg--mine {
  align-self: flex-end;
  align-items: flex-end;
}
.nx-msg--theirs {
  align-self: flex-start;
  align-items: flex-start;
}
.nx-msg__name {
  font-size: 11px;
  color: var(--nx-muted);
  margin: 0 10px 2px;
}
.nx-msg__bubble {
  padding: 8px 12px;
  border-radius: 18px;
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.35;
}
.nx-msg--mine .nx-msg__bubble {
  background: var(--nx-accent);
  color: var(--nx-ink);
  border-bottom-right-radius: 6px;
}
.nx-msg--theirs .nx-msg__bubble {
  background: var(--nx-surface-2);
  color: var(--nx-text);
  border-bottom-left-radius: 6px;
}
.nx-msg__time {
  font-size: 10px;
  color: var(--nx-muted);
  margin: 2px 8px 0;
}
.nx-chat__input {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  padding: 10px;
  border-top: 1px solid var(--nx-border);
}
.nx-chat__disabled {
  padding: 12px;
  text-align: center;
  font-size: 13px;
  color: var(--nx-muted);
  border-top: 1px solid var(--nx-border);
}
</style>
