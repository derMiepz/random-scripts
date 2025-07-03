# Self-elevate the script if required
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process PowerShell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ===== CONFIGURATION =====
$backupRoot = "C:\PATH\TO\BACKUP\FOLDER"  #EXAMPLE "C:\Users\Administrator\Desktop\WGSM Backups"

# Define your servers here
$servers = @(
    @{
        Name = "SET SERVERNAME 1 HERE"
        SourceFolder = "C:\PATH\TO\SERVERFILES" #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\1\serverfiles"
        SaveGamePath = "C:\PATH\TO\SAVEGAME"    #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\1\serverfiles\MotorTown\Saved"
    },
    @{
        Name = "SET SERVERNAME 2 HERE"
        SourceFolder = "C:\PATH\TO\SERVERFILES" #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\2\serverfiles"
        SaveGamePath = "C:\PATH\TO\SAVEGAME"    #EXAMPLE "C:\Users\Administrator\Desktop\WindowsGSM\servers\2\serverfiles\SCUM\Saved"
    }
    # Add more servers as needed
    # !!! IMPORTANT !!!
    # When adding more servers, make sure to add a "," after every bracket --> }, <--
    # Except for the last one or you will get an ERROR.
    # See above, line 16 and 21
)

# ===== FUNCTIONS =====
function Show-MainMenu {
    Clear-Host
    Write-Host "************************************" -ForegroundColor Cyan
    Write-Host "*        WGSM BACKUP UTILITY       *" -ForegroundColor Cyan
    Write-Host "************************************" -ForegroundColor Cyan
    Write-Host "1. Select Server"
    Write-Host "2. Exit"
    Write-Host "`nPress a number key (1-2) to select an option"
}

function Show-ServerMenu {
    param (
        [hashtable]$server
    )
    
    Clear-Host
    Write-Host "************************************" -ForegroundColor Yellow
    Write-Host "*       SERVER: $($server.Name.PadRight(14))     *" -ForegroundColor Yellow
    Write-Host "************************************" -ForegroundColor Yellow
    Write-Host "1. Backup entire server folder (SERVER)"
    Write-Host "2. Backup save-game only (SAVEGAME)"
    Write-Host "3. Restore a backup"
    Write-Host "4. Back to server selection"
    Write-Host "5. Exit"
    Write-Host "`nPress a number key (1-5) to select an option"
}

function Show-ServerSelection {
    Clear-Host
    Write-Host "************************************" -ForegroundColor Green
    Write-Host "*    SELECT SERVER TO MANAGE       *" -ForegroundColor Green
    Write-Host "************************************" -ForegroundColor Green
    for ($i = 0; $i -lt $servers.Count; $i++) {
        Write-Host "$($i+1). $($servers[$i].Name)"
    }
    Write-Host "$($servers.Count+1). Back to Main Menu"
    Write-Host "$($servers.Count+2). Exit"
    Write-Host "`nPress a number key (1-$($servers.Count+2)) to select an option"
}

function Backup-EntireFolder {
    param (
        [hashtable]$server
    )
    
    $serverBackupRoot = Join-Path -Path $backupRoot -ChildPath $server.Name
    $timestamp = Get-Date -Format "dd.MM.yyyy - HH-mm"
    $backupType = "SERVER"
    $folderName = Split-Path $server.SourceFolder -Leaf
    $backupPath = Join-Path -Path $serverBackupRoot -ChildPath "$timestamp - $backupType"
    $targetPath = Join-Path -Path $backupPath -ChildPath $folderName
    
    try {
        # Create directory structure
        if (-not (Test-Path $serverBackupRoot)) {
            New-Item -ItemType Directory -Path $serverBackupRoot | Out-Null
        }
        
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        New-Item -ItemType Directory -Path $targetPath -ErrorAction Stop | Out-Null
        
        Write-Host "`nStarting SERVER backup for $($server.Name)..." -ForegroundColor Yellow
        Write-Host "Source: $($server.SourceFolder)"
        Write-Host "Backup: $targetPath"
        
        robocopy $server.SourceFolder $targetPath /MIR /NFL /NDL /NJH /NJS /R:3 /W:5
        
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "`nSERVER backup completed to: $targetPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: Backup failed - $_" -ForegroundColor Red
    }
    finally {
        Read-Host "`nPress Enter to return to menu"
    }
}

function Backup-SaveGame {
    param (
        [hashtable]$server
    )
    
    if (-not (Test-Path -Path $server.SaveGamePath -PathType Container)) {
        Write-Host "`nSave-game folder not found: $($server.SaveGamePath)" -ForegroundColor Red
        Read-Host "`nPress Enter to continue"
        return
    }

    $serverBackupRoot = Join-Path -Path $backupRoot -ChildPath $server.Name
    $timestamp = Get-Date -Format "dd.MM.yyyy - HH-mm"
    $backupType = "SAVEGAME"
    $folderName = Split-Path $server.SaveGamePath -Leaf
    $backupPath = Join-Path -Path $serverBackupRoot -ChildPath "$timestamp - $backupType"
    $targetPath = Join-Path -Path $backupPath -ChildPath $folderName
    
    try {
        # Create directory structure
        if (-not (Test-Path $serverBackupRoot)) {
            New-Item -ItemType Directory -Path $serverBackupRoot | Out-Null
        }
        
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        New-Item -ItemType Directory -Path $targetPath -ErrorAction Stop | Out-Null
        
        Write-Host "`nStarting SAVEGAME backup for $($server.Name)..." -ForegroundColor Yellow
        Write-Host "Source: $($server.SaveGamePath)"
        Write-Host "Backup: $targetPath"
        
        robocopy $server.SaveGamePath $targetPath /MIR /NFL /NDL /NJH /NJS
        
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "`nSAVEGAME backup completed to: $targetPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: SAVEGAME backup failed - $_" -ForegroundColor Red
    }
    finally {
        Read-Host "`nPress Enter to return to menu"
    }
}

