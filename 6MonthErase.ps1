# 6MonthErase - Automated System Cleanup Utility
# PowerShell script to uninstall programs not used in the last 6 months
# Author: ereezyy
# Version: 1.0.0
# License: MIT

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$DaysThreshold = 180,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludePrograms = @(),
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateRestorePoint = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedReport,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "$env:TEMP\6MonthErase\Reports",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Error", "Warning", "Info", "Debug")]
    [string]$LogLevel = "Info",
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent
)

# Script configuration
$script:Config = @{
    Version = "1.0.0"
    Author = "ereezyy"
    LogPath = "$env:TEMP\6MonthErase\Logs"
    BackupPath = "$env:TEMP\6MonthErase\Backups"
    ConfigPath = ".\config.json"
}

# Protected programs that should never be uninstalled
$script:ProtectedPrograms = @(
    "Windows Security",
    "Microsoft Edge",
    "Windows Media Player",
    "Microsoft Visual C++*",
    "Microsoft .NET*",
    "Windows Defender*",
    "Intel*",
    "NVIDIA*",
    "AMD*",
    "Realtek*"
)

# Initialize logging
function Initialize-Logging {
    if (!(Test-Path $script:Config.LogPath)) {
        New-Item -Path $script:Config.LogPath -ItemType Directory -Force | Out-Null
    }
    
    $script:LogFile = Join-Path $script:Config.LogPath "cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    Write-LogMessage "Info" "6MonthErase v$($script:Config.Version) started"
    Write-LogMessage "Info" "Parameters: DaysThreshold=$DaysThreshold, DryRun=$DryRun, CreateRestorePoint=$CreateRestorePoint"
}

# Logging function
function Write-LogMessage {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $script:LogFile -Value $logEntry
    
    # Write to console based on log level
    $levelPriority = @{ "Error" = 0; "Warning" = 1; "Info" = 2; "Debug" = 3 }
    $currentPriority = $levelPriority[$LogLevel]
    $messagePriority = $levelPriority[$Level]
    
    if ($messagePriority -le $currentPriority -and !$Silent) {
        switch ($Level) {
            "Error" { Write-Host $logEntry -ForegroundColor Red }
            "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
            "Info" { Write-Host $logEntry -ForegroundColor Green }
            "Debug" { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
}

# Load configuration from file if it exists
function Load-Configuration {
    if (Test-Path $script:Config.ConfigPath) {
        try {
            $configData = Get-Content $script:Config.ConfigPath | ConvertFrom-Json
            
            if ($configData.daysThreshold) { $script:DaysThreshold = $configData.daysThreshold }
            if ($configData.excludePrograms) { $script:ExcludePrograms += $configData.excludePrograms }
            if ($configData.logLevel) { $script:LogLevel = $configData.logLevel }
            
            Write-LogMessage "Info" "Configuration loaded from $($script:Config.ConfigPath)"
        }
        catch {
            Write-LogMessage "Warning" "Failed to load configuration: $($_.Exception.Message)"
        }
    }
}

# Create system restore point
function New-SystemRestorePoint {
    if ($CreateRestorePoint -and !$DryRun) {
        try {
            Write-LogMessage "Info" "Creating system restore point..."
            
            # Enable system restore if not enabled
            Enable-ComputerRestore -Drive "C:\"
            
            # Create restore point
            Checkpoint-Computer -Description "6MonthErase - Before cleanup $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
            
            Write-LogMessage "Info" "System restore point created successfully"
        }
        catch {
            Write-LogMessage "Warning" "Failed to create restore point: $($_.Exception.Message)"
        }
    }
}

# Get installed programs with last used date
function Get-InstalledPrograms {
    Write-LogMessage "Info" "Scanning installed programs..."
    
    $programs = @()
    
    # Get programs from Windows Registry
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -and $_.UninstallString } |
                ForEach-Object {
                    $lastUsed = Get-ProgramLastUsed $_.DisplayName
                    
                    $programs += [PSCustomObject]@{
                        Name = $_.DisplayName
                        Version = $_.DisplayVersion
                        Publisher = $_.Publisher
                        InstallDate = $_.InstallDate
                        UninstallString = $_.UninstallString
                        LastUsed = $lastUsed
                        DaysUnused = if ($lastUsed) { (Get-Date) - $lastUsed | Select-Object -ExpandProperty Days } else { $null }
                        Size = $_.EstimatedSize
                    }
                }
        }
        catch {
            Write-LogMessage "Warning" "Error reading registry path $path: $($_.Exception.Message)"
        }
    }
    
    Write-LogMessage "Info" "Found $($programs.Count) installed programs"
    return $programs
}

