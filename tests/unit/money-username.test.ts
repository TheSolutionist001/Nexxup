import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { avatarHue } from '@/utils/avatar';
import { parseEuro } from '@/utils/money';
import { USERNAME_PATTERN, normalizeUsername, usernameError } from '@/utils/username';

describe('parseEuro', () => {
  it('liest übliche Schreibweisen', () => {
    expect(parseEuro('5')).toBe(500);
    expect(parseEuro('5,50')).toBe(550);
    expect(parseEuro('5.5')).toBe(550);
    expect(parseEuro(' 12,00 € ')).toBe(1200);
    expect(parseEuro(7)).toBe(700);
  });
  it('leer oder 0 bedeutet: keine Kosten', () => {
    expect(parseEuro('')).toBeNull();
    expect(parseEuro(null)).toBeNull();
    expect(parseEuro('0')).toBeNull();
  });
  it('erkennt ungültige Eingaben', () => {
    expect(parseEuro('abc')).toBeUndefined();
    expect(parseEuro('-5')).toBeUndefined();
    expect(parseEuro('5,123')).toBeUndefined();
    expect(parseEuro('99999999')).toBeUndefined();
  });
});

describe('Nutzername', () => {
  it('räumt Eingaben auf', () => {
    expect(normalizeUsername(' @Sandro_G ')).toBe('sandro_g');
  });
  it('prüft Länge und Zeichen', () => {
    expect(usernameError('sandro_4821')).toBeNull();
    expect(usernameError('ab')).toMatch(/Mindestens/);
    expect(usernameError('a'.repeat(21))).toMatch(/Höchstens/);
    expect(usernameError('sandro grimaldi')).toMatch(/Nur/);
    expect(usernameError('_sandro')).toMatch(/Nur/);
  });
  it('stimmt mit der Datenbank-Regel überein', () => {
    const sql = readFileSync('supabase/migrations/0019_username_fees_admin.sql', 'utf8');
    const match = sql.match(/username ~ '([^']+)'/);
    expect(match?.[1]).toBe(USERNAME_PATTERN.source);
  });
});

describe('avatarHue', () => {
  it('ist stabil und liegt im Farbkreis', () => {
    expect(avatarHue('abc')).toBe(avatarHue('abc'));
    expect(avatarHue('abc')).toBeGreaterThanOrEqual(0);
    expect(avatarHue('abc')).toBeLessThan(360);
    expect(avatarHue(null)).toBe(avatarHue(''));
  });
});
