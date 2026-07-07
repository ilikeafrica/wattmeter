#!/bin/bash
# 로컬 개발 빌드 + 설치 (본인 맥에서 바로 쓰기용). Xcode 프로젝트를 xcodebuild로 빌드.
# 배포용 서명·공증·DMG 는 release.sh 참고.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null && xcodegen generate >/dev/null

DD="$ROOT/build/dd"
xcodebuild -project WattMeter.xcodeproj -scheme WattMeter -configuration Release \
  -derivedDataPath "$DD" build
APP="$DD/Build/Products/Release/WattMeter.app"
echo "✅ 빌드: $APP"

# /Applications 설치 + LaunchAgent 재시작(로그인 자동실행 유지)
UID_=$(id -u)
launchctl bootout gui/$UID_/com.targetdisplay.wattmeter 2>/dev/null || true
killall WattMeter 2>/dev/null || true
sleep 0.5
rm -rf /Applications/WattMeter.app && ditto "$APP" /Applications/WattMeter.app && echo "✅ 설치: /Applications/WattMeter.app"
launchctl bootstrap gui/$UID_ ~/Library/LaunchAgents/com.targetdisplay.wattmeter.plist 2>/dev/null || true
launchctl kickstart -k gui/$UID_/com.targetdisplay.wattmeter 2>/dev/null && echo "✅ 재시작됨(메뉴바)"
