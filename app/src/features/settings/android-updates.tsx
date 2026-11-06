import { useEffect, useState } from "react";
import { invoke, isTauri } from "@tauri-apps/api/core";
import { openUrl } from "@tauri-apps/plugin-opener";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

type Update = { version: string; url: string };
const check = () => invoke<Update | null>("check_android_update");
const isAndroidApp = () => isTauri() && /Android/i.test(navigator.userAgent);

/** Check once per app launch; updates are installed by Android after the user downloads them. */
export function AndroidUpdateNotice() {
  useEffect(() => {
    if (!isAndroidApp()) return;
    let cancelled = false;
    void check().then((update) => {
      if (cancelled || !update) return;
      toast.info(`Backsight ${update.version} is available`, {
        id: "android-update", duration: Infinity,
        description: "Open GitHub to download the update.",
        action: { label: "View update", onClick: () => { void openUrl(update.url); } },
      });
    }).catch(() => {});
    return () => { cancelled = true; };
  }, []);
  return null;
}

export function AndroidUpdateButton() {
  const [busy, setBusy] = useState(false);
  if (!isAndroidApp()) return null;
  return <Button variant="outline" size="sm" disabled={busy} onClick={() => {
    setBusy(true);
    void check().then((update) => {
      if (!update) toast.info("No newer Android release was found.");
      else toast.info(`Backsight ${update.version} is available`, {
        duration: Infinity, action: { label: "View update", onClick: () => { void openUrl(update.url); } },
      });
    }).catch(() => toast.error("Couldn't check GitHub. Check your internet connection and try again."))
      .finally(() => setBusy(false));
  }}>{busy ? "Checking…" : "Check for Android updates"}</Button>;
}
