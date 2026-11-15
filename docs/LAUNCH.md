# Checkliste: Test mit Freunden und Start

Diese Punkte kann nur der Projektinhaber erledigen (Einstellungen in fremden
Konten bzw. rechtliche Angaben). Reihenfolge = Priorität.

## A. Damit Freunde die Web-App nutzen können

1. **GitHub Pages einschalten (einmalig)**
   GitHub → Repository `i-need-you-app` → *Settings* → *Pages* →
   *Build and deployment*: Source **„Deploy from a branch“**, Branch
   **`gh-pages`**, Ordner **`/ (root)`** → *Save*.
   Danach ist die App nach 1–2 Minuten erreichbar unter
   **https://thesolutionist001.github.io/i-need-you-app/**
   (jeder neue Stand auf `main` wird automatisch veröffentlicht).

2. **Supabase: Adresse der App eintragen**
   Supabase → *Authentication* → *URL Configuration*:
   - *Site URL*: `https://thesolutionist001.github.io/i-need-you-app/`
   - *Redirect URLs* (hinzufügen):
     `https://thesolutionist001.github.io/i-need-you-app/**` und
     `http://localhost:9100/**`
   Ohne das funktionieren die Links in E-Mails („Passwort vergessen“,
   später E-Mail-Bestätigung) nicht.

3. **Betreiber-Angaben eintragen** – Datei `src/data/legal.ts`
   (Name, Anschrift, E-Mail). Solange sie fehlen, zeigen Impressum und
   Datenschutz einen Warnhinweis. Die Texte sind eine Vorlage: vor dem
   öffentlichen Start rechtlich prüfen lassen.

4. **Push-Benachrichtigungen (optional für den Test)**
   OneSignal → *Settings* → *Web* → *Site URL* auf
   `https://thesolutionist001.github.io` stellen (Push funktioniert pro
   OneSignal-App nur für eine Adresse). Auf dem iPhone gehen Push-Nachrichten
   erst, nachdem Nexxup zum Home-Bildschirm hinzugefügt wurde.

## B. Vor dem öffentlichen Start

- Supabase → *Authentication* → *Sign In / Providers* → E-Mail:
  **„Confirm email“ wieder einschalten** (ist für Tests aus).
- Supabase → *Authentication* → Passwörter:
  **Leaked Password Protection** einschalten, Mindestlänge 8.
- Supabase → eigener E-Mail-Versand (SMTP) einrichten – der eingebaute
  Versand ist auf wenige E-Mails pro Stunde begrenzt.
- **Kartenbilder:** aktuell OpenStreetMap (frei, aber nur für geringe Last
  gedacht). Für viele Nutzer: MapTiler, Stadia Maps o. ä. buchen und
  `TILE_URL` in `src/components/DiscoverMap.vue` + CSP in `index.html` ändern.
- **Ortssuche (Photon):** ebenfalls Fair-Use; bei viel Verkehr eigener
  Server oder bezahlter Anbieter.
- Eigene Domain (z. B. nexxup.app) statt der GitHub-Adresse; danach
  Supabase-URLs, OneSignal und `NEXXUP_PUBLIC_PATH` in
  `.github/workflows/deploy.yml` anpassen.
- Regelmäßig in die **Moderation** schauen (Profil → Moderation):
  Meldungen sollen innerhalb von 24 Stunden bearbeitet werden – das
  verlangen auch die App-Stores.

## C. Für die App-Stores (Phase 8)

Bereits erfüllt (Pflichten von Apple/Google für Apps mit Nutzer-Inhalten):
Melden von Gesuchen, Nachrichten, Gruppen und Profilen · Blockieren ·
Wortfilter vor dem Veröffentlichen · Konto in der App löschen ·
Community-Regeln mit Zustimmung bei der Registrierung · Kontaktangabe
(sobald `legal.ts` ausgefüllt ist).

Noch nötig:
- Apple Developer Program (99 $/Jahr) und Google-Play-Konto (25 $ einmalig).
- Zum Bauen: Android Studio (Windows reicht), für iOS ein Mac mit Xcode.
- Datenschutz-Angaben in den Stores („App Privacy“ / „Data safety“),
  Screenshots, Beschreibung, Altersfreigabe.
- Native Push-Anbindung (OneSignal-Capacitor-Plugin) und Test auf Geräten.
- Öffentlich erreichbare Seite „Konto löschen“ (Google verlangt einen
  Web-Link; die App-Funktion existiert, es fehlt nur die Info-Seite).
