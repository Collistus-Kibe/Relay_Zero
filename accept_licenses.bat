@echo off
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
set ANDROID_HOME=C:\Android

REM Accept all licenses by creating the license files directly
mkdir "%ANDROID_HOME%\licenses" 2>NUL

echo 24333f8a63b6825ea9c5514f83c2829b004d1fee > "%ANDROID_HOME%\licenses\android-sdk-license"
echo d56f5187479451eabf01fb78af6dfcb131a6481e >> "%ANDROID_HOME%\licenses\android-sdk-license"
echo e6b7c2ab7fa2298c15165e9583d0cbd258bcd75d >> "%ANDROID_HOME%\licenses\android-sdk-license"

echo 84831b9409646a918e30573bab4c9c91346d8abd > "%ANDROID_HOME%\licenses\android-sdk-preview-license"

echo d975f751698a77b662f1254ddbeed3901e976f5a > "%ANDROID_HOME%\licenses\intel-android-extra-license"

echo 33b6a2b64607f11b759f320ef9dff4ae5c47d97a > "%ANDROID_HOME%\licenses\google-gdk-license"

echo e9acab5b5fbb560a72cfaecber8acb301024d4caaa > "%ANDROID_HOME%\licenses\mips-android-sysimage-license"

echo 601085b94cd77f0b54ff86406957099ebe79c4d6 > "%ANDROID_HOME%\licenses\android-googletv-license"

echo 33b6a2b64607f11b759f320ef9dff4ae5c47d97a > "%ANDROID_HOME%\licenses\android-sdk-arm-dbt-license"

echo Done creating license files.

REM Now install packages
echo Installing Android SDK packages...
"%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" "platform-tools" "emulator" "platforms;android-35" "build-tools;35.0.0" "system-images;android-35;google_apis;x86_64"
