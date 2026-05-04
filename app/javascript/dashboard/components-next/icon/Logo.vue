<script setup>
import { useAttrs, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');

const defaultLogo = '/brand-assets/logo-thumbnail.png';
const logoUrl = computed(() => {
  const configLogo = globalConfig.value.logoThumbnail;
  if (!configLogo) {
    return defaultLogo;
  }
  return configLogo;
});
</script>

<template>
  <img
    v-bind="attrs"
    :src="logoUrl"
  />
</template>