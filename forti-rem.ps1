# Version 1.9 - 7/7/2022
# Enter the version you are looking to remove. 
# Partial matches will work for both application and version (ex: 6.0 will uninstall any 6.0.x version. FortiClient will match FortiClient, FortiClient VPN, Forticlient SSLVPN, etc)
# Check for installation -> if yes then -> uninstall > detect if application was installed > insert reg keys if uninstalled, if still installed, fail out

$SearchApplicationName = "FortiClient VPN"
$SearchApplicationVersion = "7.0.5.0238"
$OutputCodeSuccess = "1"
$OutputCodeFailure = "2"
$UninstallAlreadyRan = 'false'

# VPN Settings to Inject to registry
$vpn_name = 'PVI VPN'
$vpn_server = 'connect.palermospizza.com:10443'
$vpn_description = 'Connects to the PVI network using Azure AD for credentials'
$vpn_promptusername = '0'
$vpn_promptcertificate = '0'
$vpn_servercert = '1'
$vpn_preferdtlstunnel = '1'
$vpn_ssoenabled = '1'
$vpn_use_external_browser = '0'

# RegEx For GUID selection
$reGuid = '\{?(([0-9a-f]){8}-([0-9a-f]){4}-([0-9a-f]){4}-([0-9a-f]){4}-([0-9a-f]){12})\}?'

function Find-Application 
{
$my_check = Get-Itemproperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* `
| Where -property displayName -Like "$SearchApplicationName*" `
| Select-Object DisplayName, DisplayVersion, InstallDate, @{Name = 'GUID'; Expression = { if ($_.UninstallString -match $reGuid) {$matches[1]}} }

#If program is found ($my_check not null), check for version match
    if ($my_check) {
        $versionNumber = $my_check.DisplayVersion
            if ($versionnumber.Contains($SearchApplicationVersion)) {
                #Loop detection. Exits with error if we made it here before.
                if ($UninstallAlreadyRan -eq 'true') {
                    write-output $OutputCodeFailure
                    exit 2
                } else {
                    #Program with specific version found. Getting GUID and then calling uninstall function.
                    $product_guid = $my_check.guid
                    Uninstall-Application
                }
			} else {
                # The correct program was found, but not the correct version. Populating the registry to ensure correct values.
                Populate-Registry
                #Writing success output for MEM to pick up.
                write-output $OutputCodeSuccess
                exit 0
            }
    } else {
    #Getting here means the program with a specific version isn't installed, or was installed / uninstalled and no longer detected. Populating the registry to ensure correct values.
    Populate-Registry
    #Writing success output for MEM to pick up.
    write-output $OutputCodeSuccess
    exit 0
    }
}

function Populate-Registry
{
    # Clean out existing key, if it exists 
    if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Fortinet\") -eq $true) { Remove-Item "HKLM:\SOFTWARE\Fortinet\" -Recurse -force -ea ignore | out-null }
    # Install VPN Profiles
	if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name") -ne $true) { New-Item "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -force -ea ignore | out-null }
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'Server' -Value "$vpn_server" -PropertyType String -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'Description' -Value $vpn_description -PropertyType String -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'promptusername' -Value $vpn_promptusername -PropertyType DWord -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'promptcertificate' -Value $vpn_promptcertificate -PropertyType DWord -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'ServerCert' -Value $vpn_servercert -PropertyType String -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'use_external_browser' -Value $vpn_use_external_browser -PropertyType DWord -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpn_name" -Name 'sso_enabled' -Value $vpn_ssoenabled -PropertyType DWord -Force -ea ignore | out-null
    New-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\" -Name 'PreferDtlsTunnel' -Value $vpn_preferdtlstunnel -PropertyType DWord -Force -ea ignore | out-null
}

function Uninstall-Application
{
    #Stopping any possible FortiClient services
    Get-Service -DisplayName "FortiClient Service Scheduler" | Stop-Service -ErrorAction Ignore | out-null
    Get-Service -DisplayName "FortiClient VPN Service Scheduler" | Stop-Service -ErrorAction Ignore | out-null

    #Force closing any possible running programs
    Stop-Process -Name "FortiSSLVPNclient" -Force -ErrorAction Ignore
    Stop-Process -Name "FortiSSLVPNdaemon" -Force -ErrorAction Ignore
    Stop-Process -Name "FortiSettings" -Force -ErrorAction Ignore
    Stop-Process -Name "FortiTray" -Force -ErrorAction Ignore
    Stop-Process -Name "FortiClient" -Force -ErrorAction Ignore

    #Uninstall FortiClient 
    Start-Process msiexec.exe -Wait -ArgumentList "/x {$product_guid} /qn /norestart"

    #Cleans up the directory in case it is left behind
    Remove-Item -Path "C:\Program Files\Fortinet\" -Confirm:$false -Recurse -ErrorAction Ignore
    Remove-Item -Path "C:\Program Files (x86)\Fortinet\" -Confirm:$false -Recurse -ErrorAction Ignore

    #We wouldn't want to get stuck in a loop, would we?
    $UninstallAlreadyRan = 'true'

    #Re-run application check to make sure it's gone.
    Find-Application
}

#This starts the process. Checks for the application, and, if found, calls the uninstall script block. 
Find-Application

#We shouldn't get to this point. If we do, error!
write-output $OutputCodeFailure
