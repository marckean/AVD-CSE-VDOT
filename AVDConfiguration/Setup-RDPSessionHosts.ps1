param(
    [Parameter(mandatory = $true)]
    [string]$storageConnectionString,

    [Parameter(Mandatory = $true)]
    [string]$HPtoken,

    [Parameter(Mandatory = $true)]
    [string]$repo,

    [Parameter(Mandatory = $true)]
    [string]$VDOT
)

##############################################################
#  Register session hosts to a host pool
#  https://learn.microsoft.com/en-us/azure/virtual-desktop/add-session-hosts-host-pool
##############################################################
$uris = @(
    "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv" # RDAgent.Installer
    "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH" # RDAgentBootLoader
)

$installers = @()
foreach ($uri in $uris) {
    $download = Invoke-WebRequest -Uri $uri -UseBasicParsing

    $fileName = ($download.Headers.'Content-Disposition').Split('=')[1].Replace('"','')
    $output = [System.IO.FileStream]::new("$env:temp\$fileName", [System.IO.FileMode]::Create)
    $output.write($download.Content, 0, $download.RawContentLength)
    $output.close()
    $installers += $output.Name
}

foreach ($installer in $installers) {
    Unblock-File -Path "$installer"
}

# To install the Remote Desktop Services Infrastructure Agent
$msi1 = Get-ChildItem -Path $env:temp -Filter "*RDAgent.Installer*" | select -Unique
$process = "$env:SystemRoot\System32\msiexec.exe"
$arguments = "/i `"{0}`" /quiet REGISTRATIONTOKEN=$($HPtoken)" -f $($msi1.FullName)
Start-Process $process -ArgumentList $arguments -wait

$msi2 = Get-ChildItem -Path $env:temp -Filter "*RDAgentBootLoader*" | select -Unique
$process = "$env:SystemRoot\System32\msiexec.exe"
$arguments = "/i `"{0}`" /quiet" -f $($msi2.FullName)
Start-Process $process -ArgumentList $arguments -wait

##############################################################
#  FSLogix setup CCDLocations
##############################################################
Write-Host 'Configuring FSLogix'

New-Item -Path 'HKLM:\SOFTWARE' -Name 'FSLogix' -ErrorAction Ignore
New-Item -Path 'HKLM:\SOFTWARE\FSLogix' -Name 'Profiles' -ErrorAction Ignore
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'Enabled' -Value 1 -Force

$process = "$env:ProgramFiles\FSLogix\Apps\frx.exe"
$arguments = "add-secure-key -key fslstgacct001-CS1 -value $storageConnectionString"
Start-Process $process -ArgumentList $arguments -wait

New-ItemProperty -Path HKLM:\SOFTWARE\FSLogix\Profiles\ -Name CCDLocations -PropertyType multistring -Value ('type=azure,name="AZURE PROVIDER 1",connectionString="|fslogix/fslstgacct001-CS1|"') -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'ClearCacheOnLogoff' -Value 1 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'DeleteLocalProfileWhenVHDShouldApply' -Value 1 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'FlipFlopProfileDirectoryName' -Value 1 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'HealthyProvidersRequiredForRegister' -Value 1 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'LockedRetryCount' -Value 3 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'LockedRetryInterval' -Value 15 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'ProfileType' -Value 0 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'ReAttachIntervalSeconds' -Value 15 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'ReAttachRetryCount' -Value 3 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'SizeInMBs' -Value 30000 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'VolumeType' -Value 'VHDX' -Force

##############################################################
#  Run the Virtual Desktop Optimization Tool (VDOT)
#  Derived from https://github.com/Azure/RDS-Templates/tree/master/wvd-sh/arm-template-customization
##############################################################
# https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool

# Download VDOT
$URL = $VDOT
$ZIP = 'VDOT.zip'
Invoke-WebRequest -Uri $URL -OutFile $ZIP -ErrorAction 'Stop'

# Extract VDOT from ZIP archive
Expand-Archive -LiteralPath $ZIP -Force -ErrorAction 'Stop'
    
# Run VDOT
& .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -Optimizations All -Verbose -AcceptEula

##############################################################
#  Hosts file - To disable Signal Updates
##############################################################
Add-Content -Path "$env:windir\System32\drivers\etc\hosts" -Value "`n127.0.0.1`tupdates.signal.org`n127.0.0.1`tupdates2.signal.org"

##############################################################
#  LGPO.exe - Download the tool
##############################################################
$path = "$env:SystemRoot\System32"
Invoke-WebRequest -Uri "https://$repo/LGPO.exe" -OutFile "$path\LGPO.exe"
# Start-BitsTransfer -Source "https://$repo/LGPO.exe" -Destination $path

##############################################################
#  LGPO.exe - Import and apply policy settings
##############################################################
$zip = "$repo/SignalAVD_LGPO.zip"
$localZip = "$env:TEMP\SignalAVD_LGPO.zip"
Remove-Item $localZip -Force -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $zip -OutFile $localZip -ErrorAction 'Stop'
# Extract VDOT from ZIP archive
Expand-Archive -Path $localZip -DestinationPath "$env:TEMP\SignalAVD_LGPO" -Force
Start-Process "LGPO.exe" -ArgumentList "/g $env:TEMP\SignalAVD_LGPO" -Wait

##############################################################
#  AppLocker configuration
##############################################################
# Block %SYSTEM32%\Taskmgr.exe for BUILTIN\Users
$path = "$env:TEMP\AppLocker"
$policyName = "AppLockerPolicy.xml"
$policyPath = "https://$repo/$policyName"

Remove-Item "$path\$policyName" -Force -ErrorAction SilentlyContinue
if(!(Test-Path $path)){New-Item -Path $path -ItemType Directory}
Invoke-WebRequest -Uri $policyPath -OutFile "$path\$policyName"
#Start-BitsTransfer -Source $policyPath -Destination $path
Set-AppLockerPolicy -XMLPolicy "$path\$policyName"

##############################################################
#  Set the AppLocker service to auto
##############################################################
sc.exe config appidsvc start=auto

##############################################################
#  Remote Desktop Session Host > Session Time Limits
##############################################################
# Set to 15 minutes
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name MaxDisconnectionTime -Type 'DWord' -Value 300000 -force
