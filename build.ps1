$ErrorActionPreference = 'stop'
$moduleName = (gci *.psd1)[0].basename
Set-Location $PSScriptRoot
$out = "out\$moduleName"
if(test-path out) {
    rm -r out
    mkdir $out | out-null
}
cp -r ./powertab $out
cp GuiCompletion.psd1 $out
cp GuiCompletion.psm1 $out