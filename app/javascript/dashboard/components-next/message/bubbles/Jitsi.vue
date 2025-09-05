<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

const { content, sender, contentAttributes } = useMessageContext();

const { t } = useI18n();

const meetingUrl = computed(() => {
  return (
    contentAttributes.value?.data?.meeting_url ||
    contentAttributes.value?.data?.url ||
    ''
  );
});

const meetingTitle = computed(() => {
  return contentAttributes.value?.data?.meeting_title || 'Connect AI Meeting';
});

const roomName = computed(() => {
  return contentAttributes.value?.data?.room_name || '';
});

const action = computed(() => ({
  label: t('INTEGRATION_SETTINGS.JITSI.CLICK_HERE_TO_JOIN'),
  onClick: () => {
    if (meetingUrl.value) {
      window.open(meetingUrl.value, '_blank');
    }
  },
}));
</script>

<template>
  <BaseAttachmentBubble
    icon="i-ph-video-camera-fill"
    icon-bg-color="bg-[#1976D2]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.MEETING"
    :action="action"
  >
    <div class="text-sm">
      <div class="font-medium text-n-slate-12 mb-1">
        {{ meetingTitle }}
      </div>
      <div v-if="roomName" class="text-xs text-n-slate-10 mb-2">
        {{ $t('INTEGRATION_SETTINGS.JITSI.ROOM_NAME', { room: roomName }) }}
      </div>
      <div v-if="!sender" class="text-sm truncate text-n-slate-12">
        <!-- Added as a fallback, where the sender is not available (Deleted) -->
        <!-- Will show the content, if senderName in BaseAttachment.vue is empty -->
        {{ content }}
      </div>
    </div>
  </BaseAttachmentBubble>
</template>
