import adapter from "@sveltejs/adapter-auto";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/** @type {import("@sveltejs/kit").Config} */
const config = {
  preprocess: vitePreprocess(),
  compilerOptions: {
    runes: true,
  },
  kit: {
    adapter: adapter(),
    alias: {
      "@common/*":   "src/common/*",
      "@models/*":   "src/models/*",
      "@shared/*":   "src/shared/*",
    },
  },
};

export default config;
