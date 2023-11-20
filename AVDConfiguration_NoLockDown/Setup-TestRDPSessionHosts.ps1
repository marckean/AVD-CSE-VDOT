

# ##############################################################
# #  Install Signal
# ##############################################################
# $path = "$env:ProgramFiles\signal-desktop"

# if(Test-Path $path){return $true} else {return $false;}


##############################################################
#  Check for FSLogix registry entries
##############################################################
$path = "HKLM:\SOFTWARE\FSLogix\Profiles"
$CCDLocations = (Get-Item $path).Property | where{$_ -eq 'CCDLocations'}

if($CCDLocations -eq 'CCDLocations'){return $true} else {return $false;}