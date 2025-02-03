function Ask-Confirm {
    param(
        [string]$prompt
    )
    $response = Read-Host "$prompt [Y/n]"
    return $response -eq '' -or $response -eq 'Y' -or $response -eq 'y'
}

function Install-Package {
    param(
        [string]$packageName
    )
    if (-not (Get-Command $packageName -ErrorAction SilentlyContinue)) {
        if (Ask-Confirm "$packageName ist nicht installiert. Möchten Sie $packageName installieren?") {
            Write-Host "Installiere $packageName..."
            Start-Process -FilePath "powershell.exe" -ArgumentList "Install-Package -Name $packageName -Force" -Wait
        } else {
            exit 1
        }
    }
}

function Get-ServerName {
    while ($true) {
        $SERVER_NAME = Read-Host "Servername"
        if (-not (Test-Path $SERVER_NAME)) {
            return $SERVER_NAME
        }
        Write-Host "Server `"$SERVER_NAME`" existiert bereits, wählen Sie einen anderen Namen"
    }
}

function Get-MinecraftVersion {
    while ($true) {
        $MINECRAFT_VERSION = Read-Host "Minecraft-Version"
        if ($MINECRAFT_VERSION -match '^\d+(\.\d+)*$') {
            return $MINECRAFT_VERSION
        }
        Write-Host "Ungültige Minecraft-Version. Geben Sie eine gültige Version ein (z.B. 1.16, 1.17.1)"
    }
}

function Download-PaperJar {
    param(
        [string]$MINECRAFT_VERSION,
        [string]$SERVER_NAME
    )
    
    $buildsUrl = "https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds"
    $buildsResponse = Invoke-RestMethod -Uri $buildsUrl
    
    Install-Package "jq" # annahme, dass jq auch in PowerShell verwendet werden kann
    
    if (-not ($buildsResponse.PSObject.Properties.Match("builds"))) {
        Write-Host "Keine Builds für die angegebene Version `"$MINECRAFT_VERSION`" gefunden"
        exit 1
    }

    $stableBuilds = $buildsResponse.builds | Where-Object { $_.channel -eq 'default' }
    $latestStableBuild = $stableBuilds | Sort-Object build | Select-Object -Last 1

    if (-not $latestStableBuild) {
        Write-Host "Keine stabile Build für die Version `"$MINECRAFT_VERSION`" gefunden."
        if (Ask-Confirm "Möchten Sie nach experimentellen Builds suchen?") {
            # Suchen nach instabilen Builds
            $experimentalBuilds = $buildsResponse.builds | Where-Object { $_.channel -eq 'experimental' }
            $latestExperimentalBuild = $experimentalBuilds | Sort-Object build | Select-Object -Last 1
            if (-not $latestExperimentalBuild) {
                Write-Host "Keine experimentelle Build für die Version `"$MINECRAFT_VERSION`" gefunden."
                exit 1
            }
            $latestBuild = $latestExperimentalBuild
            $buildType = "experimentell"
        } else {
            exit 1
        }
    } else {
        $latestBuild = $latestStableBuild
        $buildType = "stabil"
        Write-Host "Build für die Version `"$MINECRAFT_VERSION`" gefunden."
    }

    $jarName = "paper-$MINECRAFT_VERSION-$($latestBuild.build).jar"
    $downloadUrl = "https://api.papermc.io/v2/projects/paper/versions/$MINECRAFT_VERSION/builds/$($latestBuild.build)/downloads/$jarName"
    New-Item -ItemType Directory -Path $SERVER_NAME -Force | Out-Null
    Write-Host "Erstellt das Verzeichnis `"$SERVER_NAME`""
    Write-Host "Lade die neueste $buildType-Build für die Version `"$MINECRAFT_VERSION`" herunter..."

    $downloadResponse = Invoke-WebRequest -Uri $downloadUrl -OutFile "$SERVER_NAME/paper.jar"
    if ($downloadResponse.StatusCode -ne 200) {
        Write-Host "Fehler beim Herunterladen von paper.jar von `"$downloadUrl`" status_code: `"$($downloadResponse.StatusCode)`""
        exit 1
    } else {
        Write-Host "paper.jar erfolgreich in das Serververzeichnis heruntergeladen"
        return $true
    }
}

function Accept-Eula {
    $eulaUrl = "https://raw.githubusercontent.com/FreakMediaLP/PaperServerSetup/main/eula.txt"
    
    if (Ask-Confirm "Die EULA akzeptieren (https://aka.ms/MinecraftEULA)?") {
        Invoke-WebRequest -Uri $eulaUrl -OutFile "$SERVER_NAME/eula.txt"
        Write-Host "EULA akzeptiert, eula.txt heruntergeladen"
    } else {
        Set-Content -Path "$SERVER_NAME/eula.txt" -Value "eula=false"
        Write-Host "EULA nicht akzeptiert."
    }
}

function Create-Aliases {
    if (Ask-Confirm "Tmux-Aliase für einfachere Serveroperationen erstellen?") {
        Install-Package "tmux"

        $aliases = @"
# $SERVER_NAME
# Aliase für den Server
alias ${SERVER_NAME}_console='tmux attach -t $SERVER_NAME'
alias ${SERVER_NAME}_start='tmux new-session -d -s $SERVER_NAME "cd $PWD\$SERVER_NAME && java -Xms2G -Xmx6G -jar paper.jar"'
alias ${SERVER_NAME}_kill='tmux send-keys -t $SERVER_NAME "stop" Enter'
alias ${SERVER_NAME}_restart='${SERVER_NAME}_kill && while tmux has-session -t $SERVER_NAME 2>$null; do Start-Sleep -Seconds 1; done && ${SERVER_NAME}_start'
"@

        Add-Content -Path "$HOME\.bashrc" -Value $aliases
        Write-Host "Folgende Aliase hinzugefügt:"
        Write-Host "${SERVER_NAME}_console:   öffnet die Serverkonsole (tmux-Sitzung)"
        Write-Host "${SERVER_NAME}_start:     startet den Server (mit angegebenen RAM-Beschränkungen)"
        Write-Host "${SERVER_NAME}_kill:      stoppt den Server"
        Write-Host "${SERVER_NAME}_restart:   stoppt und startet den Server"
    } else {
        Write-Host "Keine Aliase erstellt"
    }
}

# initial setup logic
$serverCreated = $false
$SERVER_NAME = Get-ServerName
$MINECRAFT_VERSION = Get-MinecraftVersion
$serverCreated = Download-PaperJar -MINECRAFT_VERSION $MINECRAFT_VERSION -SERVER_NAME $SERVER_NAME

if ($serverCreated) {
    Accept-Eula
    Create-Aliases
}
