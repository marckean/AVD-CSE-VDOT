$repo = "raw.githubusercontent.com/marckean/AVD-CSE-VDOT/main"

##############################################################
#  AppLocker configuration
##############################################################
# Block %SYSTEM32%\Taskmgr.exe for BUILTIN\Users
$path = "$env:TEMP\AppLocker"
$policyName = "AppLockerPolicy.xml"
$policyPath = "https://$repo/$policyName"

Remove-Item "$path\$policyName" -Force -ErrorAction SilentlyContinue
if(!(Test-Path $path)){New-Item -Path $path -ItemType Directory}
Start-BitsTransfer -Source $policyPath -Destination $path
Set-AppLockerPolicy -XMLPolicy "$path\$policyName"

##############################################################
#  LGPO.exe - Import and apply policy settings
##############################################################
$path = "$env:SystemRoot\System32"
Start-BitsTransfer -Source "https://$repo/LGPO.exe" -Destination $path

##############################################################
#  LGPO.exe - Import and apply policy settings
##############################################################
$zip = "https://github.com/marckean/AVD-CSE-VDOT/raw/main/SignalAVD_LGPO.zip"
$localZip = "$env:TEMP\SignalAVD_LGPO.zip"
Remove-Item $localZip -Force -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $zip -OutFile $localZip -ErrorAction 'Stop'
# Extract VDOT from ZIP archive
Expand-Archive -Path $localZip -DestinationPath "$env:TEMP\SignalAVD_LGPO" -Force
LGPO.exe /g "$env:TEMP\SignalAVD_LGPO"

##############################################################
#  Install Signal
##############################################################
$path = "$env:TEMP\SignalInstall"
$exeName = "signal-desktop-win-6.25.0.exe"
$exePath = "https://updates.signal.org/desktop/$exeName"

Remove-Item "$path\$exeName" -Force -ErrorAction SilentlyContinue
if(!(Test-Path $path)){New-Item -Path $path -ItemType Directory}
Start-BitsTransfer -Source $exePath -Destination $path

$Command = "$path\$exeName /S"
Invoke-Expression $Command -Verbose
Start-Sleep -Seconds 60
Copy-Item -Path "$env:USERPROFILE\AppData\Local\Programs\signal-desktop\*" -Destination "$env:ProgramFiles\signal-desktop" -Recurse -Force

##############################################################
#  Set the AppLocker service to auto
##############################################################
sc.exe config appidsvc start=auto

##############################################################
#  Remote Desktop Session Host > Session Time Limits
##############################################################
# Set to 15 minutes
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name MaxDisconnectionTime -Type 'DWord' -Value 300000 -force

##############################################################
#  Run the Virtual Desktop Optimization Tool (VDOT)
##############################################################
# https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool

# Download VDOT
$URL = 'https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip'
$ZIP = 'VDOT.zip'
Invoke-WebRequest -Uri $URL -OutFile $ZIP -ErrorAction 'Stop'

# Extract VDOT from ZIP archive
Expand-Archive -LiteralPath $ZIP -Force -ErrorAction 'Stop'
    
# Run VDOT
& .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -AcceptEULA -Restart