# Get program last used date from various sources
function Get-ProgramLastUsed {
    param([string]$ProgramName)
    
    try {
        # Try to get from Windows Event Log
        $events = Get-WinEvent -FilterHashtable @{LogName='Application'; ID=1000,1001} -MaxEvents 1000 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -like "*$ProgramName*" } |
            Sort-Object TimeCreated -Descending |
            Select-Object -First 1
        
        if ($events) {
            return $events.TimeCreated
        }
        
        # Try to get from program files modification date
        $programFiles = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}")
        foreach ($path in $programFiles) {
            $programPath = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*$($ProgramName.Split(' ')[0])*" } |
                Select-Object -First 1
            
            if ($programPath) {
                $lastWrite = (Get-ChildItem -Path $programPath.FullName -Recurse -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1).LastWriteTime
                
                if ($lastWrite) {
                    return $lastWrite
                }
            }
        }
        
        return $null
    }
    catch {
        Write-LogMessage "Debug" "Could not determine last used date for $ProgramName"
        return $null
    }
}

# Check if program is protected
function Test-ProtectedProgram {
    param([string]$ProgramName)
    
    $allExclusions = $script:ProtectedPrograms + $ExcludePrograms
    
    foreach ($exclusion in $allExclusions) {
        if ($ProgramName -like $exclusion) {
            return $true
        }
    }
    
    return $false
}

# Uninstall a program
function Uninstall-Program {
    param(
        [PSCustomObject]$Program
    )
    
    if ($DryRun) {
        Write-LogMessage "Info" "[DRY RUN] Would uninstall: $($Program.Name)"
        return $true
    }
    
    try {
        Write-LogMessage "Info" "Uninstalling: $($Program.Name)"
        
        # Parse uninstall string
        $uninstallString = $Program.UninstallString
        
        if ($uninstallString -like "*msiexec*") {
            # MSI uninstall
            $productCode = ($uninstallString -split "/I" -split "/X")[1].Trim()
            $arguments = "/X$productCode /quiet /norestart"
            Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow
        }
        else {
            # Standard uninstaller
            if ($uninstallString -like '*"*') {
                $executable = ($uninstallString -split '"')[1]
                $arguments = ($uninstallString -split '"')[2].Trim()
            }
            else {
                $parts = $uninstallString -split ' ', 2
                $executable = $parts[0]
                $arguments = if ($parts.Length -gt 1) { $parts[1] } else { "" }
            }
            
            # Add silent flags if not present
            if ($arguments -notlike "*silent*" -and $arguments -notlike "*quiet*") {
                $arguments += " /S /silent /quiet"
            }
            
            Start-Process $executable -ArgumentList $arguments -Wait -NoNewWindow
        }
        
        Write-LogMessage "Info" "Successfully uninstalled: $($Program.Name)"
        return $true
    }
    catch {
        Write-LogMessage "Error" "Failed to uninstall $($Program.Name): $($_.Exception.Message)"
        return $false
    }
}

