import { computed, ref } from 'vue';

// "App installieren": Android/Chrome bieten einen eigenen Dialog an
// (beforeinstallprompt). Auf dem iPhone gibt es den nicht - dort zeigt die
// App eine kurze Anleitung (Teilen -> Zum Home-Bildschirm).
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

const deferred = ref<BeforeInstallPromptEvent | null>(null);
const installed = ref(false);
let listening = false;

function isStandalone(): boolean {
  return (
    window.matchMedia('(display-mode: standalone)').matches ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true
  );
}

export function initInstallPrompt(): void {
  if (listening) return;
  listening = true;
  installed.value = isStandalone();
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferred.value = e as BeforeInstallPromptEvent;
  });
  window.addEventListener('appinstalled', () => {
    installed.value = true;
    deferred.value = null;
  });
}

export function useInstallPrompt() {
  initInstallPrompt();
  const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const canPrompt = computed(() => deferred.value !== null);

  async function install(): Promise<boolean> {
    if (!deferred.value) return false;
    await deferred.value.prompt();
    const { outcome } = await deferred.value.userChoice;
    deferred.value = null;
    return outcome === 'accepted';
  }

  return { installed, canPrompt, isIos, install };
}
