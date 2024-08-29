# Variables for Telegram
$token = "Do you think I'm stupid?"
$chatId = "I'm not dumb"

# Environment variables to make paths dynamic
$envUserProfile = [System.Environment]::GetFolderPath("UserProfile")
$envSystemRoot = [System.Environment]::GetFolderPath("Windows")
$envAppDataRoaming = [System.Environment]::GetFolderPath("ApplicationData")  # Path to AppData\Roaming
$envAppDataLocal = [System.Environment]::GetFolderPath("LocalApplicationData")  # Path to AppData\Local

# List of paths to exclude (using environment variables)
$excludedPaths = @(
    "$envUserProfile\Documents",
    "$envSystemRoot\Temp",
    "$envSystemRoot\System32",
    "$envAppDataRoaming",
    "$envAppDataLocal",
    "C:\Program Files"
    "C:\Windows\Prefetch"
    # Add other paths here, using environment variables if necessary
)

# List of disks to monitor
$pathsToMonitor = @(
    "C:\",
    "D:\",
    "E:\"
)

# Function to obtain system information
function Get-SystemInfo {
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.Address -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    $publicIP = (Invoke-RestMethod -Uri "http://api.ipify.org").ip
    $hostname = [System.Net.Dns]::GetHostName()
    $username = [System.Environment]::UserName
    $dateTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    return @{
        LocalIP = $localIP
        PublicIP = $publicIP
        Hostname = $hostname
        Username = $username
        DateTime = $dateTime
    }
}

function Send-TelegramMessage {
    param (
        [string]$message
    )
    $systemInfo = Get-SystemInfo
        $token = "Do you think I'm stupid?"
        $chatId = "I'm not dumb"
        $url = "https://api.telegram.org/bot$token/sendMessage"
        $params = @{
            chat_id = $chatId
            text = "$message`n____________________________________________`nSystem information:`n" +
                   "Local IP address : $($systemInfo.LocalIP)`n" +
                   "Public IP address : $($systemInfo.PublicIP)`n" +
                   "Computer name : $($systemInfo.Hostname)`n" +
                   "User account : $($systemInfo.Username)`n" +
                   "Date and time : $($systemInfo.DateTime)`n `n"
        }
        try {
            $response =  Invoke-RestMethod -Uri $url -Method Post -ContentType "application/x-www-form-urlencoded" -Body $params
        if ($response.ok) {
            Write-Host "Message sent successfully"
        } else {
            Write-Host "Message failed to send : $($response.description)"
        }
        } catch {
            Write-Error "Failed to send message: $_"
        }
}

# Function to determine whether a notification should be sent
function Should-Notify {
    param (
        [string]$filePath
    )
    foreach ($excludedPath in $excludedPaths) {
        if ($filePath.ToLower().StartsWith($excludedPath.ToLower())) {
            return $false
        }
    }
    return $true
}

# Function to read the contents of a file
function Get-FileContent {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        return Get-Content -Path $filePath -Raw
    }
    return ""
}

# Function to compare two file contents
function Compare-FileContents {
    param (
        [string]$oldContent,
        [string]$newContent
    )
    # Use diff to obtain differences between files
    $diff = diff -OldFile $oldContent -NewFile $newContent -Differences
    return $diff
}

# Function to monitor a given path
function Start-FileSystemWatcher {
    param (
        [string]$pathToMonitor
    )
    
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $pathToMonitor
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Dictionary to store file contents before editing
    $fileContents = @{}

    # Event management
    Register-ObjectEvent $watcher Created -SourceIdentifier "$pathToMonitor-Created" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $fileContents[$filePath] = Get-FileContent $filePath
            Send-TelegramMessage "A file has been created : $filePath"
        }
    }

    Register-ObjectEvent $watcher Deleted -SourceIdentifier "$pathToMonitor-Deleted" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $fileContents.Remove($filePath)
            Send-TelegramMessage "A file has been deleted : $filePath"
        }
    }

    Register-ObjectEvent $watcher Changed -SourceIdentifier "$pathToMonitor-Changed" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $newContent = Get-FileContent $filePath
            if ($fileContents.ContainsKey($filePath)) {
                $oldContent = $fileContents[$filePath]
                $diff = Compare-FileContents -oldContent $oldContent -newContent $newContent
                Send-TelegramMessage "A file has been modified : $filePath`nDifférences : $diff"
            }
            $fileContents[$filePath] = $newContent
        }
    }

    Register-ObjectEvent $watcher Renamed -SourceIdentifier "$pathToMonitor-Renamed" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $oldPath = $event.SourceEventArgs.OldFullPath
            $newPath = $event.SourceEventArgs.FullPath
            if ($fileContents.ContainsKey($oldPath)) {
                $content = $fileContents[$oldPath]
                $fileContents.Remove($oldPath)
                $fileContents[$newPath] = $content
            }
            Send-TelegramMessage "A file has been renamed : $oldPath -> $newPath"
        }
    }
}

# Start-up alert
Send-TelegramMessage "The system has started up : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# System monitoring for shutdown
Register-WmiEvent -Query "SELECT * FROM Win32_ComputerShutdownEvent" -Action {
    Send-TelegramMessage "The system has stopped : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "ShutdownAlert"

# System monitoring for hibernation/standby
Register-WmiEvent -Query "SELECT * FROM Win32_PowerManagementEvent WHERE EventType = 7" -Action {
    Send-TelegramMessage "Computer enters standby mode : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "SleepAlert"

# System monitoring for standby output
Register-WmiEvent -Query "SELECT * FROM Win32_PowerManagementEvent WHERE EventType = 10" -Action {
    Send-TelegramMessage "Computer wakes up from sleep : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "WakeAlert"

# Start monitoring for each specified disk
foreach ($path in $pathsToMonitor) {
    Start-FileSystemWatcher -pathToMonitor $path
}

# To keep the script running
Write-Host "Monitoring in progress... Press Ctrl+C to stop."
while ($true) {
    Start-Sleep -Seconds 1
}