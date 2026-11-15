<template>
  <q-page class="q-px-md q-pb-xl">
    <div style="max-width: 720px; margin: 0 auto">
      <q-btn flat dense icon="arrow_back" label="Zurück" class="q-mt-md" @click="goBack" />
      <div class="nx-display q-mt-sm" style="font-size: 22px; line-height: 1.2">{{ legalTitles[doc] }}</div>
      <div class="text-caption text-grey q-mb-md">Stand: {{ legalVersion }}</div>

      <div v-if="!operatorComplete" class="nx-note nx-note--warning q-mb-md">
        Hinweis: Die Betreiber-Angaben (Name, Anschrift, E-Mail) sind noch nicht eingetragen. Diese Seite ist
        eine Vorlage und vor dem öffentlichen Start zu vervollständigen und rechtlich prüfen zu lassen.
      </div>

      <!-- ===== Community-Regeln ===== -->
      <div v-if="doc === 'regeln'" class="nx-prose">
        <p>
          Nexxup bringt Menschen für Sport und gemeinsame Aktivitäten zusammen. Damit sich alle wohlfühlen,
          gelten diese Regeln. Mit der Registrierung stimmst du ihnen zu.
        </p>
        <h2>1. Wer mitmachen darf</h2>
        <ul>
          <li>Du bist mindestens {{ MIN_AGE }} Jahre alt.</li>
          <li>Ein Konto pro Person, mit deinem echten Vornamen.</li>
        </ul>
        <h2>2. So gehen wir miteinander um</h2>
        <ul>
          <li>Respektvoll und freundlich – auf dem Platz und im Chat.</li>
          <li>Keine Beleidigungen, Drohungen, Hassrede oder Diskriminierung.</li>
          <li>Keine sexuellen Inhalte oder Anmachen, keine Belästigung.</li>
          <li>Keine Werbung, kein Spam, keine kommerziellen Angebote ohne Absprache.</li>
          <li>Nichts Illegales und keine Inhalte, die Rechte anderer verletzen.</li>
        </ul>
        <h2>3. Verlässlichkeit</h2>
        <ul>
          <li>Sag zu, wenn du kommst – und ab, wenn du doch nicht kannst.</li>
          <li>Gruppen und Gesuche sollen ernst gemeint und aktuell sein.</li>
        </ul>
        <h2>4. Sicher treffen</h2>
        <ul>
          <li>Triff dich beim ersten Mal an einem öffentlichen Ort.</li>
          <li>Sag jemandem Bescheid, wo und mit wem du unterwegs bist.</li>
          <li>Teile private Daten (Adresse, Telefonnummer) erst, wenn du der Person vertraust.</li>
          <li>Du nimmst an Treffen und Sport auf eigene Verantwortung teil.</li>
        </ul>
        <h2>5. Melden und Blockieren</h2>
        <p>
          Jedes Gesuch, jede Nachricht, jede Gruppe und jedes Profil lässt sich melden. Gemeldete Inhalte siehst
          du sofort nicht mehr; wir prüfen Meldungen zeitnah, in der Regel innerhalb von 24 Stunden. Personen,
          mit denen du nichts zu tun haben möchtest, kannst du blockieren.
        </p>
        <h2>6. Was bei Verstößen passiert</h2>
        <p>
          Wir können Inhalte entfernen und Konten vorübergehend oder dauerhaft sperren. Grob beleidigende
          Ausdrücke werden bereits beim Absenden abgelehnt.
        </p>
        <h2>7. Dein Konto</h2>
        <p>
          Du kannst dein Konto jederzeit im Profil unter „Konto löschen“ selbst und vollständig löschen.
        </p>
        <h2>8. Kontakt</h2>
        <p v-if="operator.email">Fragen oder Hinweise: <a :href="`mailto:${operator.email}`">{{ operator.email }}</a></p>
        <p v-else>Fragen oder Hinweise kannst du über „Feedback geben“ im Profil senden.</p>
      </div>

      <!-- ===== Datenschutz ===== -->
      <div v-else-if="doc === 'datenschutz'" class="nx-prose">
        <h2>1. Verantwortlicher</h2>
        <p v-if="operatorComplete">
          {{ operator.name }}, {{ operator.street }}, {{ operator.city }}, {{ operator.country }} ·
          <a :href="`mailto:${operator.email}`">{{ operator.email }}</a>
        </p>
        <p v-else>[Name und Anschrift des Betreibers – noch einzutragen]</p>

        <h2>2. Welche Daten wir verarbeiten</h2>
        <ul>
          <li><b>Konto:</b> E-Mail-Adresse und Passwort (nur verschlüsselt gespeichert).</li>
          <li>
            <b>Profil:</b> Vorname, Geschlecht, Stadt, optional „Über mich“ und Lieblingssportarten. Für andere
            sichtbar sind nur Vorname, Stadt, „Über mich“ und Sportarten – nie E-Mail oder Geschlecht.
          </li>
          <li>
            <b>Standort:</b> Wir speichern nur die Koordinaten der von dir gewählten Stadt, niemals deinen
            genauen GPS-Standort. Auf der Karte werden Orte zusätzlich gerundet und verstreut angezeigt.
          </li>
          <li><b>Inhalte:</b> Gruppen, Gesuche, Nachrichten, Zusagen, Umfragen, Meldungen und Feedback.</li>
          <li><b>Technik:</b> Daten, die beim Aufruf anfallen (z. B. IP-Adresse, Zeitpunkt), bei unseren Dienstleistern.</li>
        </ul>

        <h2>3. Wofür und auf welcher Grundlage</h2>
        <ul>
          <li>Bereitstellung der App und ihrer Funktionen (Art. 6 Abs. 1 lit. b DSGVO).</li>
          <li>Sicherheit, Missbrauchsschutz und Moderation (Art. 6 Abs. 1 lit. f DSGVO).</li>
          <li>Push-Benachrichtigungen nur mit deiner Einwilligung (Art. 6 Abs. 1 lit. a DSGVO).</li>
        </ul>

        <h2>4. Dienstleister</h2>
        <ul>
          <li><b>Supabase</b> (Datenbank, Anmeldung, Echtzeit-Aktualisierung) – speichert alle App-Daten.</li>
          <li><b>OneSignal</b> (Push-Benachrichtigungen) – nur wenn du Benachrichtigungen aktivierst.</li>
          <li><b>Photon / OpenStreetMap</b> (Ortssuche) – erhält deine Sucheingabe für Orte.</li>
          <li><b>CARTO</b> (Kartenbilder) – erhält technisch bedingt deine IP-Adresse beim Laden der Karte.</li>
          <li><b>Google Maps</b> – nur wenn du selbst auf „Route in Google Maps“ tippst (externer Link).</li>
        </ul>
        <p>Schriften und Symbole werden mit der App ausgeliefert und nicht von Dritten nachgeladen.</p>

        <h2>5. Speicherung auf deinem Gerät</h2>
        <p>
          Wir verwenden keine Werbe- oder Analyse-Cookies. Auf deinem Gerät werden nur technisch notwendige
          Daten gespeichert (Anmeldung, Darstellung hell/dunkel, zuletzt gewählte Ansicht).
        </p>

        <h2>6. Speicherdauer</h2>
        <p>
          Deine Daten bleiben gespeichert, solange dein Konto besteht. Gesuche laufen automatisch ab. Löschst du
          dein Konto, werden Profil, Mitgliedschaften, Gesuche, Nachrichten, Zusagen und Meldungen gelöscht.
        </p>

        <h2>7. Deine Rechte</h2>
        <p>
          Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit und
          Widerspruch sowie das Recht, dich bei einer Datenschutz-Aufsichtsbehörde zu beschweren. Dein Konto
          kannst du jederzeit selbst im Profil löschen.
        </p>
      </div>

      <!-- ===== Impressum ===== -->
      <div v-else class="nx-prose">
        <h2>Angaben gemäß § 5 DDG</h2>
        <p v-if="operatorComplete">
          {{ operator.name }}<br />{{ operator.street }}<br />{{ operator.city }}<br />{{ operator.country }}
        </p>
        <p v-else>[Name und Anschrift des Betreibers – noch einzutragen]</p>
        <h2>Kontakt</h2>
        <p v-if="operator.email">
          E-Mail: <a :href="`mailto:${operator.email}`">{{ operator.email }}</a>
          <template v-if="operator.phone"><br />Telefon: {{ operator.phone }}</template>
        </p>
        <p v-else>[E-Mail-Adresse – noch einzutragen]</p>
        <h2>Verantwortlich für den Inhalt</h2>
        <p>{{ operator.name || '[Name – noch einzutragen]' }}</p>
        <h2>Haftung für Inhalte von Nutzern</h2>
        <p>
          Gruppen, Gesuche und Nachrichten stammen von den Nutzerinnen und Nutzern. Rechtswidrige Inhalte können
          direkt in der App gemeldet werden; wir entfernen sie nach Kenntnis umgehend.
        </p>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { MIN_AGE, legalTitles, legalVersion, operator, operatorComplete, type LegalDoc } from '@/data/legal';

const route = useRoute();
const router = useRouter();

const doc = computed<LegalDoc>(() => {
  const d = route.params.doc;
  return d === 'datenschutz' || d === 'impressum' ? d : 'regeln';
});

function goBack() {
  if (window.history.length > 1) router.back();
  else void router.push('/');
}
</script>
