@echo off
echo Adding images to Android emulator for testing...
echo.

REM Create Pictures directory on emulator
adb shell mkdir -p /sdcard/Pictures/TestImages

REM Check if downloads folder has images
if exist "%USERPROFILE%\Downloads\*.jpg" (
    echo Found JPG files in Downloads folder
    for %%f in ("%USERPROFILE%\Downloads\*.jpg") do (
        echo Pushing %%f to emulator...
        adb push "%%f" /sdcard/Pictures/TestImages/
    )
) else (
    echo No JPG files found in Downloads folder
)

if exist "%USERPROFILE%\Downloads\*.png" (
    echo Found PNG files in Downloads folder
    for %%f in ("%USERPROFILE%\Downloads\*.png") do (
        echo Pushing %%f to emulator...
        adb push "%%f" /sdcard/Pictures/TestImages/
    )
) else (
    echo No PNG files found in Downloads folder
)

echo.
echo Listing images in emulator gallery...
adb shell ls -la /sdcard/Pictures/TestImages/

echo.
echo Done! You can now test photo selection in your Flutter app.
pause
