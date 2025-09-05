<script>
import { mapGetters } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import JitsiAPI from 'dashboard/api/integrations/jitsi';
import { useAlert } from 'dashboard/composables';

export default {
  name: 'JitsiCallButton',
  components: {
    NextButton,
  },
  props: {
    conversationId: {
      type: [String, Number],
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
    };
  },
  computed: {
    ...mapGetters({ appIntegrations: 'integrations/getAppIntegrations' }),
    isJitsiEnabled() {
      // Check if Connect AI (Jitsi) integration exists with hooks
      return this.appIntegrations.find(
        integration => integration.id === 'jitsi' && !!integration.hooks.length
      );
    },
    jitsiHelpText() {
      return 'Start a Connect AI video call';
    },
  },
  mounted() {
    // Load integrations if not already loaded
    if (!this.appIntegrations.length) {
      this.$store.dispatch('integrations/get');
    }
  },
  methods: {
    async startJitsiCall() {
      this.isLoading = true;
      try {
        await JitsiAPI.createAMeeting(this.conversationId);
      } catch (error) {
        useAlert('Failed to create Jitsi meeting. Please try again.');
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <NextButton
    v-if="isJitsiEnabled"
    v-tooltip.top-end="jitsiHelpText"
    icon="i-ph-video-camera"
    slate
    faded
    sm
    :loading="isLoading"
    @click="startJitsiCall"
  />
</template>
