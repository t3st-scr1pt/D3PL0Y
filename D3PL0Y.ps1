#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    D3PL0Y v2.0.1

.DESCRIPTION
    Configura un equipo con Windows 11 de forma sencilla y fiable.

    D3PL0Y permite elegir entre dos perfiles:

    T3ST-SCR1PT:
    - Configuración general del equipo.
    - Instala Google Chrome, Google Drive y Tailscale.
    - Aplica los fondos específicos de T3ST-SCR1PT.

    STUD10-SCR1PT:
    - Configuración orientada a edición de imagen, vídeo y música.
    - Instala Google Chrome, Google Drive, Tailscale, Audacity y GIMP.
    - Aplica los fondos específicos de STUD10-SCR1PT.

    Ambos perfiles:
    - Configuran las opciones de energía.
    - Eliminan aplicaciones preinstaladas seleccionadas.
    - Reducen publicidad, sugerencias y telemetría.
    - Aplican el tema oscuro, el color verde y los ajustes del Explorador.
    - Descargan y aplican cursores, fondo de escritorio y pantalla de bloqueo.

.PARAMETER D3PL0YProfile
    Selecciona directamente el perfil T3ST-SCR1PT o STUD10-SCR1PT.
    Si no se indica, D3PL0Y mostrará un menú interactivo.

.PARAMETER NoRestart
    Evita que el equipo se reinicie automáticamente al finalizar.
    Sin este parámetro, el equipo se reiniciará aunque alguna fase termine
    con errores.

.PARAMETER SkipDebloat
    Omite la eliminación de aplicaciones preinstaladas.

.PARAMETER RefreshAssets
    Fuerza la descarga de cursores y fondos aunque ya existan localmente.

.EXAMPLE
    irm https://lavueltitaironica.com/install | iex

.EXAMPLE
    .\D3PL0Y.ps1 -D3PL0YProfile STUD10-SCR1PT

.EXAMPLE
    .\D3PL0Y.ps1 -NoRestart
#>

[CmdletBinding()]
param(
    # No se usa ValidateSet aquí: Windows PowerShell 5.1 intenta validar el
    # valor nulo implícito al ejecutar el script mediante Invoke-Expression.
    # Select-D3PL0YProfile realiza la validación manual de forma compatible.
    [string]$D3PL0YProfile,

    [switch]$NoRestart,
    [switch]$SkipDebloat,
    [switch]$RefreshAssets
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

$ProjectName = 'D3PL0Y'
$Version = '2.0.1'

$RootFolder = 'C:\D3PL0Y'
$LogFolder = Join-Path $RootFolder 'Logs'
$ConfigFolder = Join-Path $RootFolder 'Configs'
$WallpaperFolder = Join-Path $RootFolder 'Wallpapers'
$CursorFolder = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Cursors'
$LockFolder = Join-Path $env:ProgramData 'D3PL0Y'

$RepositoryRaw = 'https://raw.githubusercontent.com/t3st-scr1pt/D3PL0Y/main'

$D3PL0YProfiles = [ordered]@{
    'T3ST-SCR1PT' = [pscustomobject]@{
        DisplayName = 'T3ST-SCR1PT'
        Description = 'D3PL0Y general para equipos de uso diario y administración.'
        Apps = @(
            'Google.Chrome',
            'Google.GoogleDrive',
            'Tailscale.Tailscale'
        )
        AppNames = @(
            'Google Chrome',
            'Google Drive',
            'Tailscale'
        )
        Wallpaper = 't3st-scr1pt.png'
        Lockscreen = 't3st-scr1pt_lockscreen.png'
    }

    'STUD10-SCR1PT' = [pscustomobject]@{
        DisplayName = 'STUD10-SCR1PT'
        Description = 'D3PL0Y para edición de imagen, vídeo y música.'
        Apps = @(
            'Google.Chrome',
            'Google.GoogleDrive',
            'Tailscale.Tailscale',
            'Audacity.Audacity',
            'GIMP.GIMP.3'
        )
        AppNames = @(
            'Google Chrome',
            'Google Drive',
            'Tailscale',
            'Audacity',
            'GIMP'
        )
        Wallpaper = 'stud10-scr1pt.png'
        Lockscreen = 'stud10-scr1pt_lockscreen.png'
    }
}


$StatusFile = Join-Path $LogFolder 'estado.txt'
$SummaryFile = Join-Path $LogFolder 'Resumen.txt'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogFolder ("install-{0}.log" -f $Timestamp)

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:TranscriptStarted = $false
$script:ExplorerNeedsRestart = $false

# =============================================================================
# FUNCIONES
# =============================================================================

function Write-D3PL0YLog
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Color = switch ($Level)
    {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }

    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    Write-Host $Line -ForegroundColor $Color
}

