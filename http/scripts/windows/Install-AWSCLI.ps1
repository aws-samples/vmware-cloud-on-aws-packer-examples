# https://chocolatey.org/packages/awscli#install

$ErrorActionPreference = 'Stop'

'Installing AWS CLI via Chocolatey...'
choco install --yes --limitoutput --no-progress awscli
