configuration SetupSessionHost
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$storageConnectionString,

        [Parameter(Mandatory = $true)]
        [string]$HPtoken,

        [Parameter(Mandatory = $true)]
        [string]$repo,

        [Parameter(Mandatory = $true)]
        [string]$VDOT,

        [Parameter(Mandatory = $true)]
        [string]$signalExe
    )

    $ErrorActionPreference = 'Stop'
    
    #$ScriptPath = [system.io.path]::GetDirectoryName($pwd)
    $ScriptPath = (Get-ChildItem -Filter 'Setup-RDPSessionHosts.ps1' -Path "$env:SystemDrive\Packages" -Recurse).DirectoryName

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }
        Script InstallSignal
        {
            TestScript = { # the TestScript block runs first. If the TestScript block returns $false, the SetScript block will run
                Test-Path "$env:ProgramFiles\signal-desktop"
            }
            SetScript = {
                $path = "$env:windir\Temp\SignalInstall"
                $exeName = $using:signalExe
                $exePath = "https://updates.signal.org/desktop/$exeName"
                Remove-Item "$path\$exeName" -Force -ErrorAction SilentlyContinue
                if (!(Test-Path $path)) { New-Item -Path $path -ItemType Directory}
                #Start-BitsTransfer -Source $exePath -Destination $path
                Invoke-WebRequest -Uri $exePath -OutFile "$path\$exeName"
                Start-Process "$path\$exeName" -ArgumentList "/S" -wait
                # Find where Signal is installed and copy it to the Program Files folder
                $signalInstallFolder = (Get-ChildItem -Path c:\ -Directory -Recurse -ErrorAction SilentlyContinue | where {$_.Name -eq 'signal-desktop'} | select -First 1).Fullname
                Copy-Item -Path $signalInstallFolder -Destination "$env:ProgramFiles" -Recurse -Force
                }
            GetScript = { # should return a hashtable representing the state of the current node
            $result = Test-Path "$env:ProgramFiles\signal-desktop"
                @{
                    "Installed" = $result
                }
            } 
        }
        Script SetupSessionHost
        {
            TestScript = { # the TestScript block runs first. If the TestScript block returns $false, the SetScript block will run
                try {
                    $path = "HKLM:\SOFTWARE\FSLogix\Profiles"
                    $CCDLocations = (Get-Item $path).Property | where {$_ -eq 'CCDLocations'}
                    if($CCDLocations -eq 'CCDLocations'){return $true} else {return $false;}
                }
                catch {
                    $ErrMsg = $PSItem | Format-List -Force | Out-String
                    throw [System.Exception]::new("Some error occurred in Session Host setup script: $ErrMsg", $PSItem.Exception)
                }
            }
            SetScript  = {
                try {
                    & "$using:ScriptPath\Setup-RDPSessionHosts.ps1" -storageConnectionString $using:storageConnectionString -HPtoken $using:HPtoken -repo $using:repo -VDOT $using:VDOT
                }
                catch {
                    $ErrMsg = $PSItem | Format-List -Force | Out-String
                    throw [System.Exception]::new("Some error occurred in Session Host setup script: $ErrMsg", $PSItem.Exception)
                }
            }
            GetScript  = {
                $path = "HKLM:\SOFTWARE\FSLogix\Profiles"
                $CCDLocations = (Get-Item $path).Property | where {$_ -eq 'CCDLocations'}
                if($CCDLocations -eq 'CCDLocations'){return $true} else {return $false;}
            }
            DependsOn = "[Script]InstallSignal" 
        }
    }
}