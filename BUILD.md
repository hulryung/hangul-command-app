# HangulCommandApp 빌드 가이드

## 🔨 빌드 방법

### 방법 1: 자동 빌드 스크립트 사용
```bash
# 실행 권한 부여
chmod +x build.sh

# 빌드 실행
./build.sh
```

### 방법 2: 수동 빌드
```bash
# 1. Xcode 프로젝트 정리
xcodebuild clean -project HangulCommandApp.xcodeproj -scheme HangulCommandApp

# 2. Release 빌드
xcodebuild -project HangulCommandApp.xcodeproj \
    -scheme HangulCommandApp \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="Developer ID Application: Your Name" \
    CODE_SIGN_ENTITLEMENTS="HangulCommandApp/HangulCommandApp.entitlements"

# 3. 앱 아카이브 생성
xcodebuild -project HangulCommandApp.xcodeproj \
    -scheme HangulCommandApp \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    -archivePath build/Archive.xcarchive

# 4. 배포용 익스포트
xcodebuild -exportArchive \
    -archivePath build/Archive.xcarchive \
    -exportPath build/Export \
    -exportOptionsPlist exportOptions.plist
```

## 📋 필수 준비물

1. **Apple 개발자 계정**: Xcode 및 코드 사인에 필요
2. **Xcode**: 15.0 이상 설치
3. **macOS**: 13.0 이상 (Ventura 이상)

## 📦 빌드 결과물

빌드 성공 시 다음 파일들이 생성됩니다:
- `HangulCommandApp-1.0.0.zip` - GitHub 릴리즈용
- `HangulCommandApp-1.0.0.dmg` - 직접 배포용

## 🐛 트러블슈팅

### 빌드 오류
```bash
# 권한 문제 확인
ls -la /dev/null

# Xcode 경로 확인
xcode-select -p

# 시스템 정보 확인
sw_vers -productVersion
```

### 코드 사인 오류
```bash
# 개발자 인증서 목록
security find-identity -v -p codesigning

# 수동 사인 테스트
codesign --verify --verbose HangulCommandApp.app
```

## 🚀 자동화

```bash
# GitHub Actions에 추가할 수 있는 빌드 스크립트
# .github/workflows/build.yml 파일 참고
```

---

이 가이드를 사용하여 직접 앱을 빌드하고 배포할 수 있습니다.