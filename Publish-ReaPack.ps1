# ReaPack Auto Publisher Script
# Automates the process of publishing new versions to ReaPack
# Author: Anthony Deneyer
# Usage: .\Publish-ReaPack.ps1

param(
    [string]$CommitMessage = "",
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# Configuration
$SCRIPT_PATH = "Scripts\DM_Ambiance Creator.lua"
$SCRIPT_NAME = "DM_Ambiance Creator"

# Colors for output
$ErrorColor = "Red"
$WarningColor = "Yellow" 
$SuccessColor = "Green"
$InfoColor = "Cyan"

function Write-ColorMessage {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-CurrentVersion {
    # Read current version from script file
    $content = Get-Content $SCRIPT_PATH -Raw
    if ($content -match '@version\s+([\d\.]+)') {
        return $matches[1]
    }
    return $null
}

function Get-NextVersion {
    param([string]$CurrentVersion)
    
    $versionParts = $CurrentVersion.Split('.')
    
    # Increment the last number
    $lastPart = [int]$versionParts[-1] + 1
    $versionParts[-1] = $lastPart.ToString()
    
    return $versionParts -join '.'
}

function Update-ScriptVersion {
    param([string]$NewVersion, [string]$ChangelogEntry)
    
    $content = Get-Content $SCRIPT_PATH -Raw
    
    # Update version
    $content = $content -replace '@version\s+[\d\.]+', "@version $NewVersion"
    
    # Update changelog - insert new version after @changelog line
    $changelogPattern = '(@changelog\s*\n)'
    $newChangelogEntry = "`$1    $NewVersion`n        $ChangelogEntry`n"
    $content = $content -replace $changelogPattern, $newChangelogEntry
    
    # Write back to file
    Set-Content -Path $SCRIPT_PATH -Value $content -NoNewline
    
    Write-ColorMessage "✅ Updated $SCRIPT_PATH to version $NewVersion" $SuccessColor
}

function Test-GitStatus {
    $status = git status --porcelain
    if ($status -and -not $Force) {
        Write-ColorMessage "❌ You have uncommitted changes. Commit them first or use -Force" $ErrorColor
        Write-ColorMessage "Uncommitted files:" $WarningColor
        $status | ForEach-Object { Write-ColorMessage "  $_" $WarningColor }
        return $false
    }
    return $true
}

function Test-ReaPackIndex {
    # Check if reapack-index is available
    try {
        $null = Get-Command reapack-index -ErrorAction Stop
        return $true
    }
    catch {
        Write-ColorMessage "❌ reapack-index not found in PATH" $ErrorColor
        Write-ColorMessage "Please install reapack-index from: https://github.com/cfillion/reapack-index/releases" $InfoColor
        return $false
    }
}

function Update-ReaPackIndex {
    Write-ColorMessage "📦 Updating ReaPack index..." $InfoColor
    
    # Remove old index
    if (Test-Path "index.xml") {
        Remove-Item "index.xml" -Force
        Write-ColorMessage "🗑️ Removed old index.xml" $InfoColor
    }
    
    # Generate new index
    Write-ColorMessage "🔄 Generating new index..." $InfoColor
    $process = Start-Process -FilePath "reapack-index" -ArgumentList "--scan --output index.xml --verbose ." -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-ColorMessage "❌ Failed to generate ReaPack index" $ErrorColor
        return $false
    }
    
    if (-not (Test-Path "index.xml")) {
        Write-ColorMessage "❌ index.xml was not created" $ErrorColor
        return $false
    }
    
    Write-ColorMessage "✅ ReaPack index generated successfully" $SuccessColor
    return $true
}

function Show-VersionInfo {
    param([string]$Version)
    
    # Try to extract changelog for this version from the generated index
    if (Test-Path "index.xml") {
        $indexContent = Get-Content "index.xml" -Raw
        if ($indexContent -match "version name=`"$([regex]::Escape($Version))`".*?<changelog><!\[CDATA\[(.*?)\]\]></changelog>" -and $matches[1]) {
            Write-ColorMessage "📋 Generated changelog for v$Version" $InfoColor
            Write-Host $matches[1] -ForegroundColor Gray
        }
    }
}

# Main execution
Write-ColorMessage "🚀 ReaPack Auto Publisher for $SCRIPT_NAME" $InfoColor
Write-ColorMessage "================================================" $InfoColor

# Pre-flight checks
if (-not (Test-Path $SCRIPT_PATH)) {
    Write-ColorMessage "❌ Script file not found: $SCRIPT_PATH" $ErrorColor
    exit 1
}

if (-not (Test-ReaPackIndex)) {
    exit 1
}

if (-not (Test-GitStatus)) {
    exit 1
}

# Get current version
$currentVersion = Get-CurrentVersion
if (-not $currentVersion) {
    Write-ColorMessage "❌ Could not read current version from $SCRIPT_PATH" $ErrorColor
    exit 1
}

Write-ColorMessage "📍 Current version: $currentVersion" $InfoColor

# Propose next version
$nextVersion = Get-NextVersion $currentVersion
Write-ColorMessage "🔢 Proposed next version: $nextVersion" $InfoColor

$userVersion = Read-Host "Enter version number (press Enter for $nextVersion)"
if ($userVersion) {
    $nextVersion = $userVersion
}

# Get changelog entry
if (-not $CommitMessage) {
    Write-ColorMessage "📝 Enter changelog for version $nextVersion" $InfoColor
    Write-ColorMessage "   (Enter multiple lines, finish with empty line)" $WarningColor
    
    $changelogLines = @()
    do {
        $line = Read-Host
        if ($line) {
            $changelogLines += $line
        }
    } while ($line)
    
    $changelogEntry = $changelogLines -join "`n        "
    if (-not $changelogEntry) {
        Write-ColorMessage "❌ Changelog cannot be empty" $ErrorColor
        exit 1
    }
} else {
    $changelogEntry = $CommitMessage
}

Write-ColorMessage "`n📋 Version $nextVersion will include:" $InfoColor
Write-ColorMessage $changelogEntry $WarningColor

if (-not $DryRun) {
    $confirm = Read-Host "`nProceed with publication? (y/N)"
    if ($confirm -ne "y") {
        Write-ColorMessage "❌ Publication cancelled" $WarningColor
        exit 0
    }
}

# DRY RUN - show what would happen
if ($DryRun) {
    Write-ColorMessage "`n🔍 DRY RUN - Would perform these actions:" $InfoColor
    Write-ColorMessage "1. Update $SCRIPT_PATH to version $nextVersion" $InfoColor
    Write-ColorMessage "2. Add changelog entry: $changelogEntry" $InfoColor
    Write-ColorMessage "3. Commit changes with message: 'Release v$nextVersion'" $InfoColor
    Write-ColorMessage "4. Generate new ReaPack index" $InfoColor
    Write-ColorMessage "5. Commit index and push to origin" $InfoColor
    exit 0
}

# Execute the publication process
try {
    Write-ColorMessage "`n🔄 Starting publication process..." $InfoColor
    
    # 1. Update script version and changelog
    Update-ScriptVersion $nextVersion $changelogEntry
    
    # 2. Commit the script changes
    Write-ColorMessage "📝 Committing script changes..." $InfoColor
    git add $SCRIPT_PATH
    git commit -m "Release v$nextVersion"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed"
    }
    
    # 3. Update ReaPack index
    if (-not (Update-ReaPackIndex)) {
        throw "ReaPack index generation failed"
    }
    
    # 4. Show version info
    Show-VersionInfo $nextVersion
    
    # 5. Commit index and push
    Write-ColorMessage "📤 Committing index and pushing..." $InfoColor
    git add index.xml
    git commit -m "Update ReaPack index for v$nextVersion"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit for index failed"
    }
    
    git push origin main
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed"
    }
    
    Write-ColorMessage "`n🎉 Successfully published $SCRIPT_NAME v$nextVersion!" $SuccessColor
    Write-ColorMessage "🌐 Changes pushed to GitHub" $SuccessColor
    Write-ColorMessage "📦 ReaPack index updated" $SuccessColor
    
} catch {
    Write-ColorMessage "`n❌ Publication failed: $_" $ErrorColor
    Write-ColorMessage "🔄 You may need to manually fix the issues and retry" $WarningColor
    exit 1
}