function Restore-Backup {
    param (
        [hashtable]$server
    )
    
    $serverBackupRoot = Join-Path -Path $backupRoot -ChildPath $server.Name
    
    # Create server-specific backup directory if it doesn't exist
    if (-not (Test-Path $serverBackupRoot)) {
        New-Item -ItemType Directory -Path $serverBackupRoot | Out-Null
    }
    
    $backups = Get-ChildItem -Path $serverBackupRoot -Directory | Sort-Object CreationTime -Descending
    if (-not $backups) {
        Write-Host "`nNo backups found for $($server.Name)!" -ForegroundColor Red
        Read-Host "`nPress Enter to continue"
        return
    }

    Write-Host "`nAvailable Backups for $($server.Name):"
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
        if ($selectedBackup.Name -match " - SAVEGAME$") {
            $restorePath = $server.SaveGamePath
            $restoreType = "SAVE-GAME"
            $expectedFolder = Split-Path $server.SaveGamePath -Leaf
        }
        elseif ($selectedBackup.Name -match " - SERVER$") {
            $restorePath = $server.SourceFolder
            $restoreType = "FULL SERVER"
            $expectedFolder = Split-Path $server.SourceFolder -Leaf
        }
        else {
            Write-Host "`nUnknown backup type! Using default restore location." -ForegroundColor Yellow
            $restorePath = $server.SourceFolder
            $restoreType = "GENERIC"
            $expectedFolder = Split-Path $server.SourceFolder -Leaf
        }

        # Find the actual content folder in the backup
        $contentPath = $null
        $backupContent = Get-ChildItem -Path $backupPath -Directory
        
        # Check if we have the expected folder structure
        if ($backupContent.Count -eq 1 -and $backupContent[0].Name -eq $expectedFolder) {
            $contentPath = $backupContent[0].FullName
        }
        # Fallback: use first folder if structure doesn't match
        elseif ($backupContent.Count -ge 1) {
            $contentPath = $backupContent[0].FullName
            Write-Host "`n[!] Using folder '$($backupContent[0].Name)' for restore" -ForegroundColor Yellow
        }
        # Fallback: use root if no folders
        else {
            $contentPath = $backupPath
            Write-Host "`n[!] Backup doesn't contain subfolders - restoring from root" -ForegroundColor Yellow
        }

        # Check if destination exists
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
        Write-Host "Source: $contentPath"
        Write-Host "Destination: $restorePath"
        
        $confirmation = Read-Host "`nConfirm restore? (Y/N)"
        if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
            Write-Host "Restore cancelled" -ForegroundColor Yellow
            Read-Host "`nPress Enter to continue"
            return
        }

        # Perform restore
        Write-Host "`nStarting restore for $($server.Name)..." -ForegroundColor Yellow
        robocopy $contentPath $restorePath /MIR /NFL /NDL /NJH /NJS
        
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

# ===== MAIN PROGRAM =====
try {
    # Set console title
    $Host.UI.RawUI.WindowTitle = "WGSM Backup Utility"
    
    # Set window size for better visibility
    $bufferWidth = [Math]::Max(120, $Host.UI.RawUI.BufferSize.Width)
    $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size ($bufferWidth, 300)
    $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size ($bufferWidth, 40)
    
    # Set colors for better visibility
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host

    :mainLoop do {
        Show-MainMenu
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Character) {
            '1' {
                do {
                    Show-ServerSelection
                    $serverKey = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    $selection = [int]$serverKey.Character - 48  # Convert char to int
                    
                    if ($selection -ge 1 -and $selection -le $servers.Count) {
                        $selectedServer = $servers[$selection-1]
                        
                        :serverLoop do {
                            Show-ServerMenu -server $selectedServer
                            $actionKey = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            
                            switch ($actionKey.Character) {
                                '1' { Backup-EntireFolder -server $selectedServer }
                                '2' { Backup-SaveGame -server $selectedServer }
                                '3' { Restore-Backup -server $selectedServer }
                                '4' { break serverLoop }
                                '5' { 
                                    Write-Host "`nExiting... Thank you for using the WGSM Backup Utility!" -ForegroundColor Cyan
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
                    elseif ($selection -eq ($servers.Count + 1)) {
                        # Back to main menu
                        break
                    }
                    elseif ($selection -eq ($servers.Count + 2)) {
                        Write-Host "`nExiting... Thank you for using the WGSM Backup Utility!" -ForegroundColor Cyan
                        Start-Sleep -Seconds 2
                        exit
                    }
                    else {
                        Write-Host "`nInvalid server selection!" -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                } while ($true)
            }
            '2' { 
                Write-Host "`nExiting... Thank you for using the WGSM Backup Utility!" -ForegroundColor Cyan
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
