<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 640px; margin: 0 auto">
      <!-- Profil-Kopf -->
      <q-card class="q-mt-lg nx-profile-head">
        <div class="row items-center no-wrap q-pa-md" style="gap: 14px">
          <q-avatar color="primary" size="64px" style="font-size: 26px">{{ initials }}</q-avatar>
          <div class="col" style="min-width: 0">
            <div class="nx-display ellipsis" style="font-size: 20px">{{ authStore.profile?.first_name }}</div>
            <div class="text-caption text-grey">
              <q-icon name="place" size="14px" /> {{ authStore.profile?.city || 'Kein Ort hinterlegt' }}
            </div>
          </div>
          <q-btn class="nx-btn-soft" unelevated round icon="edit" aria-label="Profil bearbeiten" @click="openEdit" />
        </div>
        <div v-if="authStore.profile?.bio || mySports.length > 0" class="q-px-md q-pb-md">
          <div v-if="authStore.profile?.bio" style="white-space: pre-line">{{ authStore.profile.bio }}</div>
          <div v-if="mySports.length > 0" class="row q-gutter-xs q-mt-sm">
            <span v-for="s in mySports" :key="s.key" class="nx-chip" style="cursor: default">
              <span>{{ s.emoji }}</span>{{ s.label }}
            </span>
          </div>
        </div>
        <div v-else class="q-px-md q-pb-md text-caption text-grey">
          Erzähl kurz etwas über dich und wähle deine Sportarten – so finden dich die passenden Leute.
          <a href="#" @click.prevent="openEdit">Jetzt ergänzen</a>
        </div>
      </q-card>

      <div v-if="needsCity" class="nx-note nx-note--warning q-mt-md">
        Bitte wähle deinen Ort neu aus der Liste aus, damit Gruppen und Gesuche in deiner Nähe angezeigt
        werden. <a href="#" @click.prevent="openEdit">Ort wählen</a>
      </div>

      <!-- Darstellung -->
      <div class="nx-group-title">Darstellung</div>
      <q-btn-toggle
        v-model="theme"
        class="nx-theme-toggle"
        spread
        unelevated
        toggle-color="primary"
        toggle-text-color="dark"
        :options="[
          { label: 'System', value: 'system', icon: 'brightness_auto' },
          { label: 'Hell', value: 'light', icon: 'light_mode' },
          { label: 'Dunkel', value: 'dark', icon: 'dark_mode' },
        ]"
      />

      <!-- Benachrichtigungen -->
      <template v-if="pushAvailable">
        <div class="nx-group-title">Benachrichtigungen</div>
        <q-list class="nx-group">
          <q-item>
            <q-item-section avatar><div class="nx-icon-tile"><q-icon name="notifications" /></div></q-item-section>
            <q-item-section>
              <q-item-label>Push-Benachrichtigungen</q-item-label>
              <q-item-label caption>
                {{
                  pushEnabled
                    ? 'Aktiv – bei neuen Nachrichten, Terminen und wenn du nachrückst.'
                    : 'Bei neuen Nachrichten, vor Terminen und wenn du nachrückst.'
                }}
              </q-item-label>
              <q-item-label v-if="pushError" caption class="text-negative">{{ pushError }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-icon v-if="pushEnabled" name="check_circle" color="positive" size="24px" />
              <q-btn v-else unelevated color="primary" dense padding="6px 12px" label="Aktivieren" :loading="pushLoading" @click="onEnablePush" />
            </q-item-section>
          </q-item>
        </q-list>
      </template>

      <!-- App -->
      <div class="nx-group-title">App</div>
      <q-list class="nx-group">
        <q-item v-if="!installed && (canPrompt || isIos)" :clickable="canPrompt" @click="canPrompt && install()">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon name="install_mobile" /></div></q-item-section>
          <q-item-section>
            <q-item-label>Nexxup auf den Startbildschirm</q-item-label>
            <q-item-label caption>
              <template v-if="canPrompt">Wie eine echte App installieren – ein Tipp genügt.</template>
              <template v-else>
                In Safari unten auf „Teilen“ <q-icon name="ios_share" size="14px" /> tippen, dann „Zum
                Home-Bildschirm“.
              </template>
            </q-item-label>
          </q-item-section>
          <q-item-section v-if="canPrompt" side><q-icon name="chevron_right" /></q-item-section>
        </q-item>
        <q-item clickable @click="onInvite">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon name="person_add" /></div></q-item-section>
          <q-item-section>
            <q-item-label>Freunde einladen</q-item-label>
            <q-item-label caption>Link zu Nexxup teilen</q-item-label>
          </q-item-section>
          <q-item-section side><q-icon name="chevron_right" /></q-item-section>
        </q-item>
        <q-item clickable @click="ui.feedbackOpen = true">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon name="rate_review" /></div></q-item-section>
          <q-item-section>
            <q-item-label>Feedback geben</q-item-label>
            <q-item-label caption>Was gefällt dir, was fehlt?</q-item-label>
          </q-item-section>
          <q-item-section side><q-icon name="chevron_right" /></q-item-section>
        </q-item>
      </q-list>

      <!-- Sicherheit -->
      <div class="nx-group-title">Sicherheit & Privatsphäre</div>
      <q-list class="nx-group">
        <q-item clickable to="/reset-password">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon name="lock" /></div></q-item-section>
          <q-item-section>Passwort ändern</q-item-section>
          <q-item-section side><q-icon name="chevron_right" /></q-item-section>
        </q-item>
        <q-expansion-item>
          <template #header>
            <q-item-section avatar><div class="nx-icon-tile"><q-icon name="block" /></div></q-item-section>
            <q-item-section>
              <q-item-label>Blockierte Personen</q-item-label>
              <q-item-label caption>{{ blocked.length === 0 ? 'Niemand blockiert' : `${blocked.length} blockiert` }}</q-item-label>
            </q-item-section>
          </template>
          <q-list>
            <q-item v-if="blocked.length === 0">
              <q-item-section class="text-caption text-grey">
                Blockieren kannst du über das Menü an einem Gesuch, im Chat oder im Profil einer Person.
              </q-item-section>
            </q-item>
            <q-item v-for="b in blocked" :key="b.blocked_id">
              <q-item-section>{{ b.first_name ?? 'Unbekannt' }}</q-item-section>
              <q-item-section side>
                <q-btn flat dense color="primary" label="Aufheben" @click="onUnblock(b.blocked_id)" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-expansion-item>
      </q-list>

      <!-- Admin -->
      <template v-if="authStore.profile?.is_admin">
        <div class="nx-group-title">Verwaltung</div>
        <q-list class="nx-group">
          <q-item clickable to="/admin">
            <q-item-section avatar><div class="nx-icon-tile"><q-icon name="shield" /></div></q-item-section>
            <q-item-section>
              <q-item-label>Moderation</q-item-label>
              <q-item-label caption>Meldungen und Feedback</q-item-label>
            </q-item-section>
            <q-item-section side><q-icon name="chevron_right" /></q-item-section>
          </q-item>
        </q-list>
      </template>

      <!-- Rechtliches -->
      <div class="nx-group-title">Rechtliches</div>
      <q-list class="nx-group">
        <q-item v-for="l in legalLinks" :key="l.to" clickable :to="l.to">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon :name="l.icon" /></div></q-item-section>
          <q-item-section>{{ l.label }}</q-item-section>
          <q-item-section side><q-icon name="chevron_right" /></q-item-section>
        </q-item>
      </q-list>

      <!-- Konto -->
      <div class="nx-group-title">Konto</div>
      <q-list class="nx-group">
        <q-item>
          <q-item-section>
            <q-item-label caption>Angemeldet als</q-item-label>
            <q-item-label class="ellipsis">{{ authStore.user?.email }}</q-item-label>
          </q-item-section>
        </q-item>
        <q-item clickable @click="onLogout">
          <q-item-section avatar><div class="nx-icon-tile"><q-icon name="logout" /></div></q-item-section>
          <q-item-section>Abmelden</q-item-section>
        </q-item>
        <q-item clickable @click="deleteOpen = true">
          <q-item-section avatar>
            <div class="nx-icon-tile nx-icon-tile--danger"><q-icon name="delete_forever" /></div>
          </q-item-section>
          <q-item-section class="text-negative">Konto löschen</q-item-section>
        </q-item>
      </q-list>

      <div class="text-caption text-grey text-center q-mt-lg">Nexxup · Version {{ version }}</div>
    </div>

    <!-- Profil bearbeiten -->
    <q-dialog v-model="editOpen" :maximized="$q.screen.lt.sm">
      <q-card style="width: 100%; max-width: 480px">
        <q-form @submit="onSave">
          <q-card-section class="row items-center no-wrap">
            <div class="text-h6 col">Profil bearbeiten</div>
            <q-btn v-close-popup flat round dense icon="close" aria-label="Schließen" />
          </q-card-section>
          <q-card-section class="q-gutter-md q-pt-none">
            <q-input
              v-model="firstName"
              label="Vorname"
              maxlength="40"
              :rules="[(val: string) => !!val.trim() || 'Bitte Vorname eingeben']"
            />
            <q-select
              v-model="gender"
              :options="genderOptions"
              label="Geschlecht"
              emit-value
              map-options
              hint="Nicht öffentlich – nur für Gesuche, die sich an bestimmte Gruppen richten"
            />
            <CitySelect v-model="city" @select="onCity" />
            <div v-if="cityError" class="text-negative text-caption">{{ cityError }}</div>
            <q-input
              v-model="bio"
              type="textarea"
              autogrow
              label="Über mich (optional)"
              maxlength="200"
              counter
              placeholder="z. B. Laufe 2× pro Woche, suche Leute für lockere 10 km"
            />
            <div>
              <div class="text-caption text-grey q-mb-xs">Meine Sportarten (bis zu 8)</div>
              <div class="row q-gutter-xs">
                <button
                  v-for="s in sports.filter((x) => x.key !== 'sonstiges')"
                  :key="s.key"
                  type="button"
                  class="nx-chip"
                  :class="{ 'nx-chip--on': favSports.includes(s.key) }"
                  @click="toggleSport(s.key)"
                >
                  <span>{{ s.emoji }}</span>{{ s.label }}
                </button>
              </div>
            </div>
            <div class="text-caption text-grey">
              Andere sehen: Vorname, Stadt, „Über mich“ und Sportarten. Nie deine E-Mail oder dein Geschlecht.
            </div>
            <div v-if="errorMessage" class="text-negative text-caption">{{ errorMessage }}</div>
          </q-card-section>
          <q-card-actions align="right" class="q-px-md q-pb-md">
            <q-btn v-close-popup flat label="Abbrechen" />
            <q-btn type="submit" unelevated color="primary" label="Speichern" :loading="loading" />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>

    <!-- Konto loeschen -->
    <q-dialog v-model="deleteOpen">
      <q-card style="width: 100%; max-width: 420px">
        <q-card-section>
          <div class="text-h6">Konto endgültig löschen?</div>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <p>
            Dein Profil, deine Gesuche, Nachrichten, Zusagen und Mitgliedschaften werden unwiderruflich
            gelöscht. Gruppen, die du gegründet hast, gehen an das dienstälteste Mitglied über – Gruppen ohne
            weitere Mitglieder werden gelöscht.
          </p>
          <q-input
            v-model="deleteConfirm"
            outlined
            dense
            label="Zum Bestätigen LÖSCHEN eintippen"
            autocomplete="off"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn v-close-popup flat label="Abbrechen" />
          <q-btn
            unelevated
            color="negative"
            label="Konto löschen"
            :disable="deleteConfirm.trim().toUpperCase() !== 'LÖSCHEN'"
            :loading="deleting"
            @click="onDeleteAccount"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import CitySelect from '@/components/CitySelect.vue';
import { useAuthStore } from '@/stores/auth-store';
import { useChatStore } from '@/stores/chat-store';
import { useUiStore } from '@/stores/ui-store';
import { useInstallPrompt } from '@/composables/useInstallPrompt';
import { getSport, sports } from '@/data/sports';
import { genderOptions, type Gender } from '@/types/profile';
import type { BlockedUser } from '@/types/chat';
import type { City } from '@/utils/geocode';
import { friendlyError } from '@/utils/errors';
import { notifyError, notifySuccess } from '@/utils/notify';
import { isPushEnabled, pushAvailable, requestPushPermission } from '@/utils/push';
import { appUrl, shareOrCopy } from '@/utils/share';
import { applyThemePref, readThemePref, type ThemePref } from '@/utils/theme';
import { version } from '../../package.json';

const $q = useQuasar();
const router = useRouter();
const authStore = useAuthStore();
const chatStore = useChatStore();
const ui = useUiStore();
const { installed, canPrompt, isIos, install } = useInstallPrompt();

const initials = computed(() => (authStore.profile?.first_name?.[0] ?? '?').toUpperCase());
const mySports = computed(() => (authStore.profile?.sports ?? []).map((k) => getSport(k)));

const legalLinks = [
  { to: '/legal/regeln', label: 'Community-Regeln', icon: 'handshake' },
  { to: '/legal/datenschutz', label: 'Datenschutz', icon: 'policy' },
  { to: '/legal/impressum', label: 'Impressum', icon: 'info' },
];

// --- Darstellung ---
const theme = ref<ThemePref>(readThemePref());
watch(theme, (pref) => applyThemePref(pref));

// --- Profil bearbeiten ---
const editOpen = ref(false);
const firstName = ref('');
const gender = ref<Gender>('keine_angabe');
const city = ref<string | null>(null);
const selectedCity = ref<City | null>(null);
const bio = ref('');
const favSports = ref<string[]>([]);
const loading = ref(false);
const errorMessage = ref('');
const cityError = ref('');

// Hat das Profil schon Koordinaten? Aeltere Profile haben evtl. keinen Standort.
const hasLocation = ref(true);
const needsCity = computed(() => !hasLocation.value);

function openEdit() {
  const p = authStore.profile;
  firstName.value = p?.first_name ?? '';
  gender.value = p?.gender ?? 'keine_angabe';
  city.value = p?.city ?? null;
  selectedCity.value = null;
  bio.value = p?.bio ?? '';
  favSports.value = [...(p?.sports ?? [])];
  errorMessage.value = '';
  cityError.value = '';
  editOpen.value = true;
}

function onCity(c: City | null) {
  selectedCity.value = c;
  cityError.value = '';
}

function toggleSport(key: string) {
  if (favSports.value.includes(key)) favSports.value = favSports.value.filter((k) => k !== key);
  else if (favSports.value.length < 8) favSports.value = [...favSports.value, key];
}

async function onSave() {
  cityError.value = '';
  // Ort muss neu gewaehlt werden, wenn keiner gespeichert ist oder er geleert wurde.
  if (!selectedCity.value && (!city.value || !hasLocation.value)) {
    cityError.value = 'Bitte einen Ort aus der Liste auswählen.';
    return;
  }
  loading.value = true;
  errorMessage.value = '';
  try {
    await authStore.updateOwnProfile({
      first_name: firstName.value.trim(),
      gender: gender.value,
      bio: bio.value.trim() || null,
      sports: favSports.value,
      ...(selectedCity.value ? { city: selectedCity.value.name } : {}),
    });
    if (selectedCity.value) {
      await authStore.setLocation(selectedCity.value.lat, selectedCity.value.lng);
      hasLocation.value = true;
    }
    editOpen.value = false;
    notifySuccess('Profil gespeichert');
  } catch (e) {
    errorMessage.value = friendlyError(e, 'Speichern fehlgeschlagen. Bitte versuche es erneut.');
  } finally {
    loading.value = false;
  }
}

// --- Blockierte Personen ---
const blocked = ref<BlockedUser[]>([]);
async function loadBlocked() {
  try {
    blocked.value = await chatStore.fetchBlocked();
  } catch {
    blocked.value = [];
  }
}
async function onUnblock(id: string) {
  try {
    await chatStore.unblockUser(id);
    notifySuccess('Blockierung aufgehoben');
    await loadBlocked();
  } catch {
    notifyError('Das hat nicht geklappt.');
  }
}

// --- Push ---
const pushEnabled = ref(false);
const pushLoading = ref(false);
const pushError = ref('');

async function onEnablePush() {
  pushLoading.value = true;
  pushError.value = '';
  try {
    const result = await requestPushPermission();
    pushEnabled.value = result === 'granted';
    if (result === 'denied') {
      pushError.value =
        'Dein Browser blockiert Benachrichtigungen für diese Seite. Erlaube sie in den Website-Einstellungen und versuche es erneut.';
    } else if (result === 'unavailable') {
      pushError.value = isIos
        ? 'Auf dem iPhone funktionieren Benachrichtigungen erst, wenn du Nexxup zum Home-Bildschirm hinzugefügt hast.'
        : 'Benachrichtigungen sind in diesem Fenster nicht verfügbar (z. B. im privaten Modus).';
    }
  } finally {
    pushLoading.value = false;
  }
}

// --- App ---
async function onInvite() {
  const result = await shareOrCopy({
    title: 'Nexxup',
    text: 'Komm zu Nexxup – Leute für Sport in deiner Nähe finden:',
    url: appUrl(),
  });
  if (result === 'copied') notifySuccess('Link kopiert – einfach einfügen und verschicken');
  else if (result === 'failed') notifyError('Teilen nicht möglich.');
}

// --- Konto ---
const deleteOpen = ref(false);
const deleteConfirm = ref('');
const deleting = ref(false);

async function onLogout() {
  await authStore.signOut();
  await router.push('/login');
}

async function onDeleteAccount() {
  deleting.value = true;
  try {
    await authStore.deleteAccount();
    deleteOpen.value = false;
    notifySuccess('Dein Konto wurde gelöscht.');
    await router.push('/login');
  } catch {
    notifyError('Das Konto konnte nicht gelöscht werden. Bitte versuche es erneut.');
  } finally {
    deleting.value = false;
  }
}

onMounted(async () => {
  void loadBlocked();
  if (pushAvailable) pushEnabled.value = await isPushEnabled();
  try {
    hasLocation.value = (await authStore.fetchMyLocation()) !== null;
  } catch {
    // Unklar -> keinen falschen Hinweis zeigen.
  }
});
</script>

<style scoped>
.nx-profile-head {
  border-radius: 22px;
}
.nx-theme-toggle {
  border-radius: 14px;
  overflow: hidden;
  background: var(--nx-surface);
  border: 1px solid var(--nx-border);
}
.nx-icon-tile--danger {
  background: rgba(255, 90, 90, 0.14);
  color: var(--q-negative);
}
</style>
