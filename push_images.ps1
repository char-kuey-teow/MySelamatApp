Write-Host "Adding images to Android emulator for testing..." -ForegroundColor Green
Write-Host ""

# Create Pictures directory on emulator
adb shell mkdir -p /sdcard/Pictures/TestImages

# Check Downloads folder for images
$downloadsPath = "$env:USERPROFILE\Downloads"
$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.gif")

foreach ($extension in $imageExtensions) {
    $images = Get-ChildItem -Path $downloadsPath -Filter $extension -ErrorAction SilentlyContinue
    
    if ($images) {
        Write-Host "Found $($images.Count) $extension files in Downloads folder" -ForegroundColor Yellow
        
        foreach ($image in $images) {
            Write-Host "Pushing $($image.Name) to emulator..." -ForegroundColor Cyan
            adb push "`"$($image.FullName)`"" /sdcard/Pictures/TestImages/
        }
    }
}

Write-Host ""
Write-Host "Listing images in emulator gallery..." -ForegroundColor Green
adb shell ls -la /sdcard/Pictures/TestImages/

Write-Host ""
Write-Host "Done! You can now test photo selection in your Flutter app." -ForegroundColor Green
Read-Host "Press Enter to continue"
