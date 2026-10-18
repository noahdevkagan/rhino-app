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
    title: "Rhino Voice: Free private dictation for Mac",
    description:
      "Talk instead of typing. Hold a key, speak, and your words appear in any Mac app. Free, fast, and private: nothing goes to the cloud.",
    applicationName: "Rhino Voice",
    keywords: [
      "Rhino Voice",
      "Mac dictation",
      "private dictation",
      "offline transcription",
      "voice typing",
      "on-device speech to text",
    ],
    openGraph: {
      type: "website",
      url: baseUrl,
      siteName: "Rhino Voice",
      title: "Rhino Voice: Talk instead of typing. Free, and nothing leaves your Mac.",
      description:
        "Hold one key, talk, and your words show up in any Mac app. Free to use, works with Wi-Fi off, and nothing goes to the cloud.",
      images: [
        {
          url: socialImage,
          width: 1740,
          height: 883,
          alt: "Rhino Voice, private dictation for Mac",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Rhino Voice: Free private dictation for Mac",
      description: "Talk instead of typing. Free, and nothing leaves your Mac.",
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
