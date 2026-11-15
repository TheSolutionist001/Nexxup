import { defineBoot } from '#q-app';
import { applyThemePref, readThemePref, watchSystemTheme } from '@/utils/theme';

// Stellt beim Start den gemerkten Modus (System / Hell / Dunkel) ein.
export default defineBoot(() => {
  applyThemePref(readThemePref(), false);
  watchSystemTheme();
});
