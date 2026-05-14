<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@chatwoot/utils';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { createContactSearcher } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';

import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import ContactAPI from 'dashboard/api/contacts';

const store = useStore();
const { t } = useI18n();
const searchContacts = createContactSearcher();

const { uiSettings, updateUISettings } = useUISettings();
const currentUser = useMapGetter('getCurrentUser');

const show = ref(false);
const messagePayload = ref(null);
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const selectedContactIds = ref([]);
const isSending = ref(false);

const supportedAttachments = ref([]);
const unsupportedAttachmentsCount = ref(0);

const LOCAL_STORAGE_PINNED_KEY = 'chatwoot_pinned_forward_contacts';

const pinnedContactIds = computed(() => {
  // 1. Try from UI settings
  if (uiSettings.value?.pinned_forward_contact_ids) {
    return uiSettings.value.pinned_forward_contact_ids;
  }
  // 2. Fallback to local storage
  try {
    const local = localStorage.getItem(LOCAL_STORAGE_PINNED_KEY);
    return local ? JSON.parse(local) : [];
  } catch (e) {
    return [];
  }
});

const pinnedContactsCache = ref({}); // Keep details of pinned contacts to show them when search is empty

const updatePinnedContacts = async (newIds) => {
  try {
    await updateUISettings({
      pinned_forward_contact_ids: newIds,
    });
  } catch (error) {
    // Fallback to local storage if API fails
    localStorage.setItem(LOCAL_STORAGE_PINNED_KEY, JSON.stringify(newIds));
  }
};

const togglePin = async (contact) => {
  const isPinned = pinnedContactIds.value.includes(contact.id);
  let newIds = [...pinnedContactIds.value];
  
  if (isPinned) {
    newIds = newIds.filter(id => id !== contact.id);
  } else {
    newIds.push(contact.id);
    pinnedContactsCache.value[contact.id] = contact;
  }
  
  await updatePinnedContacts(newIds);
};

const isPinned = (contactId) => pinnedContactIds.value.includes(contactId);

const onSearch = debounce(async (query) => {
  searchQuery.value = query;
  if (!query) {
    searchResults.value = [];
    isSearching.value = false;
    return;
  }
  
  isSearching.value = true;
  try {
    const results = await searchContacts(query);
    if (results === null) return; // aborted
    
    // Cache results so we have their details if they get pinned
    results.forEach(c => {
      if (isPinned(c.id)) {
        pinnedContactsCache.value[c.id] = c;
      }
    });
    
    searchResults.value = results;
  } catch (error) {
    useAlert(t('COMPOSE_NEW_CONVERSATION.CONTACT_SEARCH.ERROR_MESSAGE'));
  } finally {
    isSearching.value = false;
  }
}, 400, false);

