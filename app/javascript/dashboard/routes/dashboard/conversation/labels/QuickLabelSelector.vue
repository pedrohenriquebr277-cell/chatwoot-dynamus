<script setup>
import { ref } from 'vue';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';

const { isAdmin } = useAdmin();
const {
  savedLabels,
  accountLabels,
  addLabelToConversation,
  removeLabelFromConversation,
} = useConversationLabels();

const showDropdown = ref(false);
const toggleDropdown = () => {
  showDropdown.value = !showDropdown.value;
};
const closeDropdown = () => {
  showDropdown.value = false;
};
</script>

<template>
  <div class="relative flex items-center h-full" v-on-clickaway="closeDropdown">
    <ButtonV4
      v-tooltip="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-tag"
      class="rounded-md"
      @click="toggleDropdown"
    />
    <div
      v-if="showDropdown"
      class="border rounded-lg bg-n-alpha-3 top-full mt-2 ltr:right-0 rtl:left-0 backdrop-blur-[100px] absolute w-[16rem] shadow-lg border-n-strong dark:border-n-strong p-2 box-border z-[9999]"
    >
      <LabelDropdown
        :account-labels="accountLabels"
        :selected-labels="savedLabels"
        :allow-creation="true"
        @add="addLabelToConversation"
        @remove="removeLabelFromConversation"
      />
    </div>
  </div>
</template>
