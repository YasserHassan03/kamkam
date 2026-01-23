What I added

- `pubspec.yaml` updates with:
  - `flutter_launcher_icons` config (top-level) and dev dependency
  - `flutter_native_splash` config (top-level) and dev dependency
  - `assets/icons/` added to `flutter.assets`

- Files:
  - `assets/icons/README.md` (how to supply the source image and generate icons)
  - `scripts/generate_store_assets.sh` (ImageMagick helper to create Play/App store graphics)

What you need to do

1) Save the source PNG you attached as:
   `assets/icons/app_icon.png`
   - Recommended: 1024x1024 or larger (2048x2048 recommended)

2) Generate platform icons and splash:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons:main
   flutter pub run flutter_native_splash:create
   ```

3) (Optional) Generate store assets (requires ImageMagick):
   ```bash
   ./scripts/generate_store_assets.sh assets/icons/app_icon.png
   ```

If you'd like, I can import the PNG you attached into `assets/icons/app_icon.png` and run the generators for you — confirm and I'll proceed.