param(
    [Parameter(Mandatory = $true)]
    [string] $Civ5Path,

    [ValidateSet('Package Only', 'Default')]
    [string] $Configuration = 'Package Only',

    [string] $Civ5UserPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "My Games/Sid Meier's Civilization 5")
)

$ErrorActionPreference = 'Stop'
$msbuild = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/MSBuild.exe'
$sdkTargets = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'MSBuild/Firaxis/ModBuddy/Civ5Mod.targets'
if (!(Test-Path -LiteralPath $msbuild) -or !(Test-Path -LiteralPath $sdkTargets)) {
    throw 'Install the Civilization V SDK and initialize ModBuddy to register its MSBuild targets.'
}
if (!(Test-Path -LiteralPath $Civ5Path -PathType Container)) {
    throw "Civilization V installation directory not found: $Civ5Path"
}
$project = Join-Path $PSScriptRoot '../CoolWackyCivs4.civ5proj'
& $msbuild $project /nologo /t:Deploy "/p:Configuration=$Configuration" "/p:Civ5Path=$Civ5Path" "/p:Civ5UserPath=$Civ5UserPath"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