const displayContacts = computed(() => {
  if (searchQuery.value) {
    // Show search results, but sort pinned ones to the top
    return [...searchResults.value].sort((a, b) => {
      const aPinned = isPinned(a.id);
      const bPinned = isPinned(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });
  }
  
  // Empty search: show pinned contacts + pre-selected contact if not pinned
  const contactsToShow = new Map();
  
  pinnedContactIds.value.forEach(id => {
    if (pinnedContactsCache.value[id]) {
      contactsToShow.set(id, pinnedContactsCache.value[id]);
    }
  });

  selectedContactIds.value.forEach(id => {
    if (!contactsToShow.has(id) && pinnedContactsCache.value[id]) {
      contactsToShow.set(id, pinnedContactsCache.value[id]);
    }
  });

  return Array.from(contactsToShow.values());
});

const toggleSelection = (contactId) => {
  const index = selectedContactIds.value.indexOf(contactId);
  if (index === -1) {
    selectedContactIds.value.push(contactId);
  } else {
    selectedContactIds.value.splice(index, 1);
  }
};

const isSelected = (contactId) => selectedContactIds.value.includes(contactId);

const handleOpen = (message) => {
  messagePayload.value = message;
  show.value = true;
  searchQuery.value = '';
  searchResults.value = [];
  selectedContactIds.value = [];
  isSending.value = false;
  supportedAttachments.value = [];
  unsupportedAttachmentsCount.value = 0;

  if (message.contact_id) {
    selectedContactIds.value.push(message.contact_id);
    // If current contact is not in pinned or cache, we should fetch it so it displays correctly
    if (!pinnedContactsCache.value[message.contact_id]) {
      ContactAPI.show(message.contact_id).then(response => {
        if (response.data?.payload) {
          pinnedContactsCache.value[message.contact_id] = response.data.payload;
          // Temporarily add to pinned display so it shows up before search
          if (!pinnedContactIds.value.includes(message.contact_id)) {
            // We just add it to cache, the computed property `displayContacts` won't show it 
            // unless it's pinned or searched. Let's fix that.
          }
        }
      }).catch(() => {});
    }
  }

  if (message.attachments && message.attachments.length > 0) {
    message.attachments.forEach(att => {
      // file_type may come as snake_case or camelCase
      const type = att.file_type || att.fileType;
      if (type === 'image' || type === 'audio') {
        supportedAttachments.value.push(att);
      } else {
        unsupportedAttachmentsCount.value++;
      }
    });
  }

  // Pre-fetch pinned contacts if they are missing from cache
  pinnedContactIds.value.forEach(async (id) => {
    if (!pinnedContactsCache.value[id]) {
      try {
        const response = await ContactAPI.show(id);
        if (response.data?.payload) {
          pinnedContactsCache.value[id] = response.data.payload;
        }
      } catch (e) {
        // ignore
      }
    }
  });
};

const handleClose = () => {
  show.value = false;
  messagePayload.value = null;
};

const getInboxForContact = async (contactId) => {
  // Minimal logic to get an inbox for a contact.
  // Reusing fetchContactableInboxes logic from helper.
  try {
    const { data: { payload: inboxes = [] } } = await store.$api.contacts.getContactableInboxes(contactId);
    
    if (inboxes && inboxes.length > 0) {
      // Prioritize current message's inbox
      const currentInboxId = messagePayload.value?.inbox_id || messagePayload.value?.inboxId;
      if (currentInboxId) {
        const matchingInbox = inboxes.find(i => i.inbox.id === currentInboxId);
        if (matchingInbox) {
          return {
            inboxId: matchingInbox.inbox.id,
            sourceId: matchingInbox.source_id
          };
        }
      }

      return {
        inboxId: inboxes[0].inbox.id,
        sourceId: inboxes[0].source_id
      };
    }
  } catch (e) {
    // ignore
  }
  return null;
};

const hasValidContent = computed(() => {
  const content = messagePayload.value?.content;
  return (content && content.trim() !== '') || supportedAttachments.value.length > 0;
});

const handleConfirm = async () => {
  if (!hasValidContent.value) {
    useAlert('Não há conteúdo válido suportado para encaminhar.');
    return;
  }
  
  if (selectedContactIds.value.length === 0) {
    useAlert('Selecione pelo menos um contato para encaminhar.');
    return;
  }

  isSending.value = true;
  
  const filesToUpload = [];
  if (supportedAttachments.value.length > 0) {
    try {
      for (const att of supportedAttachments.value) {
        const url = att.data_url || att.dataUrl;
        if (!url) continue;
        
        const response = await fetch(url);
        if (!response.ok) throw new Error('Network response was not ok');
        const blob = await response.blob();
        
        // Try to get filename from URL or default
        const urlParts = url.split('/');
        let filename = urlParts[urlParts.length - 1].split('?')[0] || 'attachment';
        if (!filename.includes('.')) {
          const ext = att.extension ? `.${att.extension}` : '';
          filename = `${filename}${ext}`;
        }
        
        filesToUpload.push(new File([blob], filename, { type: blob.type }));
      }
    } catch (e) {
      useAlert('Não foi possível baixar os anexos para encaminhamento. Tente novamente.');
      isSending.value = false;
      return;
    }
  }

  let successCount = 0;
  let failCount = 0;

  for (const contactId of selectedContactIds.value) {
    try {
      const targetInbox = await getInboxForContact(contactId);
      if (!targetInbox) {
        throw new Error('No inbox found');
      }

      const payload = {
        inboxId: targetInbox.inboxId,
        sourceId: targetInbox.sourceId,
        contactId: contactId,
        message: { content: messagePayload.value?.content || '' },
        assigneeId: currentUser.value.id,
      };

      await store.dispatch('contactConversations/create', {
        params: { ...payload, files: filesToUpload },
        isFromWhatsApp: false, // Simplification
      });
      successCount++;
    } catch (e) {
      failCount++;
    }
  }

  isSending.value = false;
  
  if (failCount === 0) {
    useAlert(`Mensagem encaminhada com sucesso para ${successCount} contato(s).`);
  } else {
    useAlert(`Encaminhamento concluído: ${successCount} sucessos, ${failCount} falhas.`);
  }
  
  handleClose();
};

onMounted(() => {
  emitter.on(BUS_EVENTS.SHOW_FORWARD_MESSAGE_MODAL, handleOpen);
});

onUnmounted(() => {
  emitter.off(BUS_EVENTS.SHOW_FORWARD_MESSAGE_MODAL, handleOpen);
});
</script>

<template>
  <Modal v-if="show" v-model:show="show" :on-close="handleClose">
    <div class="flex flex-col h-[35rem] max-h-[90vh]">
      <woot-modal-header
        header-title="Encaminhar Mensagem"
        header-content="Selecione os contatos para quem deseja enviar esta mensagem."
      />

      <div class="p-4 flex-1 overflow-hidden flex flex-col">
        <div v-if="unsupportedAttachmentsCount > 0" class="mb-4 p-3 bg-y-50 border border-y-200 text-y-800 rounded-lg text-sm">
          <span class="i-lucide-alert-triangle mr-1 align-text-bottom text-y-600"></span>
          Esta mensagem contém anexos que não são suportados para encaminhamento no momento. 
          Apenas texto, imagens e áudios serão enviados.
        </div>
        
        <!-- Search -->
        <div class="mb-4 relative">
          <input
            type="text"
            class="w-full border border-n-strong rounded-lg p-2 pl-8 focus:outline-none focus:border-n-brand"
            placeholder="Buscar por nome ou número..."
            :value="searchQuery"
            @input="e => onSearch(e.target.value)"
          />
          <span class="absolute left-3 top-2.5 text-n-slate-11 i-lucide-search" />
        </div>

        <div v-if="isSearching" class="text-center p-4 text-n-slate-11 text-sm">
          Buscando contatos...
        </div>

        <!-- Contact List -->
        <div class="flex-1 overflow-y-auto border border-n-strong rounded-lg">
          <div
            v-for="contact in displayContacts"
            :key="contact.id"
            class="flex items-center justify-between p-3 border-b border-n-weak hover:bg-n-alpha-1 cursor-pointer"
            @click="toggleSelection(contact.id)"
          >
            <div class="flex items-center gap-3">
              <input
                type="checkbox"
                :checked="isSelected(contact.id)"
                class="w-4 h-4 cursor-pointer"
                @click.stop="toggleSelection(contact.id)"
              />
              <Avatar
                :name="contact.name || 'Desconhecido'"
                :src="contact.thumbnail || contact.avatarUrl"
                :size="32"
              />
              <div class="flex flex-col">
                <span class="font-medium text-sm text-n-slate-12">
                  {{ contact.name || 'Desconhecido' }}
                </span>
                <span v-if="contact.phoneNumber || contact.email" class="text-xs text-n-slate-11">
                  {{ contact.phoneNumber || contact.email }}
                </span>
              </div>
            </div>
            
            <button
              class="p-2 rounded-md hover:bg-n-alpha-2 transition-colors"
              title="Fixar/Desfixar Contato"
              @click.stop="togglePin(contact)"
            >
              <span
                class="i-lucide-pin"
                :class="isPinned(contact.id) ? 'text-n-brand' : 'text-n-slate-11'"
              />
            </button>
          </div>
          
          <div v-if="!isSearching && displayContacts.length === 0" class="p-8 text-center text-n-slate-11 text-sm">
            Nenhum contato encontrado ou fixado.
          </div>
        </div>

        <!-- Selected Count -->
        <div class="mt-3 text-sm text-n-slate-11">
          {{ selectedContactIds.length }} contato(s) selecionado(s)
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 p-4 border-t border-n-strong">
        <NextButton
          faded
          slate
          :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="handleClose"
        />
        <NextButton
          :label="isSending ? 'Enviando...' : 'Encaminhar'"
          :disabled="!hasValidContent || selectedContactIds.length === 0 || isSending"
          :is-loading="isSending"
          @click="handleConfirm"
        />
      </div>
    </div>
  </Modal>
</template>
