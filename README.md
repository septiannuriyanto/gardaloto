# gardaloto

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Watermark customization (how to test)

You can edit the watermark lines for each capture in the Capture dialog:

- Take a photo and open the capture dialog.
- Expand "Watermark (customize lines)" and edit any of the four lines (Line 1..4).
- If a line is left empty, the app will fall back to a sensible default (NRP, Unit, GPS, Time).
- Press Submit — a new watermarked image file is written next to the original (suffix `_wm.png`) and the saved record will reference the watermarked path.

If you want global, persistent defaults, I can add an app-wide Settings page to store them.

## Persistence and delete (how to test)

The app now saves LOTO records locally using Hive. To verify:

- Submit a LOTO record (via capture dialog or fullscreen form). You should see a SnackBar confirming the saved watermarked filename.
- The saved record persists across app restarts and appears in the list.
- To delete a record: tap the trash icon on the list item and confirm the dialog. This removes the record and attempts to delete the saved image file from disk.

The list thumbnails are shown with rounded corners (`ClipRRect`) and support tap-to-zoom with pinch/drag.
