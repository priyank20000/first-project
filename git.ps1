<#
.SYNOPSIS
    Advance Git Automation Script for Linux PowerShell (pwsh)
.DESCRIPTION
    Automates tracking, committing, and pushing with safety checks and logging.
.PARAMETER Message
    Optional commit message. If not provided, script prompts for one.
#>
param (
    [string]$Message
)

# Terminal settings for cleaner output
$ErrorActionPreference = "Stop"
$stdout = [Console]::Out

function Write-Log ($Text, $Color = "White") {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Text" -ForegroundColor $Color
}

try {
    # 1. Check if it's a Git repository
    if (-not (Test-Path .git)) {
        throw "Not a git repository. Please run 'git init' first."
    }

    # 2. Check for changes
    $status = git status --porcelain
    if (-not $status) {
        Write-Log "Everything up-to-date. No changes detected to commit. 🏖️" "Yellow"
        exit 0
    }

    # 3. Handle Commit Message
    if (-not $Message) {
        $Message = Read-Host -Prompt "Enter professional commit message"
        if (-not $Message) {
            $Message = "internal: routine maintenance and auto-update [$(Get-Date -Format 'yyyy-MM-dd')]"
        }
    }

    # 4. Stage Changes
    Write-Log "Staging all working directory changes..." "Cyan"
    git add .

    # 5. Commit Changes
    Write-Log "Creating a local commit snapshot..." "Cyan"
    git commit -m "$Message"

    # 6. Push to Remote
    Write-Log "Pushing local commits upstream to GitHub..." "Cyan"
    
    # Capture push errors cleanly without crashing on normal git warnings
    $ErrorActionPreference = "Continue"
    git push
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed. Verify internet connection, remote tracking, or PAT Token authorization."
    }

    Write-Log "Deployment Pipeline Complete. Code synced to GitHub successfully! 🚀" "Green"

}
catch {
    Write-Log "PIPELINE ERROR: $_" "Red"
    exit 1
}
