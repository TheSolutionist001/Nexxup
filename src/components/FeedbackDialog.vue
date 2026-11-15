<template>
  <!-- Rueckmeldung der Tester an das Nexxup-Team (landet in der Moderation) -->
  <q-dialog v-model="ui.feedbackOpen">
    <q-card style="width: 100%; max-width: 440px">
      <q-card-section>
        <div class="text-h6">Feedback geben</div>
        <div class="text-caption text-grey">
          Was gefällt dir, was nervt, was fehlt? Jede Rückmeldung hilft, Nexxup besser zu machen.
        </div>
      </q-card-section>
      <q-card-section class="q-pt-none">
        <q-input
          v-model="message"
          type="textarea"
          outlined
          autofocus
          :input-style="{ minHeight: '120px' }"
          maxlength="2000"
          counter
          placeholder="Deine Rückmeldung …"
        />
      </q-card-section>
      <q-card-actions align="right">
        <q-btn v-close-popup flat label="Abbrechen" />
        <q-btn unelevated color="primary" label="Senden" :disable="message.trim().length < 3" :loading="sending" @click="send" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRoute } from 'vue-router';
import { useModerationStore } from '@/stores/moderation-store';
import { useUiStore } from '@/stores/ui-store';
import { friendlyError } from '@/utils/errors';
import { notifyError, notifySuccess } from '@/utils/notify';

const ui = useUiStore();
const route = useRoute();
const moderationStore = useModerationStore();
const message = ref('');
const sending = ref(false);

async function send() {
  sending.value = true;
  try {
    await moderationStore.sendFeedback(message.value, route.fullPath);
    message.value = '';
    ui.feedbackOpen = false;
    notifySuccess('Danke für dein Feedback!');
  } catch (e) {
    notifyError(friendlyError(e, 'Das Feedback konnte nicht gesendet werden.'));
  } finally {
    sending.value = false;
  }
}
</script>
