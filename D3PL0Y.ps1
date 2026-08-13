#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    D3PL0Y v2.1.3

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
    - Desinstalan OneDrive y eliminan To Do, Xbox/Xbox Live y bloatware.
    - Reducen publicidad, sugerencias y telemetría.
    - Desactivan Widgets, Game DVR, búsquedas web y experiencias promocionales.
    - Aplican ajustes seguros de productividad y privacidad en Windows 11.
    - Usan una paleta verde en T3ST y morada en STUD10.
    - Descargan y aplican cursores, fondo de escritorio y pantalla de bloqueo.

.PARAMETER D3PL0YProfile
    Selecciona directamente el perfil T3ST-SCR1PT o STUD10-SCR1PT.
    Si no se indica, D3PL0Y mostrará un menú interactivo.

.PARAMETER NoRestart
    Evita que el equipo se reinicie automáticamente al finalizar.
    Sin este parámetro, el equipo se reiniciará aunque alguna fase termine
    con errores.

.PARAMETER SkipDebloat
    Omite la desinstalación de OneDrive y de aplicaciones preinstaladas.

.PARAMETER RefreshAssets
    Fuerza la descarga de cursores aunque ya existan localmente.
    Los fondos se actualizan siempre para asegurar la versión del repositorio.

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
$Version = '2.1.3'

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
        ThemeName = 'verde T3ST'
        PrimaryColor = '#107C10'
        SecondaryColor = '#0E6D0E'
        SoftColor = '#81EF95'
        AccentColor = 0xFF107C10
        ColorizationColor = 0xC4107C10
        AccentColorMenu = 0xFF107C10
        StartColorMenu = 0xFF0E6D0E
        AccentPalette = [byte[]](
            0x95,0xEF,0x81,0x00,
            0x45,0xE5,0x32,0x00,
            0x19,0xA1,0x15,0x00,
            0x10,0x7C,0x10,0x00,
            0x0E,0x6D,0x0E,0x00,
            0x08,0x4B,0x08,0x00,
            0x03,0x2B,0x03,0x00,
            0x4C,0x4A,0x48,0x00
        )
        UiColor = 'Green'
        UiDarkColor = 'DarkGreen'
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
        ThemeName = 'LVI Music STUD10'
        PrimaryColor = '#A922FB'
        SecondaryColor = '#68159C'
        SoftColor = '#F1D7FF'
        AccentColor = 0xFFFB22A9
        ColorizationColor = 0xC4FB22A9
        AccentColorMenu = 0xFFFB22A9
        StartColorMenu = 0xFFFB22A9
        AccentPalette = [byte[]](
            0xFF,0xD7,0xF1,0x00,
            0xFF,0xA1,0xDF,0x00,
            0xFD,0x5B,0xC6,0x00,
            0xFB,0x22,0xA9,0x00,
            0xD0,0x1C,0x8C,0x00,
            0x9C,0x15,0x68,0x00,
            0x65,0x0D,0x43,0x00,
            0x4C,0x4A,0x48,0x00
        )
        UiColor = 'Magenta'
        UiDarkColor = 'DarkMagenta'
    }
}


$StatusFile = Join-Path $LogFolder 'estado.txt'
$SummaryFile = Join-Path $LogFolder 'Resumen.txt'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogFolder ("install-{0}.log" -f $Timestamp)

$script:SuccessCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:FailedSteps = New-Object System.Collections.Generic.List[string]
$script:TranscriptStarted = $false
$script:ExplorerNeedsRestart = $false
$script:UiColor = 'Green'
$script:UiDarkColor = 'DarkGreen'

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
        'OK'    { $script:UiColor }
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
    Write-Host ('=' * 64) -ForegroundColor $script:UiDarkColor
    Write-Host $Name -ForegroundColor $script:UiColor
    Write-Host ('=' * 64) -ForegroundColor $script:UiDarkColor

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
        $Failure = '{0}: {1}' -f $Name, $_.Exception.Message
        $script:FailedSteps.Add($Failure)
        Write-D3PL0YLog ('Error en {0}' -f $Failure) 'ERROR'
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

    # Consultar una propiedad inexistente con Get-ItemPropertyValue y
    # ErrorAction Stop deja falsos errores en la transcripción. Esta consulta
    # permite distinguir creación y actualización sin ensuciar el registro.
    $CurrentProperties = Get-ItemProperty `
        -LiteralPath $Path `
        -Name $Name `
        -ErrorAction SilentlyContinue

    if ($null -ne $CurrentProperties)
    {
        $CurrentProperty = $CurrentProperties.PSObject.Properties[$Name]

        if ($null -ne $CurrentProperty)
        {
            $CurrentValue = $CurrentProperty.Value
            $PropertyExists = $true
        }
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
            if ($PropertyExists)
            {
                Set-ItemProperty `
                    -LiteralPath $Path `
                    -Name $Name `
                    -Value $Value `
                    -Force `
                    -ErrorAction Stop
            }
            else
            {
                New-ItemProperty `
                    -LiteralPath $Path `
                    -Name $Name `
                    -Value $Value `
                    -PropertyType $Type `
                    -Force `
                    -ErrorAction Stop | Out-Null
            }
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