# Generate HTML report
function New-HTMLReport {
    param(
        [array]$AllPrograms,
        [array]$RemovedPrograms,
        [array]$ProtectedPrograms,
        [string]$OutputPath
    )
    
    $reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $totalPrograms = $AllPrograms.Count
    $removedCount = $RemovedPrograms.Count
    $protectedCount = $ProtectedPrograms.Count
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>6MonthErase Cleanup Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { text-align: center; padding: 15px; background-color: #e8f4f8; border-radius: 5px; }
        .stat-number { font-size: 24px; font-weight: bold; color: #2c5aa0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .removed { background-color: #ffebee; }
        .protected { background-color: #e8f5e8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>6MonthErase Cleanup Report</h1>
        <p><strong>Generated:</strong> $reportDate</p>
        <p><strong>Threshold:</strong> $DaysThreshold days</p>
        <p><strong>Mode:</strong> $(if ($DryRun) { "Preview (Dry Run)" } else { "Actual Cleanup" })</p>
    </div>
    
    <div class="summary">
        <div class="stat-box">
            <div class="stat-number">$totalPrograms</div>
            <div>Total Programs</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">$removedCount</div>
            <div>$(if ($DryRun) { "Would Remove" } else { "Removed" })</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">$protectedCount</div>
            <div>Protected</div>
        </div>
    </div>
    
    <h2>$(if ($DryRun) { "Programs That Would Be Removed" } else { "Removed Programs" })</h2>
    <table>
        <tr>
            <th>Program Name</th>
            <th>Version</th>
            <th>Publisher</th>
            <th>Days Unused</th>
            <th>Last Used</th>
        </tr>
"@
    
    foreach ($program in $RemovedPrograms) {
        $lastUsedStr = if ($program.LastUsed) { $program.LastUsed.ToString("yyyy-MM-dd") } else { "Unknown" }
        $html += @"
        <tr class="removed">
            <td>$($program.Name)</td>
            <td>$($program.Version)</td>
            <td>$($program.Publisher)</td>
            <td>$($program.DaysUnused)</td>
            <td>$lastUsedStr</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
    
    <h2>Protected Programs</h2>
    <table>
        <tr>
            <th>Program Name</th>
            <th>Version</th>
            <th>Publisher</th>
            <th>Reason</th>
        </tr>
"@
    
    foreach ($program in $ProtectedPrograms) {
        $html += @"
        <tr class="protected">
            <td>$($program.Name)</td>
            <td>$($program.Version)</td>
            <td>$($program.Publisher)</td>
            <td>Protected Program</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    if (!(Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $reportFile = Join-Path $OutputPath "cleanup_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $html | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-LogMessage "Info" "Report generated: $reportFile"
    return $reportFile
}

# Main execution function
function Start-Cleanup {
    try {
        # Initialize
        Initialize-Logging
        Load-Configuration
        
        Write-LogMessage "Info" "Starting 6MonthErase cleanup process"
        
        # Create restore point
        New-SystemRestorePoint
        
        # Get all installed programs
        $allPrograms = Get-InstalledPrograms
        
        # Filter programs for removal
        $candidatesForRemoval = $allPrograms | Where-Object {
            $_.DaysUnused -ne $null -and 
            $_.DaysUnused -gt $DaysThreshold -and
            !(Test-ProtectedProgram $_.Name)
        }
        
        $protectedPrograms = $allPrograms | Where-Object {
            Test-ProtectedProgram $_.Name
        }
        
        Write-LogMessage "Info" "Found $($candidatesForRemoval.Count) programs unused for more than $DaysThreshold days"
        Write-LogMessage "Info" "Found $($protectedPrograms.Count) protected programs"
        
        # Process removals
        $removedPrograms = @()
        $failedRemovals = @()
        
        foreach ($program in $candidatesForRemoval) {
            if (Uninstall-Program $program) {
                $removedPrograms += $program
            }
            else {
                $failedRemovals += $program
            }
        }
        
        # Generate report
        if ($DetailedReport) {
            $reportFile = New-HTMLReport -AllPrograms $allPrograms -RemovedPrograms $candidatesForRemoval -ProtectedPrograms $protectedPrograms -OutputPath $ReportPath
            
            if (!$Silent) {
                Write-Host "Report generated: $reportFile" -ForegroundColor Cyan
            }
        }
        
        # Summary
        Write-LogMessage "Info" "Cleanup completed successfully"
        Write-LogMessage "Info" "Programs processed: $($candidatesForRemoval.Count)"
        Write-LogMessage "Info" "Successfully $(if ($DryRun) { "identified" } else { "removed" }): $($removedPrograms.Count)"
        Write-LogMessage "Info" "Failed removals: $($failedRemovals.Count)"
        
        if (!$Silent) {
            Write-Host "`n=== 6MonthErase Summary ===" -ForegroundColor Green
            Write-Host "Programs $(if ($DryRun) { "identified for removal" } else { "removed" }): $($removedPrograms.Count)" -ForegroundColor Yellow
            Write-Host "Failed removals: $($failedRemovals.Count)" -ForegroundColor Red
            Write-Host "Protected programs: $($protectedPrograms.Count)" -ForegroundColor Blue
            Write-Host "Log file: $script:LogFile" -ForegroundColor Gray
        }
    }
    catch {
        Write-LogMessage "Error" "Critical error during cleanup: $($_.Exception.Message)"
        throw
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-Cleanup
}