function Set-D3PL0YStatus
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    Set-Content -LiteralPath $StatusFile -Value $Status -Encoding UTF8
}

function Invoke-D3PL0YStep
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor DarkGreen
    Write-Host $Name -ForegroundColor Green
    Write-Host ('=' * 64) -ForegroundColor DarkGreen

    Set-D3PL0YStatus $Name

    try
    {
        & $Action
        $script:SuccessCount++
        Write-D3PL0YLog ('Completado: {0}' -f $Name) 'OK'
        return $true
    }
    catch
    {
        $script:ErrorCount++
        Write-D3PL0YLog ('Error en {0}. {1}' -f $Name, $_.Exception.Message) 'ERROR'
        return $false
    }
}

function Write-D3PL0YWarning
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:WarningCount++
    Write-D3PL0YLog $Message 'WARN'
}

function Test-D3PL0YAdministrator
{
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Set-D3PL0YRegistryValue
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Value,

        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
        [string]$Type = 'DWord'
    )

    if (-not (Test-Path -LiteralPath $Path))
    {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    $CurrentValue = $null
    $PropertyExists = $false

    try
    {
        $CurrentValue = Get-ItemPropertyValue `
            -LiteralPath $Path `
            -Name $Name `
            -ErrorAction Stop

        $PropertyExists = $true
    }
    catch
    {
        $PropertyExists = $false
    }

    $ValuesMatch = $false

    if ($PropertyExists)
    {
        if (($CurrentValue -is [byte[]]) -and ($Value -is [byte[]]))
        {
            $CurrentBase64 = [Convert]::ToBase64String([byte[]]$CurrentValue)
            $ExpectedBase64 = [Convert]::ToBase64String([byte[]]$Value)
            $ValuesMatch = ($CurrentBase64 -eq $ExpectedBase64)
        }
        elseif (($CurrentValue -is [array]) -and ($Value -is [array]))
        {
            $ValuesMatch = (
                (($CurrentValue | ForEach-Object { [string]$_ }) -join "`0") -eq
                (($Value | ForEach-Object { [string]$_ }) -join "`0")
            )
        }
        else
        {
            $ValuesMatch = ([string]$CurrentValue -eq [string]$Value)
        }
    }

    if (-not $ValuesMatch)
    {
        try
        {
            # Set-ItemProperty crea el valor si no existe y lo actualiza si ya existe.
            # Evita el fallo que puede provocar New-ItemProperty al sobrescribir
            # determinados valores existentes del Registro en Windows 11.
            Set-ItemProperty `
                -LiteralPath $Path `
                -Name $Name `
                -Value $Value `
                -Type $Type `
                -Force `
                -ErrorAction Stop
        }
        catch
        {
            throw (
                "No se pudo escribir '{0}' en '{1}' como {2}. {3}" -f
                $Name,
                $Path,
                $Type,
                $_.Exception.Message
            )
        }

        $script:ExplorerNeedsRestart = $true
    }
}

