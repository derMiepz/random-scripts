# Self-elevate the script if required
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process PowerShell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$backupRoot = "C:\PATH\TO\BACKUP\FOLDER"    #EXAMPLE "C:\Users\Administrator\Desktop\MT Backups"
$sourceFolder = "C:\PATH\TO\MT\SERVERFILES" #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\1\serverfiles"
$saveGamePath = "C:\PATH\TO\MT\SAVEGAME"    #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\1\serverfiles\MotorTown\Saved"

function Show-Menu {
    Clear-Host
    Write-Host "************************************"
    Write-Host "*       FILE BACKUP UTILITY        *" -ForegroundColor Cyan
    Write-Host "************************************"
    Write-Host "1. Backup entire folder"
    Write-Host "2. Backup save-game only"
    Write-Host "3. Restore a backup"
    Write-Host "4. Exit"
    Write-Host "`nPress a number key (1-4) to select an option"
}

function Backup-EntireFolder {
    $timestamp = Get-Date -Format "dd.MM.yyyy - HH-mm"
    $backupPath = Join-Path -Path $backupRoot -ChildPath $timestamp
    
    try {
        New-Item -ItemType Directory -Path $backupPath -ErrorAction Stop | Out-Null
        Write-Host "`nStarting backup..." -ForegroundColor Yellow
        robocopy $sourceFolder $backupPath /MIR /NFL /NDL /NJH /NJS /R:3 /W:5
        
        # Validate robocopy exit code
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "`nBackup completed successfully to: $backupPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: Backup failed - $_" -ForegroundColor Red
    }
    finally {
        Read-Host "`nPress Enter to return to menu"
    }
}

function Backup-SaveGame {
    if (-not (Test-Path -Path $saveGamePath -PathType Container)) {
        Write-Host "`nSave-game folder not found: $saveGamePath" -ForegroundColor Red
        Read-Host "`nPress Enter to continue"
        return
    }

    $folderName = Split-Path $saveGamePath -Leaf
    $timestamp = Get-Date -Format "dd.MM.yyyy - HH-mm"
    $backupPath = Join-Path -Path $backupRoot -ChildPath "$timestamp - $folderName"
    
    try {
        New-Item -ItemType Directory -Path $backupPath -ErrorAction Stop | Out-Null
        Write-Host "`nStarting save-game backup..." -ForegroundColor Yellow
        robocopy $saveGamePath $backupPath /MIR /NFL /NDL /NJH /NJS
        
        # Validate robocopy exit code
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "`nSave-game backup completed to: $backupPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: Save-game backup failed - $_" -ForegroundColor Red
    }
    finally {
        Read-Host "`nPress Enter to return to menu"
    }
}

function Restore-Backup {
    $backups = Get-ChildItem -Path $backupRoot -Directory | Sort-Object CreationTime -Descending
    if (-not $backups) {
        Write-Host "`nNo backups found!" -ForegroundColor Red
        Read-Host "`nPress Enter to continue"
        return
    }

    Write-Host "`nAvailable Backups:"
    $i = 1
    $backups | ForEach-Object {
        Write-Host "$i. $($_.Name)"
        $i++
    }

    $choice = Read-Host "`nSelect backup to restore (1-$($backups.Count))"
    if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $backups.Count) {
        $selectedBackup = $backups[$choice-1]
        $backupPath = $selectedBackup.FullName
        
        # Determine restore type based on folder name pattern
        if ($selectedBackup.Name -match " - Saved$") {
            $restorePath = $saveGamePath
            $restoreType = "SAVE-GAME"
        }
        else {
            $restorePath = $sourceFolder
            $restoreType = "FULL SERVER"
        }

        # Check if destination exists
        $pathMissing = $false
        if (-not (Test-Path $restorePath -PathType Container)) {
            Write-Host "`n[!] Destination folder not found: $restorePath" -ForegroundColor Yellow
            $createFolder = Read-Host "Would you like to create this folder? (Y/N)"
            
            if ($createFolder -in @('Y','y')) {
                try {
                    New-Item -ItemType Directory -Path $restorePath -Force -ErrorAction Stop | Out-Null
                    Write-Host "Folder created successfully." -ForegroundColor Green
                }
                catch {
                    Write-Host "`nERROR: Failed to create folder - $_" -ForegroundColor Red
                    Read-Host "`nPress Enter to continue"
                    return
                }
            }
            else {
                Write-Host "Restore cancelled." -ForegroundColor Yellow
                Read-Host "`nPress Enter to continue"
                return
            }
        }

        # Show restore confirmation
        Write-Host "`n[!] WARNING: This will replace all contents in the destination!" -ForegroundColor Red
        Write-Host "Restore type: $restoreType"
        Write-Host "Backup: $($selectedBackup.Name)"
        Write-Host "Destination: $restorePath"
        
        $confirmation = Read-Host "`nConfirm restore? (Y/N)"
        if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
            Write-Host "Restore cancelled" -ForegroundColor Yellow
            Read-Host "`nPress Enter to continue"
            return
        }

        # Perform restore
        Write-Host "`nStarting restore..." -ForegroundColor Yellow
        robocopy $backupPath $restorePath /MIR /NFL /NDL /NJH /NJS
        
        if ($LASTEXITCODE -ge 8) {
            Write-Host "`nERROR: Restore failed! Robocopy exit code: $LASTEXITCODE" -ForegroundColor Red
        }
        else {
            Write-Host "`nRestore completed to: $restorePath" -ForegroundColor Green
        }
    }
    else {
        Write-Host "`nInvalid selection!" -ForegroundColor Red
    }
    Read-Host "`nPress Enter to return to menu"
}

# Main program
try {
    # Set console title
    $Host.UI.RawUI.WindowTitle = "Server Backup Utility"
    
    # Set window size for better visibility
    $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (120, 300)
    $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size (120, 40)
    
    # Set colors for better visibility
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host

    do {
        Show-Menu
        # Get single key press without requiring Enter
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Character) {
            '1' { Backup-EntireFolder }
            '2' { Backup-SaveGame }
            '3' { Restore-Backup }
            '4' { 
                Write-Host "`nExiting... Thank you for using the Backup Utility!" -ForegroundColor Cyan
                Start-Sleep -Seconds 2
                exit 
            }
            default { 
                Write-Host "`nInvalid option! Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}
catch {
    Write-Host "`nFatal Error: $_" -ForegroundColor Red
    Write-Host "`nThe application will now close."
    Start-Sleep -Seconds 5
}
