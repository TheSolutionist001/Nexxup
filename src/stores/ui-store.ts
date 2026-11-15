import { ref } from 'vue';
import { defineStore } from 'pinia';

// Kleine, seitenuebergreifende Oberflaechen-Zustaende (Dialoge, die von
// ueberall geoeffnet werden koennen). Die Dialoge selbst haengen im MainLayout.
export const useUiStore = defineStore('ui', () => {
  // Profil-Karte einer anderen Person
  const profileUserId = ref<string | null>(null);
  function showProfile(userId: string) {
    profileUserId.value = userId;
  }

  const feedbackOpen = ref(false);

  return { profileUserId, showProfile, feedbackOpen };
});
