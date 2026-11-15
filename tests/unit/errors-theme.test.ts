import { describe, expect, it, vi } from 'vitest';

// theme.ts nutzt Quasars Dark-Plugin (braucht einen Browser) - fuer die reine
// Logik hier durch eine Attrappe ersetzt.
vi.mock('quasar', () => ({ Dark: { set: vi.fn(), isActive: true } }));

import { friendlyError } from '@/utils/errors';
import { parseThemePref, toQuasarDark } from '@/utils/theme';

describe('friendlyError', () => {
  it('erklärt den Wortfilter und die Spam-Bremse verständlich', () => {
    expect(friendlyError({ message: 'content_blocked' }, 'x')).toMatch(/nicht erlaubt/);
    expect(friendlyError({ message: 'rate_limited' }, 'x')).toMatch(/später/);
  });

  it('nutzt sonst die übergebene Standardmeldung', () => {
    expect(friendlyError(new Error('irgendwas'), 'Standard')).toBe('Standard');
    expect(friendlyError(null, 'Standard')).toBe('Standard');
  });
});

describe('Darstellung (hell/dunkel)', () => {
  it('unbekannte oder fehlende Werte bedeuten "System"', () => {
    expect(parseThemePref(null)).toBe('system');
    expect(parseThemePref('lila')).toBe('system');
    expect(parseThemePref('light')).toBe('light');
    expect(parseThemePref('dark')).toBe('dark');
  });

  it('übersetzt die Wahl für Quasar', () => {
    expect(toQuasarDark('system')).toBe('auto');
    expect(toQuasarDark('dark')).toBe(true);
    expect(toQuasarDark('light')).toBe(false);
  });
});
