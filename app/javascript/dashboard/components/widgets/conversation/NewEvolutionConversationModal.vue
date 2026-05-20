<script setup>
import { ref, computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import useVuelidate from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import NextButton from 'dashboard/components-next/button/Button.vue';
import evolutionAPI from 'dashboard/api/evolution';

const emit = defineEmits(['close']);
const getters = useStoreGetters();
const router = useRouter();

const inboxes = computed(() => getters['inboxes/getInboxes'].value);
const apiInboxes = computed(() => 
  inboxes.value.filter(inbox => inbox.channel_type === 'Channel::Api')
);

const state = ref({
  inboxId: '',
  name: '',
  phoneNumber: '',
  message: '',
});

const isSubmitting = ref(false);

const rules = {
  inboxId: { required },
  phoneNumber: { required, minLength: minLength(10) },
  message: { required },
};

const v$ = useVuelidate(rules, state);

const onClose = () => {
  emit('close');
};

const submit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  
  isSubmitting.value = true;
  
  try {
    const response = await evolutionAPI.create({
      inbox_id: state.value.inboxId,
      name: state.value.name,
      phone_number: state.value.phoneNumber,
      message: state.value.message,
    });
    
    const data = response.data;
    
    // Se a conversa foi criada instantaneamente (sem depender do webhook)
    if (data.conversation_id) {
      useAlert('Conversa iniciada com sucesso!');
      onClose();
      router.push({ name: 'inbox_conversation', params: { inbox_id: state.value.inboxId, conversation_id: data.conversation_id } });
    } else {
      // Se caiu na fila de webhook (sent_waiting_sync)
      useAlert('Mensagem enviada! A conversa aparecerá na sua fila assim que a rede confirmar.');
      onClose();
    }
  } catch (error) {
    // Agora o erro real disparado pelo backend (EvolutionApiError) será exibido aqui
    const errorMessage = error?.response?.data?.error || 'Erro ao iniciar conversa.';
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      header-title="Iniciar conversa com novo número"
      header-content="Envie a primeira mensagem para um número de WhatsApp via Evolution API"
    />
    <form class="flex flex-col gap-4 p-6 pt-0 mx-0" @submit.prevent="submit">
      <label class="w-full">
        Canal / Inbox *
        <select v-model="state.inboxId" class="w-full border-n-weak rounded-md mt-1" :class="{ 'border-n-ruby-9': v$.inboxId.$error }">
          <option value="" disabled>Selecione um canal</option>
          <option v-for="inbox in apiInboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </select>
        <span v-if="v$.inboxId.$error" class="text-n-ruby-9 text-xs">Selecione uma caixa de entrada</span>
      </label>

      <woot-input
        v-model="state.phoneNumber"
        :class="{ error: v$.phoneNumber.$error }"
        class="w-full mb-0"
        label="Número do WhatsApp *"
        placeholder="Ex: 5511999999999"
        @input="v$.phoneNumber.$touch"
        @blur="v$.phoneNumber.$touch"
      />
      <span v-if="v$.phoneNumber.$error" class="text-n-ruby-9 text-xs mt-[-10px]">Informe um número válido (mín. 10 dígitos)</span>

      <woot-input
        v-model="state.name"
        class="w-full mb-0"
        label="Nome do Contato (Opcional)"
        placeholder="Nome do cliente"
      />

      <label class="w-full">
        Mensagem Inicial *
        <textarea
          v-model="state.message"
          class="w-full border-n-weak rounded-md mt-1 h-24 p-2"
          :class="{ 'border-n-ruby-9': v$.message.$error }"
          placeholder="Digite a primeira mensagem que será enviada..."
          @input="v$.message.$touch"
          @blur="v$.message.$touch"
        />
        <span v-if="v$.message.$error" class="text-n-ruby-9 text-xs">A mensagem é obrigatória</span>
      </label>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2 mt-4">
        <NextButton
          faded
          slate
          type="reset"
          label="Cancelar"
          :disabled="isSubmitting"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          label="Enviar Mensagem"
          :disabled="v$.$invalid || isSubmitting"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>