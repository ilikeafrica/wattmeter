#!/bin/bash
# 배포용 릴리스: Xcode archive → Developer ID export → DMG → 공증 → 스테이플.
#
# 사전 1회 (공증 자격증명 등록):
#   xcrun notarytool store-credentials wattmeter \
#     --apple-id <APPLE_ID> --team-id 9ZL9DK8938 --password <앱전용암호>
#   (앱 전용 암호: https://appleid.apple.com → 로그인 및 보안 → 앱 암호)
#
# 사용:  ./release.sh                    (archive+export+DMG+공증)
#        SKIP_NOTARIZE=1 ./release.sh    (공증 없이 서명 DMG만; 로컬 확인용)
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
NAME="WattMeter"
NOTARY_PROFILE="${NOTARY_PROFILE:-wattmeter}"

command -v xcodegen >/dev/null && xcodegen generate >/dev/null

BUILD="$ROOT/build"
ARCHIVE="$BUILD/$NAME.xcarchive"
EXPORT="$BUILD/export"
rm -rf "$ARCHIVE" "$EXPORT"

echo "▶︎ 1/6 아카이브(유니버설, 하드닝 런타임)"
xcodebuild -project WattMeter.xcodeproj -scheme WattMeter -configuration Release \
  -archivePath "$ARCHIVE" archive

echo "▶︎ 2/6 Developer ID export"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" -exportOptionsPlist ExportOptions.plist
APP="$EXPORT/$NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$BUILD/$NAME-$VERSION.dmg"
codesign --verify --strict --verbose=2 "$APP"

if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
  echo "▶︎ 3/6 공증 건너뜀(SKIP_NOTARIZE=1) → 서명 DMG만 생성"
  STAGE="$BUILD/dmgroot"; rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"; hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  echo "✅ 서명 DMG: $DMG"; exit 0
fi

echo "▶︎ 3/6 앱 공증 제출(수 분 소요)"
ZIP="$BUILD/$NAME.zip"; rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▶︎ 4/6 앱에 스테이플(오프라인 실행 대비)"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▶︎ 5/6 DMG 생성(스테이플된 앱 담기)"
STAGE="$BUILD/dmgroot"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"; hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "▶︎ 6/6 DMG 공증 + 스테이플 + 검증"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -vvv "$STAGE/$NAME.app" 2>&1 | grep -E "accepted|source=" || true
echo "✅ 배포 준비 완료: $DMG"