function Assert-D3PL0YPngFile
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf))
    {
        throw ('No existe la imagen descargada: {0}' -f $Path)
    }

    $ExpectedSignature = [byte[]](
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    )

    $Stream = [System.IO.File]::OpenRead($Path)

    try
    {
        if ($Stream.Length -lt $ExpectedSignature.Length)
        {
            throw ('La imagen PNG está vacía o incompleta: {0}' -f $Path)
        }

        foreach ($ExpectedByte in $ExpectedSignature)
        {
            if ($Stream.ReadByte() -ne $ExpectedByte)
            {
                throw ('El archivo descargado no es un PNG válido: {0}' -f $Path)
            }
        }
    }
    finally
    {
        $Stream.Dispose()
    }
}

function Set-D3PL0YCurrentUserLockScreen
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $StorageFileType = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]

    $AsyncOperationMethod = @(
        [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            ($_.Name -eq 'AsTask') -and
            ($_.GetParameters().Count -eq 1) -and
            ($_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1')
        }
    )[0]

    $AsyncActionMethod = @(
        [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            ($_.Name -eq 'AsTask') -and
            ($_.GetParameters().Count -eq 1) -and
            ($_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction')
        }
    )[0]

    if (($null -eq $AsyncOperationMethod) -or ($null -eq $AsyncActionMethod))
    {
        throw 'No se encontraron los adaptadores asíncronos de Windows Runtime.'
    }

    $GetFileOperation = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]::GetFileFromPathAsync($Path)
    $GetFileTaskMethod = $AsyncOperationMethod.MakeGenericMethod($StorageFileType)
    $GetFileTask = $GetFileTaskMethod.Invoke($null, @($GetFileOperation))
    $GetFileTask.Wait()
    $StorageFile = $GetFileTask.Result

    $SetImageAction = [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]::SetImageFileAsync($StorageFile)
    $SetImageTask = $AsyncActionMethod.Invoke($null, @($SetImageAction))
    $SetImageTask.Wait()
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

function Remove-D3PL0YAppxPackage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $FoundPackage = $false

    # Se elimina primero el aprovisionamiento para impedir que Windows vuelva
    # a instalar la aplicación al crear usuarios nuevos.
    $ProvisionedMatches = @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $Name }
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

            Write-D3PL0YLog ('Desaprovisionado: {0}' -f $Name) 'OK'
        }
        catch
        {
            $StillProvisioned = @(
                Get-AppxProvisionedPackage `
                    -Online `
                    -ErrorAction SilentlyContinue |
                Where-Object { $_.PackageName -eq $Package.PackageName }
            )

            if ($StillProvisioned.Count -eq 0)
            {
                Write-D3PL0YLog ('Ya no estaba aprovisionado: {0}' -f $Name) 'OK'
            }
            else
            {
                Write-D3PL0YWarning (
                    'No se pudo desaprovisionar {0}. {1}' -f
                    $Name,
                    $_.Exception.Message
                )
            }
        }
    }

    # Después se elimina de todos los perfiles existentes.
    $InstalledMatches = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $Name `
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

            Write-D3PL0YLog ('Eliminado: {0}' -f $Name) 'OK'
        }
        catch
        {
            $StillInstalled = @(
                Get-AppxPackage `
                    -AllUsers `
                    -Name $Name `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.PackageFullName -eq $Package.PackageFullName
                }
            )

            if ($StillInstalled.Count -eq 0)
            {
                Write-D3PL0YLog ('Ya no estaba instalado: {0}' -f $Name) 'OK'
            }
            else
            {
                Write-D3PL0YWarning (
                    'No se pudo eliminar {0}. {1}' -f
                    $Name,
                    $_.Exception.Message
                )
            }
        }
    }

    $RemainingInstalled = @(
        Get-AppxPackage `
            -AllUsers `
            -Name $Name `
            -ErrorAction SilentlyContinue
    )

    $RemainingProvisioned = @(
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $Name }
    )

    if (
        ($RemainingInstalled.Count -eq 0) -and
        ($RemainingProvisioned.Count -eq 0)
    )
    {
        if (-not $FoundPackage)
        {
            Write-D3PL0YLog ('No estaba instalado: {0}' -f $Name)
        }
    }
    else
    {
        Write-D3PL0YWarning (
            'Persisten restos de {0}: instalados={1}, aprovisionados={2}' -f
            $Name,
            $RemainingInstalled.Count,
            $RemainingProvisioned.Count
        )
    }
}

function Uninstall-D3PL0YOneDrive
{
    Get-Process -Name OneDrive -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $OneDriveSetupSucceeded = $false

    $OneDriveSetup = @(
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'),
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\Update\OneDriveSetup.exe')
    ) |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if ($null -ne $OneDriveSetup)
    {
        Write-D3PL0YLog 'Desinstalando Microsoft OneDrive.'

        try
        {
            $UninstallProcess = Start-Process `
                -FilePath $OneDriveSetup `
                -ArgumentList @('/uninstall', '/allusers') `
                -Wait `
                -PassThru `
                -WindowStyle Hidden

            if ($UninstallProcess.ExitCode -ne 0)
            {
                Write-D3PL0YWarning (
                    'OneDriveSetup devolvió el código {0}.' -f
                    $UninstallProcess.ExitCode
                )
            }
            else
            {
                $OneDriveSetupSucceeded = $true
                Write-D3PL0YLog 'OneDriveSetup completó la desinstalación.' 'OK'
            }
        }
        catch
        {
            Write-D3PL0YWarning (
                'No se pudo ejecutar OneDriveSetup. {0}' -f
                $_.Exception.Message
            )
        }

        Start-Sleep -Seconds 3
    }
    else
    {
        Write-D3PL0YLog 'No se encontró OneDriveSetup.exe.'
    }

    # WinGet queda como método alternativo. No se ejecuta después de un
    # OneDriveSetup correcto porque la entrada de aplicaciones puede tardar en
    # actualizarse y producir un aviso falso aunque OneDrive ya no esté.
    if (
        (-not $OneDriveSetupSucceeded) -and
        (Test-D3PL0YWingetPackage -Id 'Microsoft.OneDrive')
    )
    {
        & winget.exe uninstall `
            --id Microsoft.OneDrive `
            --exact `
            --silent `
            --disable-interactivity `
            --accept-source-agreements

        if (
            ($LASTEXITCODE -ne 0) -and
            (Test-D3PL0YWingetPackage -Id 'Microsoft.OneDrive')
        )
        {
            Write-D3PL0YWarning (
                'WinGet no pudo completar la desinstalación de OneDrive.'
            )
        }
    }

    Remove-ItemProperty `
        -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'OneDrive' `
        -Force `
        -ErrorAction SilentlyContinue

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' `
        -Name 'DisableFileSyncNGSC' `
        -Value 1 `
        -Type DWord

    foreach ($NamespacePath in @(
        'HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}',
        'HKLM:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $NamespacePath `
            -Name 'System.IsPinnedToNameSpaceTree' `
            -Value 0 `
            -Type DWord
    }

    Write-D3PL0YLog (
        'OneDrive deshabilitado. No se ha borrado ninguna carpeta de datos del usuario.'
    ) 'OK'
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

    & rundll32.exe 'user32.dll,UpdatePerUserSystemParameters'
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
$script:UiColor = $SelectedConfig.UiColor
$script:UiDarkColor = $SelectedConfig.UiDarkColor
$InstalledAppSummary = $SelectedConfig.AppNames -join ', '
$DebloatSummary = if ($SkipDebloat)
{
    'Omitido mediante -SkipDebloat'
}
else
{
    'OneDrive y aplicaciones innecesarias eliminadas'
}

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

$PreflightPassed = Invoke-D3PL0YStep -Name 'Comprobaciones previas' -Action {

    if (-not (Test-D3PL0YAdministrator))
    {
        throw 'D3PL0Y debe ejecutarse como administrador.'
    }

    if (
        [Environment]::Is64BitOperatingSystem -and
        (-not [Environment]::Is64BitProcess)
    )
    {
        throw (
            'Ejecuta D3PL0Y desde Windows PowerShell de 64 bits; ' +
            'la consola x86 no puede aplicar correctamente la pantalla de bloqueo.'
        )
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
}

if (-not $PreflightPassed)
{
    Set-D3PL0YStatus 'ABORTADO'

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

    throw 'D3PL0Y se ha detenido porque falló una comprobación previa.'
}

Invoke-D3PL0YStep -Name 'Configurar energía' -Action {

    $PowerCommands = @(
        @('-h', 'off'),
        @('/change', 'standby-timeout-ac', '0'),
        @('/change', 'monitor-timeout-ac', '20'),
        @('/change', 'standby-timeout-dc', '30'),
        @('/change', 'monitor-timeout-dc', '10')
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
    Invoke-D3PL0YStep -Name 'Desinstalar OneDrive' -Action {

        Uninstall-D3PL0YOneDrive
    } | Out-Null

    Invoke-D3PL0YStep -Name 'Eliminar aplicaciones preinstaladas' -Action {

        # Lista deliberadamente conservadora: se mantienen Store, WinGet,
        # Terminal, Bloc de notas, Calculadora, Fotos, Paint, Cámara,
        # Recortes, codecs, Seguridad de Windows y componentes del sistema.
        $AppsToRemove = @(
            'Clipchamp.Clipchamp',
            'Microsoft.3DBuilder',
            'Microsoft.549981C3F5F10',
            'Microsoft.BingNews',
            'Microsoft.BingWeather',
            'Microsoft.Copilot',
            'Microsoft.GamingApp',
            'Microsoft.GetHelp',
            'Microsoft.Getstarted',
            'Microsoft.Microsoft3DViewer',
            'Microsoft.MicrosoftOfficeHub',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.MixedReality.Portal',
            'Microsoft.OneDriveSync',
            'Microsoft.OutlookForWindows',
            'Microsoft.People',
            'Microsoft.PowerAutomateDesktop',
            'Microsoft.SkypeApp',
            'Microsoft.Todos',
            'Microsoft.WindowsFeedbackHub',
            'Microsoft.WindowsMaps',
            'Microsoft.Xbox.TCUI',
            'Microsoft.XboxApp',
            'Microsoft.XboxGameOverlay',
            'Microsoft.XboxGamingOverlay',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.XboxSpeechToTextOverlay',
            'Microsoft.YourPhone',
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo',
            'MicrosoftTeams',
            'MSTeams'
        )

        foreach ($Target in $AppsToRemove)
        {
            Remove-D3PL0YAppxPackage -Name $Target
        }
    } | Out-Null
}
else
{
    Write-D3PL0YWarning (
        'Se ha omitido la desinstalación de OneDrive y del bloatware.'
    )
}

Invoke-D3PL0YStep -Name 'Configurar privacidad y sugerencias' -Action {

    $ContentDeliveryManager =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    foreach ($Property in @(
        'SubscribedContent-338387Enabled',
        'SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled',
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled',
        'RotatingLockScreenEnabled',
        'RotatingLockScreenOverlayEnabled',
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

    $CloudContentPolicy =
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

    foreach ($Property in @(
        'DisableTailoredExperiencesWithDiagnosticData',
        'DisableThirdPartySuggestions',
        'DisableWindowsConsumerFeatures',
        'DisableWindowsSpotlightFeatures',
        'DisableWindowsSpotlightOnActionCenter',
        'DisableWindowsSpotlightOnLockScreen',
        'DisableWindowsSpotlightOnSettings',
        'DisableWindowsSpotlightWindowsWelcomeExperience'
    ))
    {
        Set-D3PL0YRegistryValue `
            -Path $CloudContentPolicy `
            -Name $Property `
            -Value 1 `
            -Type DWord
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' `
        -Name 'Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' `
        -Name 'TailoredExperiencesWithDiagnosticDataEnabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Input\TIPC' `
        -Name 'Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' `
        -Name 'ScoobeSystemSettingEnabled' `
        -Value 0 `
        -Type DWord
} | Out-Null

Invoke-D3PL0YStep -Name 'Optimizar componentes de Windows 11' -Action {

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' `
        -Name 'DisableSearchBoxSuggestions' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' `
        -Name 'AllowNewsAndInterests' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\System\GameConfigStore' `
        -Name 'GameDVR_Enabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' `
        -Name 'AppCaptureEnabled' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' `
        -Name 'AllowGameDVR' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
        -Name 'LongPathsEnabled' `
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
        -Name 'TaskbarMn' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'ShowTaskViewButton' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'ShowSyncProviderNotifications' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'LaunchTo' `
        -Value 1 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Start_AccountNotifications' `
        -Value 0 `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $ExplorerAdvanced `
        -Name 'Start_IrisRecommendations' `
        -Value 0 `
        -Type DWord

    $Search =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

    Set-D3PL0YRegistryValue `
        -Path $Search `
        -Name 'SearchboxTaskbarMode' `
        -Value 0 `
        -Type DWord

    $ClassicContextMenu =
        'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'

    if (-not (Test-Path -LiteralPath $ClassicContextMenu))
    {
        New-Item -Path $ClassicContextMenu -Force | Out-Null
    }

    Set-Item -LiteralPath $ClassicContextMenu -Value '' -Force
    $script:ExplorerNeedsRestart = $true
} | Out-Null

Invoke-D3PL0YStep `
    -Name ('Aplicar paleta {0}' -f $SelectedConfig.ThemeName) `
    -Action {

    $Dwm = 'HKCU:\Software\Microsoft\Windows\DWM'

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'AccentColor' `
        -Value $SelectedConfig.AccentColor `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Dwm `
        -Name 'ColorizationColor' `
        -Value $SelectedConfig.ColorizationColor `
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

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentPalette' `
        -Value $SelectedConfig.AccentPalette `
        -Type Binary

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'AccentColorMenu' `
        -Value $SelectedConfig.AccentColorMenu `
        -Type DWord

    Set-D3PL0YRegistryValue `
        -Path $Accent `
        -Name 'StartColorMenu' `
        -Value $SelectedConfig.StartColorMenu `
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
        (0x01 -bor 0x02)
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
        -Force

    Assert-D3PL0YPngFile -Path $WallpaperFile

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
        -Force

    Assert-D3PL0YPngFile -Path $LockImage

    # Aplica la imagen al usuario actual mediante la API de Windows. Este es el
    # método principal en Windows 11 Pro sin administración MDM.
    try
    {
        Set-D3PL0YCurrentUserLockScreen -Path $LockImage
        Write-D3PL0YLog 'Pantalla de bloqueo aplicada al usuario actual.' 'OK'
    }
    catch
    {
        Write-D3PL0YWarning (
            'La API de pantalla de bloqueo no respondió. Se usarán las directivas de respaldo. {0}' -f
            $_.Exception.Message
        )
    }

    Set-D3PL0YRegistryValue `
        -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' `
        -Name 'LockScreenImage' `
        -Value $LockImage `
        -Type String

    # PersonalizationCSP sirve como respaldo en ediciones/builds de Windows 11
    # que no aplican inmediatamente la directiva clásica de Personalization.
    $PersonalizationCsp =
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImagePath' `
        -Value $LockImage `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImageUrl' `
        -Value $LockImage `
        -Type String

    Set-D3PL0YRegistryValue `
        -Path $PersonalizationCsp `
        -Name 'LockScreenImageStatus' `
        -Value 1 `
        -Type DWord

    Write-D3PL0YLog (
        'Pantalla de bloqueo preparada para {0}: {1}. Se aplicará al reiniciar.' -f
        $SelectedD3PL0Y,
        $SelectedConfig.Lockscreen
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

$FailureSummary = if ($script:FailedSteps.Count -eq 0)
{
    'Ninguna.'
}
else
{
    '- ' + ($script:FailedSteps -join "`r`n- ")
}

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

Fases con error:
$FailureSummary

Log:
$LogFile

Notas:
- Aplicaciones del perfil: $InstalledAppSummary.
- Limpieza de Windows: $DebloatSummary.
- Paleta: $($SelectedConfig.ThemeName) — principal $($SelectedConfig.PrimaryColor), secundaria $($SelectedConfig.SecondaryColor), suave $($SelectedConfig.SoftColor).
- Fondo de escritorio: $($SelectedConfig.Wallpaper).
- Pantalla de bloqueo: $($SelectedConfig.Lockscreen).
- Los archivos de la carpeta OneDrive del usuario no se eliminan.
"@

Set-Content `
    -LiteralPath $SummaryFile `
    -Value $Summary `
    -Encoding UTF8

Write-Host ''
Write-Host $Summary -ForegroundColor $script:UiColor

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

    $RestartDetail = if ($script:FailedSteps.Count -gt 0)
    {
        $FirstFailure = $script:FailedSteps[0]

        if ($FirstFailure.Length -gt 300)
        {
            $FirstFailure = $FirstFailure.Substring(0, 300)
        }

        ' - ERROR: {0}' -f $FirstFailure
    }
    else
    {
        ''
    }

    $RestartComment = 'D3PL0Y v{0} - {1} - {2}{3}' -f (
        $Version,
        $SelectedD3PL0Y,
        $FinalStatus,
        $RestartDetail
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
