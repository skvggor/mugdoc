import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  site: "https://mugdoc.reposito.rio.br",
  integrations: [
    starlight({
      title: "mugdoc",
      customCss: ["./src/styles/global.css"],
      components: {
        Footer: "./src/components/Footer.astro",
      },
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
