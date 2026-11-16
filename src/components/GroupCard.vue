<template>
  <!-- Gruppe als Karte: neutrale Gemeinschaft, darunter (fuer Mitglieder) das naechste Event -->
  <q-card v-ripple class="nx-gcard cursor-pointer" @click="router.push(target)">
    <div class="nx-gcard__cover" :style="{ background: cover }">
      <div class="nx-gcard__emoji">{{ emoji }}</div>
      <div class="nx-gcard__tags">
        <span v-if="group.next_event_at" class="nx-tag">{{ formatMeetup(group.next_event_at) }}</span>
        <span v-if="distance" class="nx-tag">{{ distance }}</span>
      </div>
      <div class="nx-gcard__free">
        {{ group.member_count }} {{ group.member_count === 1 ? 'Mitglied' : 'Mitglieder' }}
      </div>
    </div>
    <div class="q-pa-md">
      <div class="nx-display ellipsis" style="font-size: 15px">{{ group.name }}</div>
      <div class="text-caption text-grey ellipsis">
        <template v-if="group.next_event_title">Nächstes Event: {{ group.next_event_title }}</template>
        <template v-else-if="group.description">{{ group.description }}</template>
        <template v-else>{{ group.city ?? 'Gruppe' }}</template>
      </div>
      <div class="row items-center no-wrap q-mt-sm">
        <div class="col text-caption text-grey ellipsis">
          <template v-if="group.my_status">
            {{ group.events_upcoming === 0 ? 'Kein Event geplant' : group.events_upcoming === 1 ? '1 Event geplant' : `${group.events_upcoming} Events geplant` }}
          </template>
          <template v-else-if="group.city"><q-icon name="place" size="14px" /> {{ group.city }}</template>
        </div>
        <q-btn
          v-if="!group.my_status"
          class="q-ml-md"
          color="primary"
          unelevated
          dense
          padding="6px 14px"
          label="Mitmachen"
          @click.stop="router.push(target)"
        />
        <q-badge v-else class="q-ml-md" color="positive" label="Mitglied ✓" />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { getSport, sportGradient } from '@/data/sports';
import { avatarHue } from '@/utils/avatar';
import { formatDistanceShort, formatMeetup } from '@/utils/format';
import type { DiscoverGroup } from '@/types/group';

const props = defineProps<{ group: DiscoverGroup }>();
const router = useRouter();

const distance = computed(() => formatDistanceShort(props.group.distance_m));
// Mit kommendem Event: dessen Sportart. Sonst eine feste Farbe pro Gruppe.
const emoji = computed(() => (props.group.next_event_sport ? getSport(props.group.next_event_sport).emoji : '👥'));
const cover = computed(() => {
  if (props.group.next_event_sport) return sportGradient(props.group.next_event_sport);
  const hue = avatarHue(props.group.id);
  return `linear-gradient(135deg, hsl(${hue} 55% 52%) 0%, hsl(${(hue + 40) % 360} 55% 22%) 100%)`;
});
// Mitglieder landen direkt in der Gruppe, alle anderen auf der Beitrittsseite.
const target = computed(() =>
  props.group.my_status ? `/groups/${props.group.id}` : `/groups/join/${props.group.id}`,
);
</script>

<style scoped>
.nx-gcard {
  overflow: hidden;
  border-radius: 22px;
  transition: border-color 0.15s, transform 0.15s;
}
.nx-gcard:hover {
  border-color: var(--nx-accent);
}
.nx-gcard__cover {
  position: relative;
  height: 140px;
  overflow: hidden;
}
.nx-gcard__emoji {
  position: absolute;
  right: 12px;
  bottom: -14px;
  font-size: 96px;
  line-height: 1;
  filter: drop-shadow(0 6px 16px rgba(0, 0, 0, 0.35));
}
.nx-gcard__tags {
  position: absolute;
  left: 12px;
  top: 12px;
  display: flex;
  gap: 6px;
}
.nx-gcard__free {
  position: absolute;
  left: 12px;
  bottom: 12px;
  background: var(--nx-cream);
  color: var(--nx-ink);
  font-weight: 800;
  font-size: 12px;
  padding: 4px 10px;
  border-radius: 999px;
}
</style>
