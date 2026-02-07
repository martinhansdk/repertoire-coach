mkdir -p .pub-cache
docker run --rm \
  -e PUB_CACHE=/app/.pub-cache \
  -v $(pwd):/app \
  -v $(pwd)/.pub-cache:/app/.pub-cache \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "flutter pub get > /dev/null 2>&1 && dart run flutter_launcher_icons:main"
git add assets/ android/app/src/main/res/mipmap-* android/app/src/main/res/drawable-* android/app/src/main/res/values/colors.xml ios/Runner/Assets.xcassets/AppIcon.appiconset/ 
      && git status --short
