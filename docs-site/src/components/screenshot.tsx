import { cn } from "@/lib/cn";
import { asset } from "@/lib/shared";

export type ScreenshotName =
  | "home"
  | "history"
  | "dictionary"
  | "settings"
  | "onboarding-0"
  | "onboarding-1"
  | "onboarding-3"
  | "onboarding-4"
  | "onboarding-5"
  | "pill-recording"
  | "pill-transcribing"
  | "pill-inserted";

/** A PNG captured by scripts/capture-screenshots.sh, framed like a window. */
export function Screenshot({
  name,
  alt,
  caption,
  className,
  bare = false,
}: {
  name: ScreenshotName;
  alt: string;
  caption?: string;
  className?: string;
  /** Skip the frame, for the transparent pill captures. */
  bare?: boolean;
}) {
  const image = (
    // biome-ignore lint/performance/noImgElement: static export serves plain files
    <img
      src={asset(`/screenshots/${name}.png`)}
      alt={alt}
      loading="lazy"
      className={cn("w-full h-auto", !bare && "rounded-xl")}
    />
  );

  return (
    <figure className={cn("not-prose my-6", className)}>
      {bare ? (
        image
      ) : (
        <div className="rounded-2xl border bg-fd-card/60 p-1.5 shadow-xl shadow-black/10">
          {image}
        </div>
      )}
      {caption ? (
        <figcaption className="mt-3 text-center text-sm text-fd-muted-foreground">
          {caption}
        </figcaption>
      ) : null}
    </figure>
  );
}
