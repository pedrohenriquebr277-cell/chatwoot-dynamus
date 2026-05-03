<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  // eslint-disable-next-line vue/no-unused-properties
  active: {
    type: Boolean,
    default: false,
  },
  inbox: {
    type: Object,
    required: true,
  },
});

const reauthorizationRequired = computed(() => {
  return props.inbox.reauthorization_required;
});

const parsedLabel = computed(() => {
  // Extract phone number from the end of the string if it exists
  const match = props.label.match(/^(.*?)(?:\s*[\/\-\(]\s*(\+?\d{10,15})\)?\s*)?$/);
  
  if (match && match[2]) {
    return {
      base: match[1].trim(),
      number: match[2]
    };
  }
  
  // Fallback to inbox.phone_number if the name doesn't contain it
  return {
    base: props.label.trim(),
    number: props.inbox.phone_number || null
  };
});

const evolutionStatus = computed(() => {
  return props.inbox.csat_config?.evolution_status;
});

const statusColor = computed(() => {
  if (evolutionStatus.value === 'connected') return 'bg-[#22c55e]'; // Green
  if (evolutionStatus.value === 'disconnected') return 'bg-[#ef4444]'; // Red
  if (evolutionStatus.value === 'qrcode') return 'bg-[#f59e0b]'; // Amber
  return null;
});

const statusTooltip = computed(() => {
  if (evolutionStatus.value === 'connected') return 'Conectado';
  if (evolutionStatus.value === 'disconnected') return 'Desconectado';
  if (evolutionStatus.value === 'qrcode') return 'Aguardando QR Code';
  return '';
});
</script>

<template>
  <div class="relative size-4 flex-shrink-0 grid place-content-center rounded-full">
    <ChannelIcon :inbox="inbox" class="size-4" />
    <span v-if="statusColor" 
          :class="['absolute -bottom-[2px] -right-[2px] size-2 rounded-full border border-n-background', statusColor]"
          v-tooltip.top-end="statusTooltip"
    ></span>
  </div>
  <div class="flex-1 flex flex-col justify-center min-w-0">
    <div class="truncate text-sm" :title="parsedLabel.base">{{ parsedLabel.base }}</div>
    <div v-if="parsedLabel.number" class="truncate text-[10px] text-n-slate-10 font-mono tracking-wide mt-0.5" :title="parsedLabel.number">
      {{ parsedLabel.number }}
    </div>
  </div>
  <div
    v-if="reauthorizationRequired"
    v-tooltip.top-end="$t('SIDEBAR.REAUTHORIZE')"
    class="flex-shrink-0 grid place-content-center size-5 bg-n-ruby-5/60 rounded-full ml-1"
  >
    <Icon icon="i-woot-alert" class="size-3 text-n-ruby-9" />
  </div>
</template>
