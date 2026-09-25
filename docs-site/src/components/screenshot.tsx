import { cn } from "@/lib/cn";
import { asset } from "@/lib/shared";

export type ScreenshotName =
  | "menubar"
  | "menubar-dark"
  | "history"
  | "dictionary"
  | "settings"
  | "onboarding-0"
  | "onboarding-1"
  | "onboarding-2"
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
  darkName,
}: {
  name: ScreenshotName;
  /** A Dark Mode capture, shown instead of `name` when the site is dark. */
  darkName?: ScreenshotName;
  alt: string;
  caption?: string;
  className?: string;
  /** Skip the frame, for the transparent pill and menu bar captures. */
  bare?: boolean;
}) {
  const imageClass = cn("w-full h-auto", !bare && "rounded-xl");
  const image = darkName ? (
    <>
      {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
      <img
        src={asset(`/screenshots/${name}.png`)}
        alt={alt}
        loading="lazy"
        className={cn(imageClass, "dark:hidden")}
      />
      {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
      <img
        src={asset(`/screenshots/${darkName}.png`)}
        alt={alt}
        loading="lazy"
        className={cn(imageClass, "hidden dark:block")}
      />
    </>
  ) : (
    // biome-ignore lint/performance/noImgElement: static export serves plain files
    <img
      src={asset(`/screenshots/${name}.png`)}
      alt={alt}
      loading="lazy"
      className={imageClass}
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