function Invoke-D3PL0YDownload
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [int]$Retries = 3,

        [switch]$Force
    )

    if ((Test-Path -LiteralPath $Destination) -and (-not $Force))
    {
        $ExistingFile = Get-Item -LiteralPath $Destination -ErrorAction SilentlyContinue

        if (($null -ne $ExistingFile) -and ($ExistingFile.Length -gt 0))
        {
            Write-D3PL0YLog ('Ya existe: {0}' -f $Destination)
            return
        }
    }

    $ParentFolder = Split-Path -Parent $Destination

    if (-not (Test-Path -LiteralPath $ParentFolder))
    {
        New-Item -ItemType Directory -Path $ParentFolder -Force | Out-Null
    }

    $TemporaryFile = '{0}.download' -f $Destination
    Remove-Item -LiteralPath $TemporaryFile -Force -ErrorAction SilentlyContinue

    for ($Attempt = 1; $Attempt -le $Retries; $Attempt++)
    {
        try
        {
            Invoke-WebRequest `
                -Uri $Uri `
                -OutFile $TemporaryFile `
                -UseBasicParsing `
                -TimeoutSec 90

            $DownloadedFile = Get-Item -LiteralPath $TemporaryFile -ErrorAction Stop

            if ($DownloadedFile.Length -le 0)
            {
                throw 'El archivo descargado está vacío.'
            }

            Move-Item `
                -LiteralPath $TemporaryFile `
                -Destination $Destination `
                -Force

            Write-D3PL0YLog ('Descargado: {0}' -f $Destination) 'OK'
            return
        }
        catch
        {
            Remove-Item -LiteralPath $TemporaryFile -Force -ErrorAction SilentlyContinue

            if ($Attempt -ge $Retries)
            {
                throw
            }

            Write-D3PL0YWarning (
                'Descarga fallida. Reintento {0} de {1}: {2}' -f
                $Attempt,
                $Retries,
                $Uri
            )

            Start-Sleep -Seconds (3 * $Attempt)
        }
    }
}

function Test-D3PL0YWingetPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    $Output = & winget.exe list `
        --id $Id `
        --exact `
        --accept-source-agreements 2>$null | Out-String

    return (
        ($LASTEXITCODE -eq 0) -and
        ($Output -match [regex]::Escape($Id))
    )
}

function Install-D3PL0YWingetPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    if (Test-D3PL0YWingetPackage -Id $Id)
    {
        Write-D3PL0YLog ('Ya está instalado: {0}' -f $Id) 'OK'
        return
    }

    Write-D3PL0YLog ('Instalando: {0}' -f $Id)

    & winget.exe install `
        --id $Id `
        --exact `
        --silent `
        --disable-interactivity `
        --accept-package-agreements `
        --accept-source-agreements

    $InstallExitCode = $LASTEXITCODE

    if (
        ($InstallExitCode -ne 0) -and
        (-not (Test-D3PL0YWingetPackage -Id $Id))
    )
    {
        throw (
            'WinGet no pudo instalar {0}. Código de salida: {1}' -f
            $Id,
            $InstallExitCode
        )
    }

    Write-D3PL0YLog ('Instalado: {0}' -f $Id) 'OK'
}

function Select-D3PL0YProfile
{
    param(
        [string]$RequestedProfile
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedProfile))
    {
        $NormalizedProfile = $RequestedProfile.Trim().ToUpperInvariant()

        if ($D3PL0YProfiles.Keys -contains $NormalizedProfile)
        {
            return $NormalizedProfile
        }

        throw (
            'Perfil D3PL0Y no válido: {0}. Opciones válidas: {1}' -f
            $RequestedProfile,
            ($D3PL0YProfiles.Keys -join ', ')
        )
    }

    while ($true)
    {
        Write-Host ''
        Write-Host '╔════════════════════════════════════════════════════╗' -ForegroundColor DarkGreen
        Write-Host '║              SELECCIONA EL D3PL0Y                  ║' -ForegroundColor Green
        Write-Host '╠════════════════════════════════════════════════════╣' -ForegroundColor DarkGreen
        Write-Host '║ [1] T3ST-SCR1PT                                    ║' -ForegroundColor Green
        Write-Host '║     Equipo general: Chrome, Drive y Tailscale      ║' -ForegroundColor Gray
        Write-Host '║                                                    ║' -ForegroundColor DarkGreen
        Write-Host '║ [2] STUD10-SCR1PT                                  ║' -ForegroundColor Magenta
        Write-Host '║     Edición: añade Audacity y GIMP                 ║' -ForegroundColor Gray
        Write-Host '║                                                    ║' -ForegroundColor DarkGreen
        Write-Host '║ [0] Cancelar                                       ║' -ForegroundColor Yellow
        Write-Host '╚════════════════════════════════════════════════════╝' -ForegroundColor DarkGreen

        $Choice = Read-Host 'Selecciona una opción'
        $NormalizedChoice = $Choice.Trim().ToUpperInvariant()

        if ($NormalizedChoice -in @('1', 'T3ST', 'T3ST-SCR1PT'))
        {
            return 'T3ST-SCR1PT'
        }

        if ($NormalizedChoice -in @('2', 'STUD10', 'STUD10-SCR1PT'))
        {
            return 'STUD10-SCR1PT'
        }

        if ($NormalizedChoice -in @('0', 'Q', 'S', 'SALIR', 'CANCELAR'))
        {
            return $null
        }

        Write-Host ''
        Write-Host 'Selección no válida. Usa 1, 2 o 0.' -ForegroundColor Red
    }
}

