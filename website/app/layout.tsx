import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ??
    requestHeaders.get("host") ??
    "rhinovoice.app";
  const protocol =
    requestHeaders.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const baseUrl = new URL(`${protocol}://${host}`);
  const socialImage = new URL("/og.png", baseUrl).toString();

  return {
    metadataBase: baseUrl,
    title: "Rhino — Private dictation for Mac",
    description:
      "Hold a key, talk, and Rhino types in any app. Fast, private dictation with on-device transcription and optional local AI cleanup.",
    applicationName: "Rhino",
    keywords: [
      "Mac dictation",
      "private dictation",
      "offline transcription",
      "voice typing",
      "on-device speech to text",
    ],
    openGraph: {
      type: "website",
      url: baseUrl,
      siteName: "Rhino",
      title: "Rhino — Talk. Rhino types. Nothing leaves your Mac.",
      description:
        "Private, on-device dictation for Mac. Hold Fn, speak naturally, and release to type in any app.",
      images: [
        {
          url: socialImage,
          width: 1740,
          height: 883,
          alt: "Rhino — private dictation for Mac",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Rhino — Private dictation for Mac",
      description: "Talk. Rhino types. Nothing leaves your Mac.",
      images: [socialImage],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        {children}
      </body>
    </html>
  );
}
