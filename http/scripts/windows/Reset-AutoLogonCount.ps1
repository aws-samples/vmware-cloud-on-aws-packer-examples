# https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue

$ErrorActionPreference = 'Stop'

'Resetting AutoLogonCount to 0...'
$splat = @{
    Path  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Name  = 'AutoLogonCount'
    Value = 0
    Force = $true
}
Set-ItemProperty @splat
