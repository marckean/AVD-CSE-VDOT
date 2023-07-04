##############################################################
#  AppLocker configuration
##############################################################
# Block %SYSTEM32%\Taskmgr.exe for BUILTIN\Users
$path = "$env:TEMP\AppLocker"
$policyName = "AppLockerPolicy.xml"
$policyPath = "https://raw.githubusercontent.com/marckean/AVD-CSE-VDOT/main/$policyName"

if(!(Test-Path "$env:TEMP\AppLocker")){New-Item -Path $path -ItemType Directory}
Start-BitsTransfer -Source $policyPath -Destination $path
Set-AppLockerPolicy -XMLPolicy "$path\$policyName"

##############################################################
#  Set the AppLocker service to auto
##############################################################
sc.exe config appidsvc start= auto

##############################################################
#  Remote Desktop Session Host > Session Time Limits
##############################################################
# Set to 15 minutes
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name MaxDisconnectionTime -Type 'DWord' -Value 300000 -force

##############################################################
#  Local Security Group
##############################################################
net localgroup /add "AVD Users"

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
