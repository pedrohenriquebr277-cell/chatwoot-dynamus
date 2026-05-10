<script>
import {
  dateFormat,
  formatConversationDate,
} from 'shared/helpers/timeHelper';

export default {
  name: 'TimeAgo',
  props: {
    isAutoRefreshEnabled: {
      type: Boolean,
      default: true,
    },
    lastActivityTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    createdAtTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    conversationId: {
      type: [String, Number],
      default: '',
    },
  },
  computed: {
    lastActivityTime() {
      return formatConversationDate(this.lastActivityTimestamp);
    },
    createdAt() {
      return `${this.$t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.LATEST')} ${dateFormat(
        this.createdAtTimestamp,
        'dd/MM/yyyy HH:mm'
      )}`;
    },
    lastActivity() {
      return `${this.$t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.ACTIVE')} ${dateFormat(
        this.lastActivityTimestamp,
        'dd/MM/yyyy HH:mm'
      )}`;
    },
    tooltipText() {
      return `${this.createdAt}\n${this.lastActivity}`;
    },
  },
};
</script>

<template>
  <div
    v-tooltip.top="{
      content: tooltipText,
      delay: { show: 1000, hide: 0 },
    }"
    class="ml-auto leading-4 text-xxs text-n-slate-10 hover:text-n-slate-11"
  >
    <span>{{ lastActivityTime }}</span>
  </div>
</template>
