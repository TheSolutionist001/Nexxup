<template>
  <!-- Ein Event in einer Liste: Datum, Titel, Belegung und mein Status -->
  <q-card v-ripple class="nx-ecard cursor-pointer" @click="router.push(`/events/${event.id}`)">
    <div class="row items-center no-wrap q-pa-sm" style="gap: 12px">
      <div class="nx-ecard__date" :style="{ background: sportGradient(event.sport) }">
        <div class="nx-ecard__wd">{{ day.weekday }}</div>
        <div class="nx-ecard__d">{{ day.day }}</div>
      </div>
      <div class="col" style="min-width: 0">
        <div class="text-weight-bold ellipsis">{{ sport.emoji }} {{ event.title }}</div>
        <div class="text-caption text-grey ellipsis">
          {{ formatMeetup(event.starts_at) }}
          <template v-if="showGroup && event.group_name"> · {{ event.group_name }}</template>
          <template v-else-if="event.place_name"> · {{ event.place_name }}</template>
        </div>
        <div class="text-caption q-mt-xs row items-center" style="gap: 6px">
          <span>{{ occupancyLabel(event.max_participants, event.going_count, event.waitlist_count) }}</span>
          <span v-if="event.fee_cents" class="text-grey">· {{ formatEuro(event.fee_cents) }}</span>
          <q-icon v-if="event.repeat_weeks" name="repeat" size="14px" class="text-grey" />
        </div>
      </div>
      <q-badge v-if="badge" :color="badge.color" :label="badge.label" class="nx-ecard__badge" />
      <q-icon v-else name="chevron_right" size="22px" class="text-grey" />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { getSport, sportGradient } from '@/data/sports';
import { formatMeetup, meetupDayParts } from '@/utils/format';
import { formatEuro } from '@/utils/money';
import { occupancyLabel } from '@/utils/events';
import type { GroupEvent } from '@/types/event';

const props = defineProps<{ event: GroupEvent; showGroup?: boolean }>();
const router = useRouter();

const sport = computed(() => getSport(props.event.sport));
const day = computed(() => meetupDayParts(props.event.starts_at));
const badge = computed(() => {
  switch (props.event.my_status) {
    case 'going':
      return { color: 'positive', label: 'Dabei ✓' };
    case 'offered':
      return { color: 'primary', label: 'Platz frei!' };
    case 'waitlist':
      return { color: 'warning', label: 'Warteliste' };
    default:
      return null;
  }
});
</script>

<style scoped>
.nx-ecard {
  border-radius: 18px;
}
.nx-ecard__date {
  width: 52px;
  height: 56px;
  border-radius: 14px;
  text-align: center;
  padding-top: 7px;
  flex-shrink: 0;
  color: #fff;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.45);
}
.nx-ecard__wd {
  font-size: 11px;
  font-weight: 700;
}
.nx-ecard__d {
  font-family: 'Unbounded Variable', sans-serif;
  font-size: 20px;
  font-weight: 700;
  line-height: 1.1;
}
.nx-ecard__badge {
  flex-shrink: 0;
}
</style>
