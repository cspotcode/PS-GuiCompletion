$ErrorActionPreference = 'stop'
set-location $PSScriptRoot
. .\build.ps1
$key = get-content -raw -path publishkey.txt | out-string
$psd = get-content -raw -path .\GuiCompletion.psd1 | out-string
$manifest = invoke-expression $psd
$version = $manifest.moduleversion
publish-module -Path $out -NuGetApiKey $key
git tag "v$version"