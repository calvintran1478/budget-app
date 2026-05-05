import { defineConfig } from "vite";
import unocssPlugin from "unocss/vite";
import solid from "vite-plugin-solid";

export default defineConfig({
  plugins: [unocssPlugin(), solid()],
})
