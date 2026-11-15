# Nexxup

Community-App für Sport: Gruppen mit Warteliste, spontane Gesuche am „Brett“,
Karte, Chat, Termine mit Zusagen. Web-App (Vue 3 + Quasar), Backend Supabase,
später per Capacitor als Android-/iOS-App.

- **Technischer Leitfaden:** [`CLAUDE.md`](CLAUDE.md)
- **Projektbrief:** [`handout-i-need-you.md`](handout-i-need-you.md)
- **Checkliste vor dem Start:** [`docs/LAUNCH.md`](docs/LAUNCH.md)

## Lokal starten

Windows: Doppelklick auf `Nexxup starten.bat`.

Sonst:

```bash
cp .env.example .env   # Werte eintragen
npm install
npm run dev            # http://localhost:9100
```

## Prüfen

```bash
npm run typecheck
npm test
npx quasar build
```

## Veröffentlichen

Jeder Stand auf `main` wird automatisch gebaut und auf GitHub Pages
veröffentlicht (`.github/workflows/deploy.yml`):
`https://thesolutionist001.github.io/<repository-name>/`

## Datenbank

Migrationen liegen unter `supabase/migrations/` (nummeriert, der Reihe nach
einspielen). Jede Datei beginnt mit einer Erklärung in einfachen Worten.
