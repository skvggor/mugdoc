import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://{{PROJECT_NAME}}.{{BASE_DOMAIN}}",
  integrations: [
    starlight({
      title: "{{PROJECT_NAME}}",
      customCss: ["./src/styles/global.css"],
      components: {
        Footer: "./src/components/Footer.astro",
        PageFrame: "./src/components/PageFrame.astro",
      },
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
