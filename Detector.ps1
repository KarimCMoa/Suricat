# Variables pour Telegram
$token = "Do you think I'm stupid?"
$chatId = "I'm not dumb"

# Variables d'environnement pour rendre les chemins dynamiques
$envUserProfile = [System.Environment]::GetFolderPath("UserProfile")
$envSystemRoot = [System.Environment]::GetFolderPath("Windows")
$envAppDataRoaming = [System.Environment]::GetFolderPath("ApplicationData")  # Chemin vers AppData\Roaming
$envAppDataLocal = [System.Environment]::GetFolderPath("LocalApplicationData")  # Chemin vers AppData\Local

# Liste des chemins à exclure (utilisation de variables d'environnement)
$excludedPaths = @(
    "$envUserProfile\Documents",
    "$envSystemRoot\Temp",
    "$envSystemRoot\System32",
    "$envAppDataRoaming",
    "$envAppDataLocal",
    "C:\Program Files"
    "C:\Windows\Prefetch"
    # Ajoutez d'autres chemins ici, utilisez des variables d'environnement si nécessaire
)

# Liste des disques à surveiller
$pathsToMonitor = @(
    "C:\",
    "D:\",
    "E:\"
)

# Fonction pour obtenir les informations système
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
            text = "$message`n____________________________________________`nInformations système:`n" +
                   "Adresse IP locale : $($systemInfo.LocalIP)`n" +
                   "Adresse IP publique : $($systemInfo.PublicIP)`n" +
                   "Nom de l'ordinateur : $($systemInfo.Hostname)`n" +
                   "Compte utilisateur : $($systemInfo.Username)`n" +
                   "Date et Heure : $($systemInfo.DateTime)`n `n"
        }
        try {
            $response =  Invoke-RestMethod -Uri $url -Method Post -ContentType "application/x-www-form-urlencoded" -Body $params
        if ($response.ok) {
            Write-Host "Message envoyé avec succès"
        } else {
            Write-Host "Échec de l'envoi du message : $($response.description)"
        }
        } catch {
            Write-Error "Failed to send message: $_"
        }
}

# Fonction pour déterminer si une notification doit être envoyée
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

# Fonction pour lire le contenu d'un fichier
function Get-FileContent {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        return Get-Content -Path $filePath -Raw
    }
    return ""
}

# Fonction pour comparer deux contenus de fichiers
function Compare-FileContents {
    param (
        [string]$oldContent,
        [string]$newContent
    )
    # Utilise diff pour obtenir les différences entre les fichiers
    $diff = diff -OldFile $oldContent -NewFile $newContent -Differences
    return $diff
}

# Fonction pour surveiller un chemin donné
function Start-FileSystemWatcher {
    param (
        [string]$pathToMonitor
    )
    
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $pathToMonitor
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Dictionnaire pour stocker les contenus des fichiers avant modification
    $fileContents = @{}

    # Gestion des événements
    Register-ObjectEvent $watcher Created -SourceIdentifier "$pathToMonitor-Created" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $fileContents[$filePath] = Get-FileContent $filePath
            Send-TelegramMessage "Un fichier a été créé : $filePath"
        }
    }

    Register-ObjectEvent $watcher Deleted -SourceIdentifier "$pathToMonitor-Deleted" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $fileContents.Remove($filePath)
            Send-TelegramMessage "Un fichier a été supprimé : $filePath"
        }
    }

    Register-ObjectEvent $watcher Changed -SourceIdentifier "$pathToMonitor-Changed" -Action {
        if (Should-Notify $event.SourceEventArgs.FullPath) {
            $filePath = $event.SourceEventArgs.FullPath
            $newContent = Get-FileContent $filePath
            if ($fileContents.ContainsKey($filePath)) {
                $oldContent = $fileContents[$filePath]
                $diff = Compare-FileContents -oldContent $oldContent -newContent $newContent
                Send-TelegramMessage "Un fichier a été modifié : $filePath`nDifférences : $diff"
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
            Send-TelegramMessage "Un fichier a été renommé : $oldPath -> $newPath"
        }
    }
}

# Alerte au démarrage
Send-TelegramMessage "Le système a démarré : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Surveillance du système pour l'arrêt
Register-WmiEvent -Query "SELECT * FROM Win32_ComputerShutdownEvent" -Action {
    Send-TelegramMessage "Le système s'est arrêté : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "ShutdownAlert"

# Surveillance du système pour l'hibernation/veille
Register-WmiEvent -Query "SELECT * FROM Win32_PowerManagementEvent WHERE EventType = 7" -Action {
    Send-TelegramMessage "L'ordinateur entre en veille : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "SleepAlert"

# Surveillance du système pour la sortie de veille
Register-WmiEvent -Query "SELECT * FROM Win32_PowerManagementEvent WHERE EventType = 10" -Action {
    Send-TelegramMessage "L'ordinateur sort de veille : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} -SourceIdentifier "WakeAlert"

# Démarrage de la surveillance pour chaque disque spécifié
foreach ($path in $pathsToMonitor) {
    Start-FileSystemWatcher -pathToMonitor $path
}

# Pour garder le script en cours d'exécution
Write-Host "Surveillance en cours... Appuyez sur Ctrl+C pour arrêter."
while ($true) {
    Start-Sleep -Seconds 1
}