param(
    [string]$TerminalPath = "$env:ProgramFiles\MetaTrader 5 Terminal\terminal64.exe",
    [string]$InputsDir = "$PSScriptRoot\..\tests\automation\inputs",
    [string]$ReportsDir = "$PSScriptRoot\..\tests\automation\reports",
    [string]$TesterFilesDir = "$env:APPDATA\MetaQuotes\Terminal\FB9A56D617EDDDFE29EE54EBEFFE96C1\MQL5\Profiles\Tester",
    [string]$ExtraTerminalArgs = ""
    
)

function Resolve-DirectoryPath([string]$path)
{
    if([string]::IsNullOrWhiteSpace($path))
    {
        throw "Path cannot be empty."
    }
    if(Test-Path -Path $path)
    {
        return (Resolve-Path -LiteralPath $path).ProviderPath
    }
    return (Resolve-Path -LiteralPath (New-Item -ItemType Directory -LiteralPath $path -Force).FullName).ProviderPath
}

$InputsDir = Resolve-DirectoryPath $InputsDir
$ReportsDir = Resolve-DirectoryPath $ReportsDir

if(!(Test-Path -Path $TerminalPath))
{
    throw "Terminal executable not found at '$TerminalPath'."
}

$iniFiles = Get-ChildItem -Path $InputsDir -Filter '*.ini' | Sort-Object Name
if($iniFiles.Count -eq 0)
{
    Write-Host "No INI files found under '$InputsDir'. Add your inputs before running the script." -ForegroundColor Yellow
    return
}

if(!(Test-Path -Path $TesterFilesDir))
{
    Write-Host "Tester files directory '$TesterFilesDir' does not exist; report copying will be skipped." -ForegroundColor Yellow
}

foreach($ini in $iniFiles)
{
    $setupFingerprint = @{}
    if(Test-Path -Path $TesterFilesDir)
    {
        Get-ChildItem -Path $TesterFilesDir -Filter '*.htm','*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
            $setupFingerprint[$_.FullName] = $_.LastWriteTimeUtc
        }
    }

    $configArg = "/config:`"$($ini.FullName)`""
    $arguments = @($configArg)
    if(-not [string]::IsNullOrWhiteSpace($ExtraTerminalArgs))
    {
        $arguments += $ExtraTerminalArgs
    }

    Write-Host "Running tester for $($ini.Name) ..."
    $process = Start-Process -FilePath $TerminalPath -ArgumentList $arguments -Wait -PassThru
    if($process.ExitCode -ne 0)
    {
        Write-Warning "Terminal exited with code $($process.ExitCode) for $($ini.Name)."
    }

    if(Test-Path -Path $TesterFilesDir)
    {
        $newFiles = Get-ChildItem -Path $TesterFilesDir -Filter '*.htm','*.xml' | Where-Object {
            -not $setupFingerprint.ContainsKey($_.FullName) -or $_.LastWriteTimeUtc -gt $setupFingerprint[$_.FullName]
        }

        if($newFiles.Count -eq 0)
        {
            Write-Warning "No new report files detected in '$TesterFilesDir' after running $($ini.Name)."
            continue
        }

        foreach($file in $newFiles)
        {
            $timestamp = $file.LastWriteTimeUtc.ToString('yyyyMMddTHHmmssZ')
            $targetBase = "$($ini.BaseName)_$timestamp"
            $targetPath = Join-Path $ReportsDir ("$targetBase$($file.Extension)")
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            Write-Host "Saved report file $($file.Name) to $targetPath"
        }
    }
}
