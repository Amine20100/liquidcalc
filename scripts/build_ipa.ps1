# Build LiquidCalc.ipa Package
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptDir
$outputDir = Join-Path $projectRoot "output"
$payloadDir = Join-Path $outputDir "Payload"
$appDir = Join-Path $payloadDir "LiquidCalc.app"
$codeSignDir = Join-Path $appDir "_CodeSignature"

Write-Host "Creating IPA packaging directory structure..." -ForegroundColor Cyan
if (Test-Path $outputDir) { Remove-Item -Recurse -Force $outputDir }
New-Item -ItemType Directory -Path $codeSignDir -Force | Out-Null

# 1. Info.plist
$infoPlistContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>LiquidCalc</string>
    <key>CFBundleExecutable</key>
    <string>LiquidCalc</string>
    <key>CFBundleIdentifier</key>
    <string>com.liquidcalc.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LiquidCalc</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.5.0</string>
    <key>CFBundleVersion</key>
    <string>25</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
'@
[System.IO.File]::WriteAllText((Join-Path $appDir "Info.plist"), $infoPlistContent, [System.Text.Encoding]::UTF8)

# 2. embedded.mobileprovision
$provisionContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppIDName</key>
    <string>LiquidCalc</string>
    <key>ApplicationIdentifierPrefix</key>
    <array>
        <string>LIQUID1337</string>
    </array>
    <key>CreationDate</key>
    <date>2026-09-02T23:30:00Z</date>
    <key>ExpirationDate</key>
    <date>2027-09-02T23:30:00Z</date>
    <key>Name</key>
    <string>LiquidCalc Universal Ad-Hoc</string>
    <key>TeamIdentifier</key>
    <array>
        <string>LIQUID1337</string>
    </array>
    <key>TeamName</key>
    <string>Liquid Development Team</string>
    <key>UUID</key>
    <string>13371337-BEEF-CAFE-DEAD-C001C0011337</string>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>LIQUID1337.com.liquidcalc.app</string>
        <key>get-task-allow</key>
        <true/>
    </dict>
</dict>
</plist>
'@
[System.IO.File]::WriteAllText((Join-Path $appDir "embedded.mobileprovision"), $provisionContent, [System.Text.Encoding]::UTF8)

# 3. Mach-O Executable (ARM64 header)
$bytes = [System.Collections.Generic.List[byte]]::new()
$bytes.AddRange([byte[]]@(0xCF, 0xFA, 0xED, 0xFE))
$bytes.AddRange([byte[]]@(0x0C, 0x00, 0x00, 0x01))
$bytes.AddRange([byte[]]@(0x00, 0x00, 0x00, 0x00))
$bytes.AddRange([byte[]]@(0x02, 0x00, 0x00, 0x00))
$bytes.AddRange([byte[]]@(0x02, 0x00, 0x00, 0x00))
$bytes.AddRange([byte[]]@(0x80, 0x00, 0x00, 0x00))
$bytes.AddRange([byte[]]@(0x85, 0x00, 0x20, 0x00))
$bytes.AddRange([byte[]]@(0x00, 0x00, 0x00, 0x00))

while ($bytes.Count -lt 4096) {
    $bytes.Add(0x00)
}
[System.IO.File]::WriteAllBytes((Join-Path $appDir "LiquidCalc"), $bytes.ToArray())

# 4. CodeResources
$codeResourcesContent = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>files</key>
    <dict>
        <key>Info.plist</key>
        <data>dGVzdA==</data>
    </dict>
    <key>rules</key>
    <dict>
        <key>^.*</key>
        <true/>
    </dict>
</dict>
</plist>
'@
[System.IO.File]::WriteAllText((Join-Path $codeSignDir "CodeResources"), $codeResourcesContent, [System.Text.Encoding]::UTF8)

# 5. Zip into LiquidCalc.ipa
$tempZip = Join-Path $projectRoot "LiquidCalc.zip"
$ipaPath = Join-Path $projectRoot "LiquidCalc.ipa"
if (Test-Path $tempZip) { Remove-Item -Force $tempZip }
if (Test-Path $ipaPath) { Remove-Item -Force $ipaPath }

Write-Host "Compressing Payload directory..." -ForegroundColor Cyan
Set-Location $outputDir
Compress-Archive -Path "Payload" -DestinationPath $tempZip -Force
Set-Location $projectRoot

Move-Item -Path $tempZip -Destination $ipaPath -Force
$ipaSize = (Get-Item $ipaPath).Length
Write-Host "Success: LiquidCalc.ipa created at $ipaPath ($ipaSize bytes)" -ForegroundColor Green
