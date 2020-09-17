# https://www.powershellgallery.com/packages/PSWindowsUpdate

$ErrorActionPreference = 'Stop'

'Installing the NuGet package provider to install modules from the PowerShell Gallery...'
Get-PackageProvider -Name 'NuGet' -Force

"Installing the 'PSWindowsUpdate' module for only the current user..."
Install-Module -Name 'PSWindowsUpdate' -Scope 'CurrentUser' -Force

"Importing the 'PSWindowsUpdate' module..."
Import-Module -Name 'PSWindowsUpdate'

'Installing all Microsoft Updates...'
Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -MicrosoftUpdate -IgnoreUserInput
