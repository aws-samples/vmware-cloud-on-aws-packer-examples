# https://www.packer.io/docs/communicators/winrm#configuring-winrm-in-vmware

$ErrorActionPreference = 'Stop'

'Initializing WinRM...'

'Removing all WinRM listeners...'
Remove-Item -Path 'WSMan:\Localhost\listener\listener*' -Recurse -Force

'Creating a self-signed certificate...'
$splat = @{
    CertStoreLocation = 'Cert:\LocalMachine\My'
    DnsName           = $Env:COMPUTERNAME
}
$cert = New-SelfSignedCertificate @splat

'Adding the self-signed certificate to the local WinRM listener catalog...'
$splat = @{
    Path                  = 'WSMan:\LocalHost\Listener'
    Transport             = 'HTTPS'
    Address               = '*'
    CertificateThumbPrint = $cert.Thumbprint
    Force                 = $true
}
New-Item @splat

'Initializing WinRM...'
$splat = @{
    UseSSL                  = $false
    SkipNetworkProfileCheck = $true
    Force                   = $true
}
Set-WSManQuickConfig @splat

'Configuring WinRM to allow unencrypted communication...'
$splat = @{
    ResourceUri = 'winrm/config/service'
    ValueSet    = @{ AllowUnencrypted = 'true' }
}
Set-WSManInstance @splat

'Configuring WinRM to allow basic username/password authentication...'
$splat = @{
    ResourceUri = 'winrm/config/service/auth'
    ValueSet    = @{ Basic = 'true' }
}
Set-WSManInstance @splat

'Assigning the self-signed cert to the WinRM listener...'
$splat = @{
    ResourceUri = 'winrm/config/listener'
    SelectorSet = @{
        Address   = '*'
        Transport = 'HTTPS'
    }
    ValueSet    = @{
        Port                  = '5986'
        Hostname              = 'packer'
        CertificateThumbprint = $cert.Thumbprint
    }
}
Set-WSManInstance @splat

'Retarting the WinRM service...'
Restart-Service -Name 'WinRM' -Force

'Disable the WinRM service in favor of OpenSSH...'
Set-Service -Name 'WinRM' -StartupType 'Disabled'
