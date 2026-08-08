"""Generate notification-ready avatar PNGs from the app's bundled assets.

The 40 files in `assets/avatars/` have transparent backgrounds. That's right
for the app, where `AvatarDisplay` paints them on a gradient circle at render
time, but wrong for push notifications: FCM's `notification.image` is fetched
and drawn by the OS with no styling of ours, so a transparent avatar lands on
whatever the notification shade's background happens to be (usually white or
black) and typically reads as a floating, cut-out head.

This bakes the same gradient in once, so no image has to be edited by hand.
Run it whenever `assets/avatars/` changes, then upload the output folder to
the public `avatar-icons` Storage bucket (see CLAUDE.md).

    python tools/build_avatar_icons.py

Output: tools/avatar-icons-out/<same filenames>.png

Filenames are preserved exactly, because `send-push` builds the URL straight
from `profiles.avatar_id` (`fox-m` -> `.../avatar-icons/fox-m.png`).
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Matches AvatarCatalog.stageGradient — AppColors.magenta -> AppColors.primary.
# Keep in sync with lib/core/theme/app_colors.dart if the brand palette moves.
GRADIENT_START = (214, 31, 105)   # magenta
GRADIENT_END = (124, 58, 183)     # primary

SIZE = 512  # Comfortably above the ~256px most launchers render; keeps files small.

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "avatars"
OUT = Path(__file__).resolve().parent / "avatar-icons-out"


def gradient_background(size: int) -> Image.Image:
    """Diagonal two-stop gradient, drawn top-left to bottom-right."""
    base = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(base)
    # One line per diagonal step: cheap, and at 512px the banding is invisible.
    for i in range(size * 2):
        t = i / (size * 2 - 1)
        colour = tuple(
            round(GRADIENT_START[c] + (GRADIENT_END[c] - GRADIENT_START[c]) * t)
            for c in range(3)
        )
        draw.line([(i, 0), (0, i)], fill=colour)
    return base


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Source folder not found: {SRC}")

    OUT.mkdir(parents=True, exist_ok=True)
    background = gradient_background(SIZE)

    sources = sorted(SRC.glob("*.png"))
    if not sources:
        raise SystemExit(f"No PNGs found in {SRC}")

    for path in sources:
        avatar = Image.open(path).convert("RGBA")
        # `contain`-style fit so nothing is cropped, centred on the gradient.
        avatar.thumbnail((SIZE, SIZE), Image.LANCZOS)
        canvas = background.copy()
        offset = ((SIZE - avatar.width) // 2, (SIZE - avatar.height) // 2)
        # Third arg is the mask: uses the PNG's own alpha, so the transparent
        # area shows the gradient rather than a black box.
        canvas.paste(avatar, offset, avatar)
        canvas.save(OUT / path.name, "PNG", optimize=True)
        print(f"  {path.name}")

    print(f"\n{len(sources)} icons written to {OUT}")
    print("Upload the contents of that folder to the public 'avatar-icons' bucket.")


if __name__ == "__main__":
    main()
