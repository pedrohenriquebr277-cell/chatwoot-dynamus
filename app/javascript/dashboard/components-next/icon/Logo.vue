<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');

const defaultLogo = '/brand-assets/logo-thumbnail.png';
</script>

<template>
  <img
    v-bind="attrs"
    :src="globalConfig.logoThumbnail || defaultLogo"
  />
</template>