function Restart-D3PL0YExplorer
{
    Write-D3PL0YLog 'Actualizando la configuración visual de Windows.'

    & rundll32.exe user32.dll,UpdatePerUserSystemParameters
    Start-Sleep -Seconds 2

    Stop-Process `
        -Name explorer `
        -Force `
        -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}

# =============================================================================
# PREPARACIÓN
# =============================================================================

foreach ($Folder in @(
    $RootFolder,
    $LogFolder,
    $ConfigFolder,
    $WallpaperFolder,
    $CursorFolder,
    $LockFolder
))
{
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
}

try
{
    Start-Transcript -Path $LogFile -Append | Out-Null
    $script:TranscriptStarted = $true
}
catch
{
    Write-Host 'No se pudo iniciar la transcripción completa.' -ForegroundColor Yellow
}

$Banner = @"

██████╗ ██████╗ ██████╗ ██╗      ██████╗ ██╗   ██╗
██╔══██╗╚════██╗██╔══██╗██║     ██╔═████╗╚██╗ ██╔╝
██║  ██║ █████╔╝██████╔╝██║     ██║██╔██║ ╚████╔╝
██║  ██║ ╚═══██╗██╔═══╝ ██║     ████╔╝██║  ╚██╔╝
██████╔╝██████╔╝██║     ███████╗╚██████╔╝   ██║
╚═════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝    ╚═╝

╔════════════════════════════════════════════════════╗
║                    D3PL0Y                          ║
║                                                    ║
║   Instalación automática de aplicaciones           ║
║   Configuración personalizada de Windows 11         ║
╚════════════════════════════════════════════════════╝

"@

Write-Host $Banner -ForegroundColor Green

$SelectedD3PL0Y = Select-D3PL0YProfile -RequestedProfile $D3PL0YProfile

if ([string]::IsNullOrWhiteSpace($SelectedD3PL0Y))
{
    Set-D3PL0YStatus 'CANCELADO'
    Write-D3PL0YLog 'D3PL0Y cancelado por el usuario.'

    if ($script:TranscriptStarted)
    {
        try
        {
            Stop-Transcript | Out-Null
            $script:TranscriptStarted = $false
        }
        catch
        {
        }
    }

    return
}

$SelectedConfig = $D3PL0YProfiles[$SelectedD3PL0Y]
$InstalledAppSummary = $SelectedConfig.AppNames -join ', '

Set-D3PL0YStatus ('INICIANDO {0}' -f $SelectedD3PL0Y)
Write-D3PL0YLog ('Perfil seleccionado: {0}' -f $SelectedD3PL0Y) 'OK'
Write-D3PL0YLog $SelectedConfig.Description

$Date = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$Computer = $env:COMPUTERNAME
$User = $env:USERNAME

Write-Host '┌────────────────────────────────────────────────────┐' -ForegroundColor DarkGreen
Write-Host '│                  D3PL0Y STATUS                     │' -ForegroundColor DarkGreen
Write-Host '├────────────────────────────────────────────────────┤' -ForegroundColor DarkGreen
Write-Host ('│ HOSTNAME : {0,-38}│' -f $Computer) -ForegroundColor Green
Write-Host ('│ USER     : {0,-38}│' -f $User) -ForegroundColor Green
Write-Host ('│ DATE     : {0,-38}│' -f $Date) -ForegroundColor Green
Write-Host ('│ VERSION  : {0,-38}│' -f ('v{0}' -f $Version)) -ForegroundColor Green
Write-Host ('│ PROFILE  : {0,-38}│' -f $SelectedD3PL0Y) -ForegroundColor Magenta
Write-Host ('│ STATUS   : {0,-38}│' -f 'INITIALIZING') -ForegroundColor Yellow
Write-Host '└────────────────────────────────────────────────────┘' -ForegroundColor DarkGreen

# =============================================================================
# EJECUCIÓN
# =============================================================================

Invoke-D3PL0YStep -Name 'Comprobaciones previas' -Action {

    if (-not (Test-D3PL0YAdministrator))
    {
        throw 'D3PL0Y debe ejecutarse como administrador.'
    }

    $OperatingSystem = Get-CimInstance Win32_OperatingSystem

    if ([version]$OperatingSystem.Version -lt [version]'10.0.22000')
    {
        throw (
            'D3PL0Y requiere Windows 11. Versión detectada: {0}' -f
            $OperatingSystem.Version
        )
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue))
    {
        throw (
            'WinGet no está disponible. Instala o actualiza ' +
            'App Installer desde Microsoft Store.'
        )
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    & winget.exe source update | Out-Null

    if ($LASTEXITCODE -ne 0)
    {
        Write-D3PL0YWarning 'No se pudieron actualizar las fuentes de WinGet.'
    }
} | Out-Null

Invoke-D3PL0YStep -Name 'Configurar energía' -Action {

    $PowerCommands = @(
        @('-h', 'off'),
        @('/change', 'standby-timeout-ac', '0'),
        @('/change', 'monitor-timeout-ac', '0'),
        @('/change', 'standby-timeout-dc', '0'),
        @('/change', 'monitor-timeout-dc', '0')
    )

    foreach ($Arguments in $PowerCommands)
    {
        & powercfg.exe @Arguments | Out-Null

        if ($LASTEXITCODE -ne 0)
        {
            Write-D3PL0YWarning (
                'Powercfg devolvió un error para: {0}' -f
                ($Arguments -join ' ')
            )
        }
    }
} | Out-Null

if (-not $SkipDebloat)
{
    Invoke-D3PL0YStep -Name 'Eliminar aplicaciones preinstaladas' -Action {

        $AppsToRemove = @(
            'Microsoft.XboxApp',
            'Microsoft.XboxGamingOverlay',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.XboxSpeechToTextOverlay',
            'Microsoft.BingNews',
            'Clipchamp.Clipchamp',
            'Microsoft.YourPhone',
            'MicrosoftTeams',
            'MSTeams',
            'Microsoft.GetHelp',
            'Microsoft.Getstarted',
            'Microsoft.WindowsFeedbackHub',
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo',
            'Microsoft.People',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.PowerAutomateDesktop'
        )

        foreach ($Target in $AppsToRemove)
        {
            $FoundPackage = $false

            # Primero se elimina el aprovisionamiento de la imagen de Windows.
            # Así la aplicación no se instalará automáticamente en usuarios nuevos.
            $ProvisionedMatches = @(
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $Target }
            )

            foreach ($Package in $ProvisionedMatches)
            {
                $FoundPackage = $true

                try
                {
                    Remove-AppxProvisionedPackage `
                        -Online `
                        -PackageName $Package.PackageName `
                        -ErrorAction Stop | Out-Null

                    Write-D3PL0YLog (
                        'Desaprovisionado: {0}' -f $Target
                    ) 'OK'
                }
                catch
                {
                    # Algunos builds devuelven "archivo/ruta no encontrada" aunque
                    # el paquete ya haya desaparecido. Se comprueba de nuevo antes
                    # de registrar una advertencia real.
                    $StillProvisioned = @(
                        Get-AppxProvisionedPackage `
                            -Online `
                            -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.PackageName -eq $Package.PackageName
                        }
                    )

                    if ($StillProvisioned.Count -eq 0)
                    {
                        Write-D3PL0YLog (
                            'Ya no estaba aprovisionado: {0}' -f $Target
                        ) 'OK'
                    }
                    else
                    {
                        Write-D3PL0YWarning (
                            'No se pudo desaprovisionar {0}. {1}' -f
                            $Target,
                            $_.Exception.Message
                        )
                    }
                }
            }

            # Después se elimina la aplicación de los perfiles ya existentes.
            # La consulta se hace de nuevo para evitar trabajar con datos obsoletos.
            $InstalledMatches = @(
                Get-AppxPackage `
                    -AllUsers `
                    -Name $Target `
                    -ErrorAction SilentlyContinue
            )

            foreach ($Package in $InstalledMatches)
            {
                $FoundPackage = $true

                try
                {
                    Remove-AppxPackage `
                        -Package $Package.PackageFullName `
                        -AllUsers `
                        -ErrorAction Stop

                    Write-D3PL0YLog ('Eliminado: {0}' -f $Target) 'OK'
                }
                catch
                {
                    $StillInstalled = @(
                        Get-AppxPackage `
                            -AllUsers `
                            -Name $Target `
                            -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.PackageFullName -eq $Package.PackageFullName
                        }
                    )

                    if ($StillInstalled.Count -eq 0)
                    {
                        Write-D3PL0YLog (
                            'Ya no estaba instalado: {0}' -f $Target
                        ) 'OK'
                    }
                    else
                    {
                        Write-D3PL0YWarning (
                            'No se pudo eliminar {0}. {1}' -f
                            $Target,
                            $_.Exception.Message
                        )
                    }
                }
            }

            $RemainingInstalled = @(
                Get-AppxPackage `
                    -AllUsers `
                    -Name $Target `
                    -ErrorAction SilentlyContinue
            )

            $RemainingProvisioned = @(
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $Target }
            )

            if (
                ($RemainingInstalled.Count -eq 0) -and
                ($RemainingProvisioned.Count -eq 0)
            )
            {
                if (-not $FoundPackage)
                {
                    Write-D3PL0YLog ('No estaba instalado: {0}' -f $Target)
                }
            }
            else
            {
                Write-D3PL0YWarning (
                    'Persisten restos de {0}: instalados={1}, aprovisionados={2}' -f
                    $Target,
                    $RemainingInstalled.Count,
                    $RemainingProvisioned.Count
                )
            }
        }
    } | Out-Null
}
else
{
    Write-D3PL0YWarning 'La eliminación de bloatware se ha omitido.'
}

