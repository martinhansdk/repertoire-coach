mkdir -p .pub-cache
docker run --rm \
  -e PUB_CACHE=/app/.pub-cache \
  -v $(pwd):/app \
  -v $(pwd)/.pub-cache:/app/.pub-cache \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "flutter pub get > /dev/null 2>&1 && dart run flutter_launcher_icons:main"

ICON_SOURCE="assets/icon/icon.png"
WEB_ICON_DIR="web/icons"
mkdir -p "$WEB_ICON_DIR"
for size in 192 512; do
  cp "$ICON_SOURCE" "$WEB_ICON_DIR/Icon-$size.png"
  cp "$ICON_SOURCE" "$WEB_ICON_DIR/Icon-maskable-$size.png"
done
cp "$ICON_SOURCE" "web/favicon.png"

git add assets/ android/app/src/main/res/mipmap-* android/app/src/main/res/drawable-* android/app/src/main/res/values/colors.xml ios/Runner/Assets.xcassets/AppIcon.appiconset/ web/icons web/favicon.png
git status --short
