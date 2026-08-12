import type { Metadata } from "next";
import Link from "next/link";
import RedeemForm from "./redeem-form";

export const metadata: Metadata = {
  title: "Redeem your AppSumo code — Rhino",
  description: "Redeem your AppSumo code and download Rhino for Mac.",
  robots: { index: false, follow: false },
};

export default function AppSumoRedemptionPage() {
  return (
    <main className="redemption-page">
      <Link className="redemption-brand" href="/" aria-label="Rhino home">
        <span className="rhino-mark redemption-mark" aria-hidden="true">
          🦏
        </span>
        <span>Rhino</span>
      </Link>
      <RedeemForm />
    </main>
  );
}
