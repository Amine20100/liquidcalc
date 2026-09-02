import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "LiquidCalc Serverless Engine | Gemini 2.5 Flash & iOS OTA Hub",
  description:
    "Production Next.js Serverless Backend Suite for LiquidCalc iOS 18+: Gemini 2.5 Flash SSE streaming proxy, dynamic Apple itms-services OTA manifest generator, update distribution, and history sync.",
  icons: {
    icon: "https://raw.githubusercontent.com/Amine20100/liquidcalc/main/LiquidCalc/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-[#07090e] text-gray-100 antialiased selection:bg-[#00F0FF]/30 selection:text-[#00F0FF]">
        {children}
      </body>
    </html>
  );
}
