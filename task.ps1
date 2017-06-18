param(
    [switch]$build,
    [switch]$publish,
    [switch]$bumpMajorVersion,
    [switch]$bumpMinorVersion,
    [switch]$bumpPatchVersion,
    $setVersion,
    [switch]$getVersion
)

$ErrorActionPreference = 'stop'
Set-Location $PSScriptRoot

function get-manifest-content {
    read-file .\$moduleName.psd1
}
function set-manifest-content($s) {
    write-file .\$moduleName.psd1 $s
}
function get-manifest {
    invoke-expression (get-manifest-content)
}
class SemVer {
    [int]$Major
    [int]$Minor
    [int]$Patch
    [object]$Suffix
    static [SemVer]parse($v) {
        if($v -match '(\d+)(?:\.(\d+)(?:\.(\d+)(.*)?)?)?') {
            return [SemVer]@{
                Major = $Matches[1]
                Minor = $Matches[2]
                Patch = $Matches[3]
                Suffix = $Matches[4]
            }
        } else {
            return $null
        }
    }
    [string]encode() {
        return '' + $this.Major + '.' + $this.Minor + '.' + $this.Patch + $this.Suffix
    }
}
function get-version {
    (get-manifest).moduleversion
}
function set-version($version) {
    $psd = get-manifest-content
    set-manifest-content ($psd -replace "ModuleVersion\s*=\s*'.*'","ModuleVersion = '$version'")
}
function read-file($path) {
    get-content -raw -path $path | out-string
}
function write-file($path, $content) {
    [system.Text.Encoding]::UTF8.GetBytes($content) | set-content -path $path -encoding byte
}

$moduleName = (gci *.psd1)[0].basename
$out = "out\$moduleName"
$version = [SemVer]::parse((get-version))

if($bumpMajorVersion) {
    $version.Major++
    $version.Minor = 0
    $version.Patch = 0
    $version.Suffix = $null
    Set-Version $version.encode()
}
if($bumpMinorVersion) {
    $version.Minor++
    $version.Patch = 0
    $version.Suffix = $null
    Set-Version $version.encode()
}
if($bumpPatchVersion) {
    $version.Patch++
    $version.Suffix = $null
    Set-Version $version.encode()
}
if($setVersion) {
    set-version $setVersion
}
if($getVersion) {
    echo (get-version)
}
if($build) {
    if(test-path out) {
        rm -r out
        mkdir $out | out-null
    }

    # Copy files
    cp -r ./powertab $out
    cp "$moduleName.psm1" $out
    cp README.md $out

    # Render module manifest
    $readme = read-file README.md
    $psd = read-file "$moduleName.psd1"
    $matches = $null
    $readme -match '<!--BEGIN DESCRIPTION-->([\s\S]*)<!--END DESCRIPTION-->' | out-null
    $description = $Matches[1]
    $psd = $psd -replace '--DESCRIPTION--',$description
    write-file $out\$moduleName.psd1 $psd
}
if($publish) {
    $key = read-file publishkey.txt
    $version = get-version
    publish-module -Path $out -NuGetApiKey $key
    # git tag "v$version"
}