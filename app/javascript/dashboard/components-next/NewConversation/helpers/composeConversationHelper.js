import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import camelcaseKeys from 'camelcase-keys';
import ContactAPI from 'dashboard/api/contacts';

const CHANNEL_PRIORITY = {
  'Channel::Email': 1,
  'Channel::Whatsapp': 2,
  'Channel::Sms': 3,
  'Channel::TwilioSms': 4,
  'Channel::WebWidget': 5,
  'Channel::Api': 6,
};

export const generateLabelForContactableInboxesList = ({
  name,
  email,
  channelType,
  phoneNumber,
}) => {
  if (channelType === INBOX_TYPES.EMAIL) {
    return `${name} (${email})`;
  }
  if (
    channelType === INBOX_TYPES.TWILIO ||
    channelType === INBOX_TYPES.WHATSAPP
  ) {
    return phoneNumber ? `${name} (${phoneNumber})` : name;
  }
  return name;
};

const transformInbox = ({
  name,
  id,
  email,
  channelType,
  phoneNumber,
  medium,
  ...rest
}) => ({
  id,
  icon: getInboxIconByType(channelType, medium, 'line'),
  label: generateLabelForContactableInboxesList({
    name,
    email,
    channelType,
    phoneNumber,
  }),
  action: 'inbox',
  value: id,
  name,
  email,
  phoneNumber,
  channelType,
  medium,
  ...rest,
});

export const compareInboxes = (a, b) => {
  // Channels that have no priority defined should come at the end.
  const priorityA = CHANNEL_PRIORITY[a.channelType] || 999;
  const priorityB = CHANNEL_PRIORITY[b.channelType] || 999;

  if (priorityA !== priorityB) {
    return priorityA - priorityB;
  }

  const nameA = a.name || '';
  const nameB = b.name || '';
  return nameA.localeCompare(nameB);
};

export const buildContactableInboxesList = contactInboxes => {
  if (!contactInboxes) return [];

  return contactInboxes.map(transformInbox).sort(compareInboxes);
};

export const getCapitalizedNameFromEmail = email => {
  const name = email.match(/^([^@]*)@/)?.[1] || email.split('@')[0];
  return name.charAt(0).toUpperCase() + name.slice(1);
};

export const processContactableInboxes = inboxes => {
  return inboxes.map(inbox => ({
    ...inbox.inbox,
    sourceId: inbox.sourceId,
  }));
};

export const mergeInboxDetails = (inboxesData, inboxesList = []) => {
  if (!inboxesData || !inboxesData.length) {
    return [];
  }

  return inboxesData.map(inboxData => {
    const matchingInbox =
      inboxesList.find(inbox => inbox.id === inboxData.id) || {};
    return {
      ...camelcaseKeys(matchingInbox, { deep: true }),
      ...inboxData,
    };
  });
};

export const prepareAttachmentPayload = (
  attachedFiles,
  directUploadsEnabled
) => {
  const files = [];
  attachedFiles.forEach(attachment => {
    if (directUploadsEnabled) {
      files.push(attachment.blobSignedId);
    } else {
      files.push(attachment.resource.file);
    }
  });
  return files;
};

export const prepareNewMessagePayload = ({
  targetInbox,
  selectedContact,
  message,
  subject,
  ccEmails,
  bccEmails,
  currentUser,
  attachedFiles = [],
  directUploadsEnabled = false,
}) => {
  const payload = {
    inboxId: targetInbox.id,
    sourceId: targetInbox.sourceId,
    contactId: Number(selectedContact.id),
    message: { content: message },
    assigneeId: currentUser.id,
  };

  if (attachedFiles?.length) {
    payload.files = prepareAttachmentPayload(
      attachedFiles,
      directUploadsEnabled
    );
  }

  if (subject) {
    payload.mailSubject = subject;
  }

  if (ccEmails) {
    payload.message.cc_emails = ccEmails;
  }

  if (bccEmails) {
    payload.message.bcc_emails = bccEmails;
  }

  return payload;
};

export const prepareWhatsAppMessagePayload = ({
  targetInbox,
  selectedContact,
  message,
  templateParams,
  currentUser,
}) => {
  return {
    inboxId: targetInbox.id,
    sourceId: targetInbox.sourceId,
    contactId: selectedContact.id,
    message: { content: message, template_params: templateParams },
    assigneeId: currentUser.id,
  };
};

// API Calls
const MIN_SEARCH_LENGTH = 2;

export const createContactSearcher = () => {
  let controller = null;

  return async (query, { skipMinLength = false } = {}) => {
    const trimmed = typeof query === 'string' ? query.trim() : '';

    controller?.abort();

    if (!trimmed || (!skipMinLength && trimmed.length < MIN_SEARCH_LENGTH))
      return [];

    controller = new AbortController();
    const { signal } = controller;

    try {
      const {
        data: { payload },
      } = await ContactAPI.search(trimmed, 1, 'name', '', { signal });

      const camelCasedPayload = camelcaseKeys(payload, { deep: true });
      // Filter contacts that have either phone_number or email
      const filteredPayload = camelCasedPayload?.filter(
        contact => contact.phoneNumber || contact.email
      );
      return filteredPayload || [];
    } catch (error) {
      // Return null for aborted requests so callers can distinguish
      // "request was cancelled" from "no results found"
      if (error?.name === 'AbortError' || error?.name === 'CanceledError') {
        return null;
      }
      throw error;
    }
  };
};

// Detects phone numbers in formats like: +55 (41) 98864-7010, 5541988647010,
// (41) 98864-7010, 41 9 8864-7010, 55-41-98864-7010, etc.
const PHONE_NUMBER_REGEX = /^[+]?[\d\s\-(). ]{7,20}$/;

const sanitizePhoneNumber = raw => {
  // Remove tudo que não é número
  let digits = raw.replace(/\D/g, '');
  
  // Se o operador digitou apenas DDD + Número (10 ou 11 dígitos), injeta o DDI do Brasil (55)
  if (digits.length === 10 || digits.length === 11) {
    digits = '55' + digits;
  }
  
  // Força o '+' obrigatório do padrão E.164 exigido pelo Chatwoot e Evolution
  return `+${digits}`;
};
export const createNewContact = async input => {
  const trimmed = input.trim();
  const isPhone = PHONE_NUMBER_REGEX.test(trimmed);

  let payload;
  if (isPhone) {
    const sanitized = sanitizePhoneNumber(trimmed);
    payload = {
      name: sanitized,
      phone_number: sanitized,
    };
  } else {
    payload = {
      name: getCapitalizedNameFromEmail(trimmed),
      email: trimmed,
    };
  }

  const {
    data: {
      payload: { contact: newContact },
    },
  } = await ContactAPI.create(payload);

  return camelcaseKeys(newContact, { deep: true });
};

export const fetchContactableInboxes = async contactId => {
  const {
    data: { payload: inboxes = [] },
  } = await ContactAPI.getContactableInboxes(contactId);

  const convertInboxesToCamelKeys = camelcaseKeys(inboxes, { deep: true });

  return processContactableInboxes(convertInboxesToCamelKeys);
};