Invoke-D3PL0YStep -Name 'Configurar privacidad y sugerencias' -Action {

    $ContentDeliveryManager =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    foreach ($Property in @(
        'SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled',
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled',
        'SystemPaneSuggestionsEnabled',
        'SilentInstalledAppsEnabled',
        'SoftLandingEnabled'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $ContentDeliveryManager `
            -Name $Property `
            -Value 0 `
            -Type DWord
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' `
        -Name 'TurnOffWindowsCopilot' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' `
        -Name 'AllowTelemetry' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' `
        -Name 'DisableWindowsConsumerFeatures' `
        -Value 1 `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Instalar aplicaciones' -Action {

    $Apps = @($SelectedConfig.Apps)
    $FailedApps = New-Object System.Collections.Generic.List[string]

    foreach ($App in $Apps)
    {
        Set-D3PL0YStatus ('INSTALANDO {0}' -f $App)

        try
        {
            Install-D3PL0YWingetPackage -Id $App
        }
        catch
        {
            $FailedApps.Add($App)
            Write-D3PL0YWarning $_.Exception.Message
        }
    }

    if ($FailedApps.Count -gt 0)
    {
        throw (
            'No se pudieron instalar estas aplicaciones: {0}' -f
            ($FailedApps -join ', ')
        )
    }
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar tema oscuro y configurar Explorador' -Action {

    $Personalize =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'AppsUseLightTheme' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'SystemUsesLightTheme' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Personalize `
        -Name 'ColorPrevalence' `
        -Value 1 `
        -Type DWord

    $ExplorerAdvanced =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'HideFileExt' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Hidden' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'TaskbarAl' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'TaskbarDa' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'ShowTaskViewButton' `
        -Value 0 `
        -Type DWord

    $Search =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

    Set-D3PL0YRegistryValue `
        -Path $Search `
        -Name 'SearchboxTaskbarMode' `
        -Value 0 `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar color de énfasis verde' -Action {

    $Dwm = 'HKCU:\Software\Microsoft\Windows\DWM'

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'AccentColor' `
        -Value 0xFF107C10 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'ColorizationColor' `
        -Value 0xC4107C10 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'EnableWindowColorization' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'ColorPrevalence' `
        -Value 1 `
        -Type DWord

    $Accent =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'

    $AccentPalette = [byte[]](
        0x95,0xEF,0x81,0x00,
        0x45,0xE5,0x32,0x00,
        0x19,0xA1,0x15,0x00,
        0x10,0x7C,0x10,0x00,
        0x0E,0x6D,0x0E,0x00,
        0x08,0x4B,0x08,0x00,
        0x03,0x2B,0x03,0x00,
        0x4C,0x4A,0x48,0x00
    )

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentPalette' `
        -Value $AccentPalette `
        -Type Binary

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentColorMenu' `
        -Value 0xFF107C10 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'StartColorMenu' `
        -Value 0xFF0E6D0E `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar cursores' -Action {

    $CursorMap = [ordered]@{
        Arrow       = 'arrow_eoa.cur'
        AppStarting = 'busy_eoa.cur'
        Crosshair   = 'cross_eoa.cur'
        SizeWE      = 'ew_eoa.cur'
        Help        = 'helpsel_eoa.cur'
        IBeam       = 'ibeam_eoa.cur'
        Hand        = 'link_eoa.cur'
        SizeAll     = 'move_eoa.cur'
        SizeNESW    = 'nesw_eoa.cur'
        SizeNS      = 'ns_eoa.cur'
        SizeNWSE    = 'nwse_eoa.cur'
        NWPen       = 'pen_eoa.cur'
        Person      = 'person_eoa.cur'
        Pin         = 'pin_eoa.cur'
        No          = 'unavail_eoa.cur'
        UpArrow     = 'up_eoa.cur'
        Wait        = 'wait_eoa.cur'
    }

    foreach ($Entry in $CursorMap.GetEnumerator())
    {
        $Destination = Join-Path $CursorFolder $Entry.Value
        $Uri = '{0}/configs/cursors/{1}' -f $RepositoryRaw, $Entry.Value

        Invoke-D3PL0YDownload `
            -Uri $Uri `
            -Destination $Destination `
            -Force:$RefreshAssets

        Set-D3PL0YRegistryValue `
            -Path 'HKCU:\Control Panel\Cursors' `
            -Name $Entry.Key `
            -Value $Destination `
            -Type String
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Cursors' `
        -Name '(Default)' `
        -Value 'D3PL0Y' `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Cursors' `
        -Name 'CursorBaseSize' `
        -Value 48 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Control Panel\Mouse' `
        -Name 'MouseSensitivity' `
        -Value '13' `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorType' `
        -Value 6 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorColor' `
        -Value 65280 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Accessibility' `
        -Name 'CursorSize' `
        -Value 2 `
        -Type DWord

    if (-not ('D3PL0YCursorRefresh' -as [type]))
    {
        Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class D3PL0YCursorRefresh
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(
        uint uiAction,
        uint uiParam,
        IntPtr pvParam,
        uint fWinIni
    );
}
'@
    }

    [D3PL0YCursorRefresh]::SystemParametersInfo(
        0x57,
        0,
        [IntPtr]::Zero,
        0x01 -bor 0x02
    ) | Out-Null
} | Out-Null

Invoke-D3PL0YStep -Name 'Aplicar fondo de escritorio' -Action {

    $WallpaperFile = Join-Path $WallpaperFolder $SelectedConfig.Wallpaper
    $WallpaperUri = '{0}/wallpapers/{1}' -f (
        $RepositoryRaw,
        $SelectedConfig.Wallpaper
    )

    Invoke-D3PL0YDownload `
        -Uri $WallpaperUri `
        -Destination $WallpaperFile `
        -Force:$RefreshAssets

    if (-not ('D3PL0YWallpaper' -as [type]))
    {
        Add-Type @'
using System.Runtime.InteropServices;

public static class D3PL0YWallpaper
{
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(
        int uAction,
        int uParam,
        string lpvParam,
        int fuWinIni
    );
}
'@
    }

    $WallpaperApplied = [D3PL0YWallpaper]::SystemParametersInfo(
        20,
        0,
        $WallpaperFile,
        3
    )

    if (-not $WallpaperApplied)
    {
        throw 'Windows no confirmó la aplicación del fondo de escritorio.'
    }

    Write-D3PL0YLog (
        'Fondo de escritorio aplicado para {0}: {1}' -f
        $SelectedD3PL0Y,
        $SelectedConfig.Wallpaper
    ) 'OK'
} | Out-Null

Invoke-D3PL0YStep -Name 'Configurar pantalla de bloqueo' -Action {

    $LockImage = Join-Path $LockFolder $SelectedConfig.Lockscreen
    $LockUri = '{0}/wallpapers/{1}' -f (
        $RepositoryRaw,
        $SelectedConfig.Lockscreen
    )

    Invoke-D3PL0YDownload `
        -Uri $LockUri `
        -Destination $LockImage `
        -Force:$RefreshAssets

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' `
        -Name 'LockScreenImage' `
        -Value $LockImage `
        -Type String

    Write-D3PL0YLog (
        'La pantalla de bloqueo se aplicará al actualizar la sesión o reiniciar.'
    ) 'OK'
} | Out-Null

Invoke-D3PL0YStep -Name 'Actualizar entorno gráfico' -Action {

    Restart-D3PL0YExplorer
    $script:ExplorerNeedsRestart = $false
} | Out-Null

# =============================================================================
# RESUMEN FINAL
# =============================================================================

$FinalStatus = if ($script:ErrorCount -eq 0)
{
    'COMPLETADO'
}
else
{
    'COMPLETADO CON ERRORES'
}

Set-D3PL0YStatus $FinalStatus

$Summary = @"
=================================
D3PL0Y
=================================

Versión: $Version
Perfil: $SelectedD3PL0Y
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Estado: $FinalStatus
Equipo: $env:COMPUTERNAME
Usuario: $env:USERNAME

Fases completadas: $script:SuccessCount
Avisos: $script:WarningCount
Errores: $script:ErrorCount

Log:
$LogFile

Notas:
- Aplicaciones del perfil: $InstalledAppSummary.
- Fondo de escritorio: $($SelectedConfig.Wallpaper).
- Pantalla de bloqueo: $($SelectedConfig.Lockscreen).
"@

Set-Content `
    -LiteralPath $SummaryFile `
    -Value $Summary `
    -Encoding UTF8

Write-Host ''
Write-Host $Summary -ForegroundColor Green

if ($script:TranscriptStarted)
{
    try
    {
        Stop-Transcript | Out-Null
    }
    catch
    {
    }
}

if (-not $NoRestart)
{
    Write-Host ''
    Write-Host (
        'El equipo se reiniciará en 30 segundos. ' +
        'Ejecuta shutdown /a para cancelarlo.'
    ) -ForegroundColor Yellow

    $RestartComment = 'D3PL0Y v{0} - {1} - {2}' -f (
        $Version,
        $SelectedD3PL0Y,
        $FinalStatus
    )

    & shutdown.exe `
        /r `
        /t 30 `
        /c $RestartComment
}
else
{
    Write-Host 'Reinicio automático omitido mediante -NoRestart.' -ForegroundColor Yellow
}
