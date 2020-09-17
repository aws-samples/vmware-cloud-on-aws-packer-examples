# https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse#installing-openssh-with-powershell

$ErrorActionPreference = 'Stop'

'Getting the current OpenSSH Server Windows Capability configuration...'
$opensshServerWindowsCapability = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' |
    Select-Object -First 1

if ($null -eq $opensshServerWindowsCapability.Name) {
    'Installing OpenSSH Server via Chocolatey...'
    choco install --yes --limitoutput --no-progress openssh
} else {
    'Installing OpenSSH Server via Windows Features on Demand...'
    Add-WindowsCapability -Online -Name $opensshServerWindowsCapability.Name
}

$path = 'HKLM:\SOFTWARE\OpenSSH'
if ((Test-Path -Path $path) -eq $false) {
    New-Item -Path $path -Force
}

'Setting the default shell to PowerShell...'
$splat = @{
    Path  = $path
    Name  = 'DefaultShell'
    Value = "$Env:SYSTEMROOT\System32\WindowsPowerShell\v1.0\powershell.exe"
}
New-ItemProperty @splat

'Setting the OpenSSH Server service to start automatically...'
Set-Service -Name 'sshd' -StartupType 'Automatic'
