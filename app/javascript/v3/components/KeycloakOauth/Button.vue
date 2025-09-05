<script>
import SimpleDivider from '../Divider/SimpleDivider.vue';

export default {
  components: {
    SimpleDivider,
  },
  props: {
    showSeparator: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    loginText() {
      return this.$t('LOGIN.OAUTH.KEYCLOAK_LOGIN') || 'Login with AUTH Shield';
    },
  },
  methods: {
    getKeycloakAuthUrl() {
      // Direct link to Keycloak OAuth endpoint
      return '/auth/keycloak';
    },
  },
};
</script>

<template>
  <div class="flex flex-col">
    <a
      :href="getKeycloakAuthUrl()"
      class="inline-flex justify-center w-full px-4 py-3 bg-n-background dark:bg-n-solid-3 rounded-md shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2"
    >
      <span class="i-mdi-shield-lock h-6 w-6 text-blue-600" />
      <span class="ml-2 text-base font-medium text-n-slate-12">
        {{ loginText }}
      </span>
    </a>
    <SimpleDivider
      v-if="showSeparator"
      :label="$t('COMMON.OR')"
      class="uppercase"
    />
  </div>
</template>
