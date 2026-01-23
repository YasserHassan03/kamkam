Place the source launcher/splash icon image in this folder as `app_icon.png`.

Requirements & recommendations:
- Provide a high-resolution square PNG (recommended 2048x2048 or at least 1024x1024).
- Transparent background is fine; the generator will composite as needed.

After adding your file, run:

1) Install dependencies:
   flutter pub get

2) Generate platform launcher icons:
   flutter pub run flutter_launcher_icons:main

3) Generate splash screen from same image:
   flutter pub run flutter_native_splash:create

4) (Optional) Generate Play/App store assets (512x512 and 1024x1024) using the helper script:
   scripts/generate_store_assets.sh assets/icons/app_icon.png

If you want me to import the PNG for you, upload the file to the repository path `assets/icons/app_icon.png` and tell me to proceed; otherwise add it locally and run the commands above.