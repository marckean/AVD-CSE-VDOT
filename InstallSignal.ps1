$signalExe = "signal-desktop-win-6.27.1.exe"

##############################################################
#  Install Signal
##############################################################
$path = "$env:TEMP\SignalInstall"
$exeName = $signalExe
$exePath = "https://updates.signal.org/desktop/$exeName"
Remove-Item "$path\$exeName" -Force -ErrorAction SilentlyContinue
if (!(Test-Path $path)) { New-Item -Path $path -ItemType Directory }
Start-BitsTransfer -Source $exePath -Destination $path
Start-Process "$path\$exeName" -ArgumentList "/S" -wait
# Find where Signal is installed and copy it to the Program Files folder
$userProfiles = (Get-ChildItem -Path "$env:SystemDrive\Users")
foreach ($userProfile in $userProfiles) {
    if (Test-Path "$($userProfile.FullName)\AppData\Local\Programs\signal-desktop") {
        Copy-Item -Path "$($userProfile.FullName)\AppData\Local\Programs\signal-desktop" -Destination "$env:ProgramFiles" -Recurse -Force
        Break
    }
}
