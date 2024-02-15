#!/opt/microsoft/powershell/7/pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 7.3

[string[]] $netversions = @(
    '6.0',
    '7.0',
    '8.0'
    )

[string[]] $templates = @(
        'console',
        'web',
        'classlib',
        'mstest',
        'xunit',
        'nunit'
        )

[long] $ResultCode = 0


$netversions `
 | ForEach-Object {
    [string] $netversion    =$_
    [string] $framwork      ="net$netversion"
    [string] $sdkVersion    ="$netversion.0"
    Push-Location
    New-Item -Path $framwork -ItemType Directory `
        | Set-Location

    dotnet new globaljson --force --sdk-version $sdkVersion --roll-forward latestFeature
    dotnet --version
    dotnet --info

    $templates `
        | ForEach-Object {
            [string] $template = $_
            [string] $project = "test$template"
            Push-Location
            New-Item -Path $template -ItemType Directory `
             | Set-Location

            dotnet new $template -n $project --framework $framwork
            dotnet build $project --verbosity Minimal

            $ResultCode+=$LASTEXITCODE
            Pop-Location
            Remove-Item -Recurse -Force $template
        }
    Pop-Location
    Remove-Item -Recurse -Force $framwork
 }

 exit $ResultCode