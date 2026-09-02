import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "#07090e",
        foreground: "#f3f4f6",
        cyber: {
          bg: "#07090e",
          card: "rgba(13, 17, 26, 0.75)",
          cardHover: "rgba(22, 28, 45, 0.85)",
          cyan: "#00F0FF",
          purple: "#7928CA",
          emerald: "#00FFA3",
          pink: "#FF007A",
          yellow: "#FFE600",
          border: "rgba(255, 255, 255, 0.08)",
          borderHover: "rgba(0, 240, 255, 0.35)",
        },
      },
      boxShadow: {
        glowCyan: "0 0 25px -5px rgba(0, 240, 255, 0.3)",
        glowPurple: "0 0 25px -5px rgba(121, 40, 202, 0.4)",
        glowEmerald: "0 0 25px -5px rgba(0, 255, 163, 0.3)",
      },
      fontFamily: {
        mono: [
          "JetBrains Mono",
          "SF Mono",
          "Consolas",
          "Menlo",
          "Courier New",
          "monospace",
        ],
      },
    },
  },
  plugins: [],
};

export default config;
