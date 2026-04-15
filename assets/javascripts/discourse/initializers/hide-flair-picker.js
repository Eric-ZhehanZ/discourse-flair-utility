import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "hide-flair-picker",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.flair_utility_enabled) {
      return;
    }

    withPluginApi("0.12.1", (api) => {
      if (siteSettings.flair_utility_hide_user_flair_picker) {
        document.documentElement.classList.add("flair-utility-hide-picker");
      }
    });
  },
};
