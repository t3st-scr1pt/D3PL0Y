#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    D3PL0Y v4.0

.DESCRIPTION
    Aprovisionamiento idempotente, reanudable y optimizado de Windows 11.

    D3PL0Y instala solo las aplicaciones necesarias, elimina software preinstalado
    seleccionado, aplica la configuración visual y de privacidad, conserva las
    carpetas personales en el almacenamiento local y evita operaciones redundantes.

    No crea tareas de Google Drive, no ejecuta scripts secundarios y no redirige
    Escritorio, Documentos, Descargas, Música, Imágenes ni Vídeos a unidades externas.

.PARAMETER Force
    Ejecuta de nuevo todas las fases aunque su punto de control siga vigente.

.PARAMETER UpdateApps
    Además de instalar aplicaciones ausentes, intenta actualizar las aplicaciones gestionadas.

.PARAMETER NoRestart
    Impide cualquier reinicio automático al terminar.

.PARAMETER OnlyPhase
    Ejecuta únicamente las fases indicadas por su clave. Ejemplo: -OnlyPhase Apps,Assets

.PARAMETER SkipPhase
    Omite las fases indicadas por su clave. Ejemplo: -SkipPhase Debloat

.EXAMPLE
    irm https://lavueltitaironica.com/install | iex

.EXAMPLE
    .\D3PL0Y.ps1 -NoRestart

.EXAMPLE
    .\D3PL0Y.ps1 -Force -UpdateApps -NoRestart

.EXAMPLE
    .\D3PL0Y.ps1 -OnlyPhase Apps,Assets -NoRestart
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$UpdateApps,
    [switch]$NoRestart,
    [string[]]$OnlyPhase,
    [string[]]$SkipPhase
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# =============================================================================
# CONFIGURACIÓN CENTRAL
# =============================================================================

$D3PL0Y = [ordered]@{
    Name                  = 'D3PL0Y'
    Version               = '4.0'
    StateSchema           = 3
    Root                  = 'C:\D3PL0Y'
    RepositoryRaw         = 'https://raw.githubusercontent.com/t3st-scr1pt/D3PL0Y/main'
    SourceMaxAgeHours     = 12
    MinimumFreeSpaceBytes = 5GB
    LogRetention          = 20
    AccentColor           = -15696880
    ColorizationColor     = -1005552624
    StartColorMenu        = -15831794
    MouseSpeed            = '13'
}

$Paths = [ordered]@{
    Root       = $D3PL0Y.Root
    Logs       = Join-Path $D3PL0Y.Root 'Logs'
    State      = Join-Path $D3PL0Y.Root 'State'
    Wallpapers = Join-Path $D3PL0Y.Root 'Wallpapers'
    Cursors    = Join-Path $D3PL0Y.Root 'Cursors'
    Configs    = Join-Path $D3PL0Y.Root 'Configs'
    Cache      = Join-Path $D3PL0Y.Root 'Cache'
}

$ManagedApps = @(
    [ordered]@{ Id = 'Google.Chrome';               Required = $true  }
    [ordered]@{ Id = 'Google.GoogleDrive';          Required = $true  }
    [ordered]@{ Id = 'Tailscale.Tailscale';         Required = $true  }
    [ordered]@{ Id = 'Git.Git';                     Required = $true  }
    [ordered]@{ Id = 'Microsoft.VisualStudioCode'; Required = $true  }
)

$AppsToRemove = @(
    'Microsoft.XboxApp'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.BingNews'
    'Clipchamp.Clipchamp'
    'Microsoft.YourPhone'
    'MicrosoftTeams'
    'MSTeams'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.People'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.PowerAutomateDesktop'
)

$LocalKnownFolders = @(
    [ordered]@{ Name = 'Desktop'; RelativePath = 'Desktop' }
    [ordered]@{ Name = 'Personal'; RelativePath = 'Documents' }
    [ordered]@{ Name = 'My Pictures'; RelativePath = 'Pictures' }
    [ordered]@{ Name = 'My Music'; RelativePath = 'Music' }
    [ordered]@{ Name = 'My Video'; RelativePath = 'Videos' }
    [ordered]@{ Name = 'Favorites'; RelativePath = 'Favorites' }
    [ordered]@{ Name = '{374DE290-123F-4565-9164-39C4925E467B}'; RelativePath = 'Downloads' }
    [ordered]@{ Name = '{56784854-C6CB-462B-8169-88E350ACB882}'; RelativePath = 'Contacts' }
    [ordered]@{ Name = '{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}'; RelativePath = 'Links' }
    [ordered]@{ Name = '{4C5C32FF-BB9D-43B0-BF3E-169D1D25C7B0}'; RelativePath = 'Saved Games' }
    [ordered]@{ Name = '{7D1D3A04-DEBB-4115-95CF-2F29DA2920DA}'; RelativePath = 'Searches' }
)

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

$Assets = [System.Collections.Generic.List[object]]::new()
foreach ($CursorFile in $CursorMap.Values) {
    $Assets.Add([pscustomobject]@{
        Name        = $CursorFile
        Uri         = "$($D3PL0Y.RepositoryRaw)/configs/cursors/$CursorFile"
        Destination = Join-Path $Paths.Cursors $CursorFile
        Sha256      = $null
    })
}

$Assets.Add([pscustomobject]@{
    Name        = 'd3pl0y.png'
    Uri         = "$($D3PL0Y.RepositoryRaw)/wallpapers/d3pl0y.png"
    Destination = Join-Path $Paths.Wallpapers 'd3pl0y.png'
    Sha256      = $null
})

$Assets.Add([pscustomobject]@{
    Name        = 'lockscreen.png'
    Uri         = "$($D3PL0Y.RepositoryRaw)/wallpapers/lockscreen.png"
    Destination = Join-Path $Paths.Wallpapers 'lockscreen.png'
    Sha256      = $null
})

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

foreach ($Folder in $Paths.Values) {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
}

$Timestamp         = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile           = Join-Path $Paths.Logs "d3pl0y-$Timestamp.log"
$StatusFile        = Join-Path $Paths.Logs 'estado.txt'
$SummaryFile       = Join-Path $Paths.Logs "resumen-$Timestamp.json"
$LatestSummaryFile = Join-Path $Paths.Logs 'Resumen.txt'
$StateFile         = Join-Path $Paths.State 'd3pl0y-state.json'
$EffectiveConfig   = Join-Path $Paths.Configs 'effective-config.json'
$WingetImportFile  = Join-Path $Paths.Cache 'winget-import.json'

$Script:Results               = [System.Collections.Generic.List[object]]::new()
$Script:LogWriter             = $null
$Script:State                 = $null
$Script:ExplorerRefreshNeeded = $false
$Script:RestartRecommended    = $false
$Script:WingetAvailable       = $false
$Script:Changes               = 0
$Script:Errors                = 0
$Script:Warnings              = 0
$Script:StartedAt             = Get-Date
$Script:Mutex                 = $null
$Script:MutexAcquired         = $false
$Script:LogLinesSinceFlush     = 0
$Script:LogFlushInterval       = 25

# =============================================================================
# LOG, ESTADO Y UTILIDADES
# =============================================================================

function Initialize-Log {
    $Encoding = [System.Text.UTF8Encoding]::new($false)
    $Script:LogWriter = [System.IO.StreamWriter]::new($LogFile, $true, $Encoding, 65536)
    $Script:LogWriter.AutoFlush = $false
}

function Flush-D3PL0YLog {
    if ($null -ne $Script:LogWriter) {
        $Script:LogWriter.Flush()
        $Script:LogLinesSinceFlush = 0
    }
}

function Write-D3PL0YLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'SKIP')][string]$Level = 'INFO'
    )

    $Color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'SKIP'  { 'DarkGray' }
        default { 'Gray' }
    }

    if ($Level -eq 'WARN')  { $Script:Warnings++ }
    if ($Level -eq 'ERROR') { $Script:Errors++ }

    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $Line -ForegroundColor $Color

    if ($null -ne $Script:LogWriter) {
        $Script:LogWriter.WriteLine($Line)
        $Script:LogLinesSinceFlush++

        if ($Level -in @('WARN', 'ERROR') -or $Script:LogLinesSinceFlush -ge $Script:LogFlushInterval) {
            Flush-D3PL0YLog
        }
    }
}

function Set-D3PL0YStatus {
    param([Parameter(Mandatory)][string]$Status)
    [System.IO.File]::WriteAllText($StatusFile, $Status, ([System.Text.UTF8Encoding]::new($false)))
}

function Add-D3PL0YResult {
    param(
        [Parameter(Mandatory)][string]$Phase,
        [ValidateSet('OK', 'SKIP', 'WARN', 'ERROR')][string]$Status,
        [string]$Detail,
        [long]$DurationMs = 0,
        [int]$Changes = 0
    )

    $Script:Results.Add([pscustomobject]@{
        Phase      = $Phase
        Status     = $Status
        Detail     = $Detail
        DurationMs = $DurationMs
        Changes    = $Changes
        Time       = (Get-Date).ToString('s')
    })
}

function Read-D3PL0YState {
    $State = @{
        Schema          = $D3PL0Y.StateSchema
        ProjectVersion   = $D3PL0Y.Version
        Machine         = $env:COMPUTERNAME
        SourceUpdatedAt = $null
        Phases           = @{}
    }

    if (-not (Test-Path -LiteralPath $StateFile)) {
        return $State
    }

    try {
        $Raw = Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json

        if ([int]$Raw.Schema -ne $D3PL0Y.StateSchema -or [string]$Raw.Machine -ne $env:COMPUTERNAME) {
            Write-D3PL0YLog 'El estado pertenece a otro esquema o equipo; se crearán puntos de control nuevos.' WARN
            return $State
        }

        if ($null -ne $Raw.SourceUpdatedAt) {
            $State.SourceUpdatedAt = [string]$Raw.SourceUpdatedAt
        }

        if ($null -ne $Raw.Phases) {
            foreach ($Property in $Raw.Phases.PSObject.Properties) {
                $Entry = $Property.Value
                $State.Phases[$Property.Name] = @{
                    Fingerprint = [string]$Entry.Fingerprint
                    Status      = [string]$Entry.Status
                    CompletedAt = [string]$Entry.CompletedAt
                    DurationMs  = [long]$Entry.DurationMs
                    Detail      = [string]$Entry.Detail
                }
            }
        }
    }
    catch {
        Write-D3PL0YLog "El estado anterior no se pudo leer y será reconstruido: $($_.Exception.Message)" WARN
    }

    return $State
}

function Save-D3PL0YState {
    Flush-D3PL0YLog
    $Temporary = "$StateFile.tmp"
    $Script:State.ProjectVersion = $D3PL0Y.Version
    $Json = $Script:State | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Temporary, $Json, ([System.Text.UTF8Encoding]::new($false)))
    Move-Item -LiteralPath $Temporary -Destination $StateFile -Force
}

function Get-ObjectFingerprint {
    param(
        [Parameter(Mandatory)][string]$Revision,
        [Parameter()][object]$Data
    )

    $Payload = [ordered]@{
        Revision = $Revision
        Data     = $Data
    } | ConvertTo-Json -Depth 12 -Compress

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)
        return ([System.BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $Sha.Dispose()
    }
}

function Test-PhaseSelected {
    param([Parameter(Mandatory)][string]$Key)

    if ($Key -eq 'Preflight') {
        return $true
    }

    if ($OnlyPhase -and $OnlyPhase.Count -gt 0 -and $OnlyPhase -notcontains $Key) {
        return $false
    }

    if ($SkipPhase -and $SkipPhase -contains $Key) {
        return $false
    }

    return $true
}

function Invoke-D3PL0YPhase {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Revision,
        [Parameter()][object]$FingerprintData,
        [Parameter(Mandatory)][scriptblock]$Action,
        [scriptblock]$ComplianceTest,
        [switch]$Critical,
        [switch]$AlwaysRun
    )

    if (-not (Test-PhaseSelected -Key $Key)) {
        Write-D3PL0YLog "Fase omitida por selección: $Key" SKIP
        Add-D3PL0YResult -Phase $Key -Status SKIP -Detail 'Omitida mediante OnlyPhase/SkipPhase.'
        return
    }

    $Fingerprint = Get-ObjectFingerprint -Revision $Revision -Data $FingerprintData
    $Previous = $null
    if ($Script:State.Phases.ContainsKey($Key)) {
        $Previous = $Script:State.Phases[$Key]
    }

    $IsCompliant = $true
    if ($null -ne $ComplianceTest) {
        try {
            $IsCompliant = [bool](& $ComplianceTest)
        }
        catch {
            $IsCompliant = $false
        }
    }

    if (-not $Force -and -not $AlwaysRun -and $IsCompliant -and $null -ne $Previous -and
        $Previous.Status -eq 'OK' -and $Previous.Fingerprint -eq $Fingerprint) {
        Write-D3PL0YLog "Sin cambios, se reutiliza el punto de control: $Name" SKIP
        Add-D3PL0YResult -Phase $Key -Status SKIP -Detail "Completada previamente: $($Previous.CompletedAt)."
        return
    }

    if (-not $IsCompliant -and $null -ne $Previous) {
        Write-D3PL0YLog "El punto de control de $Name existe, pero el sistema ya no cumple su estado esperado." WARN
    }

    Set-D3PL0YStatus $Name
    Write-D3PL0YLog "Iniciando: $Name"
    $Watch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $Outcome = & $Action
        $Watch.Stop()

        $Detail = 'Completado.'
        $PhaseChanges = 0

        if ($null -ne $Outcome) {
            $LastOutcome = @($Outcome)[-1]
            if ($LastOutcome -is [string]) {
                $Detail = $LastOutcome
            }
            elseif ($LastOutcome.PSObject.Properties.Name -contains 'Detail') {
                $Detail = [string]$LastOutcome.Detail
                if ($LastOutcome.PSObject.Properties.Name -contains 'Changes') {
                    $PhaseChanges = [int]$LastOutcome.Changes
                }
            }
        }

        $Script:Changes += $PhaseChanges
        $Script:State.Phases[$Key] = @{
            Fingerprint = $Fingerprint
            Status      = 'OK'
            CompletedAt = (Get-Date).ToString('s')
            DurationMs  = $Watch.ElapsedMilliseconds
            Detail      = $Detail
        }
        Save-D3PL0YState

        Add-D3PL0YResult -Phase $Key -Status OK -Detail $Detail -DurationMs $Watch.ElapsedMilliseconds -Changes $PhaseChanges
        Write-D3PL0YLog "Completado: $Name. $Detail" OK
    }
    catch {
        $Watch.Stop()
        $Detail = $_.Exception.Message

        $Script:State.Phases[$Key] = @{
            Fingerprint = $Fingerprint
            Status      = 'ERROR'
            CompletedAt = (Get-Date).ToString('s')
            DurationMs  = $Watch.ElapsedMilliseconds
            Detail      = $Detail
        }
        Save-D3PL0YState

        Add-D3PL0YResult -Phase $Key -Status ERROR -Detail $Detail -DurationMs $Watch.ElapsedMilliseconds
        Write-D3PL0YLog "Error en '$Name': $Detail" ERROR

        if ($Critical) {
            throw
        }
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @(),
        [int[]]$SuccessExitCodes = @(0),
        [switch]$IgnoreExitCode,
        [switch]$Quiet
    )

    $Output = @(& $FilePath @ArgumentList 2>&1)
    $ExitCode = $LASTEXITCODE

    if (-not $Quiet) {
        foreach ($Line in $Output) {
            $Text = [string]$Line
            if (-not [string]::IsNullOrWhiteSpace($Text)) {
                Write-D3PL0YLog $Text
            }
        }
    }

    if (-not $IgnoreExitCode -and $SuccessExitCodes -notcontains $ExitCode) {
        throw "$FilePath devolvió el código de salida $ExitCode."
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = ($Output -join [Environment]::NewLine)
    }
}

function Set-FileIfChanged {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $Encoding = [System.Text.UTF8Encoding]::new($false)
    $Existing = $null
    if (Test-Path -LiteralPath $Path) {
        $Existing = [System.IO.File]::ReadAllText($Path, $Encoding)
    }

    if ($Existing -ceq $Content) {
        return $false
    }

    $Parent = Split-Path -Parent $Path
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Temporary = "$Path.tmp"
    [System.IO.File]::WriteAllText($Temporary, $Content, $Encoding)
    Move-Item -LiteralPath $Temporary -Destination $Path -Force
    return $true
}

function Test-ByteArrayEqual {
    param([byte[]]$First, [byte[]]$Second)

    if ($null -eq $First -or $null -eq $Second -or $First.Length -ne $Second.Length) {
        return $false
    }

    for ($Index = 0; $Index -lt $First.Length; $Index++) {
        if ($First[$Index] -ne $Second[$Index]) {
            return $false
        }
    }

    return $true
}

function Test-RegistryValueEqual {
    param($Current, $Desired)

    if ($Current -is [byte[]] -and $Desired -is [byte[]]) {
        return (Test-ByteArrayEqual -First $Current -Second $Desired)
    }

    return ([string]$Current -ceq [string]$Desired)
}

function Set-RegistryBatch {
    param(
        [ValidateSet('CurrentUser', 'LocalMachine')][string]$Hive,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Values
    )

    $Root = if ($Hive -eq 'CurrentUser') {
        [Microsoft.Win32.Registry]::CurrentUser
    }
    else {
        [Microsoft.Win32.Registry]::LocalMachine
    }

    $Key = $Root.CreateSubKey($Path, $true)
    if ($null -eq $Key) {
        throw "No se pudo abrir o crear $Hive\$Path."
    }

    $Changed = 0
    try {
        foreach ($Entry in $Values) {
            $Name = [string]$Entry.Name
            $Kind = [Microsoft.Win32.RegistryValueKind][System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$Entry.Kind)
            $Desired = $Entry.Value
            $Exists = $true
            $Current = $null

            try {
                $Current = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $null = $Key.GetValueKind($Name)
            }
            catch {
                $Exists = $false
            }

            if (-not $Exists -or -not (Test-RegistryValueEqual -Current $Current -Desired $Desired)) {
                $Key.SetValue($Name, $Desired, $Kind)
                $Changed++
            }
        }
    }
    finally {
        $Key.Dispose()
    }

    return $Changed
}

function Test-PendingReboot {
    $Checks = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($Path in $Checks) {
        if (Test-Path -LiteralPath $Path) {
            return $true
        }
    }

    try {
        $PendingRename = Get-ItemPropertyValue -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Stop
        if ($null -ne $PendingRename) {
            return $true
        }
    }
    catch {}

    return $false
}

function Remove-OldLogs {
    $Patterns = @('d3pl0y-*.log', 'resumen-*.json')
    foreach ($Pattern in $Patterns) {
        Get-ChildItem -LiteralPath $Paths.Logs -Filter $Pattern -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip $D3PL0Y.LogRetention |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# DESCARGAS EN LOTE
# =============================================================================

function Invoke-HttpDownload {
    param(
        [Parameter(Mandatory)][object]$Client,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination,
        [int]$Retries = 3
    )

    for ($Attempt = 1; $Attempt -le $Retries; $Attempt++) {
        try {
            $Bytes = $Client.GetByteArrayAsync($Uri).GetAwaiter().GetResult()
            if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
                throw 'La descarga está vacía.'
            }

            [System.IO.File]::WriteAllBytes($Destination, $Bytes)
            return
        }
        catch {
            if ($Attempt -eq $Retries) {
                throw
            }

            Write-D3PL0YLog "Descarga fallida ($Attempt/$Retries): $Uri" WARN
            Start-Sleep -Seconds (2 * $Attempt)
        }
    }
}

function Sync-AssetBatch {
    param(
        [Parameter(Mandatory)][object[]]$AssetList,
        [switch]$RefreshExisting
    )

    $DownloadList = [System.Collections.Generic.List[object]]::new()
    foreach ($Asset in $AssetList) {
        $NeedsDownload = $RefreshExisting -or -not (Test-Path -LiteralPath $Asset.Destination)
        if (-not $NeedsDownload) {
            try {
                $NeedsDownload = (Get-Item -LiteralPath $Asset.Destination).Length -le 0
            }
            catch {
                $NeedsDownload = $true
            }
        }

        if ($NeedsDownload) {
            $DownloadList.Add($Asset)
        }
    }

    if ($DownloadList.Count -eq 0) {
        Write-D3PL0YLog 'Todos los recursos visuales están presentes; no se abre ninguna conexión de red.' SKIP
        return 0
    }

    foreach ($Asset in $DownloadList) {
        $Parent = Split-Path -Parent $Asset.Destination
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
        Remove-Item -LiteralPath "$($Asset.Destination).download" -Force -ErrorAction SilentlyContinue
    }

    $HttpSucceeded = $false
    try {
        Add-Type -AssemblyName System.Net.Http
        [Net.ServicePointManager]::DefaultConnectionLimit = [Math]::Max([Net.ServicePointManager]::DefaultConnectionLimit, 8)

        $Handler = [System.Net.Http.HttpClientHandler]::new()
        if ($Handler.PSObject.Properties.Name -contains 'MaxConnectionsPerServer') {
            $Handler.MaxConnectionsPerServer = 8
        }

        $Client = [System.Net.Http.HttpClient]::new($Handler)
        $Client.Timeout = [TimeSpan]::FromSeconds(90)
        $Client.DefaultRequestHeaders.UserAgent.ParseAdd('D3PL0Y/4.0')

        try {
            $Pending = [System.Collections.Generic.List[object]]::new()
            foreach ($Asset in $DownloadList) {
                $Pending.Add([pscustomobject]@{
                    Asset = $Asset
                    Task  = $Client.GetByteArrayAsync([string]$Asset.Uri)
                })
            }

            Write-D3PL0YLog "Descargando $($DownloadList.Count) recursos mediante HTTP concurrente limitado a 8 conexiones."

            foreach ($Item in $Pending) {
                $Temporary = "$($Item.Asset.Destination).download"
                try {
                    $Bytes = $Item.Task.GetAwaiter().GetResult()
                    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
                        throw 'La descarga está vacía.'
                    }
                    [System.IO.File]::WriteAllBytes($Temporary, $Bytes)
                }
                catch {
                    Write-D3PL0YLog "La descarga concurrente de $($Item.Asset.Name) falló; se reintentará de forma individual." WARN
                    Invoke-HttpDownload -Client $Client -Uri $Item.Asset.Uri -Destination $Temporary
                }
            }

            $HttpSucceeded = $true
        }
        finally {
            $Client.Dispose()
            $Handler.Dispose()
        }
    }
    catch {
        Write-D3PL0YLog "HTTP concurrente no pudo completar el lote; se usará BITS: $($_.Exception.Message)" WARN
    }

    if (-not $HttpSucceeded) {
        if (-not (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue)) {
            throw 'No están disponibles ni HTTP concurrente ni BITS para descargar los recursos.'
        }

        $Sources = @($DownloadList | ForEach-Object { [string]$_.Uri })
        $Destinations = @($DownloadList | ForEach-Object { "$($_.Destination).download" })
        Start-BitsTransfer -Source $Sources -Destination $Destinations -TransferType Download `
            -Priority Foreground -DisplayName 'D3PL0Y Assets' -ErrorAction Stop
    }

    $Changed = 0
    foreach ($Asset in $DownloadList) {
        $Temporary = "$($Asset.Destination).download"

        if (-not (Test-Path -LiteralPath $Temporary) -or (Get-Item -LiteralPath $Temporary).Length -le 0) {
            throw "El recurso $($Asset.Name) no se descargó correctamente."
        }

        if ($Asset.Sha256) {
            $ActualHash = (Get-FileHash -LiteralPath $Temporary -Algorithm SHA256).Hash
            if ($ActualHash -ne $Asset.Sha256) {
                throw "El hash SHA-256 de $($Asset.Name) no coincide."
            }
        }

        $Same = $false
        if (Test-Path -LiteralPath $Asset.Destination) {
            $OldHash = (Get-FileHash -LiteralPath $Asset.Destination -Algorithm SHA256).Hash
            $NewHash = (Get-FileHash -LiteralPath $Temporary -Algorithm SHA256).Hash
            $Same = ($OldHash -eq $NewHash)
        }

        if ($Same) {
            Remove-Item -LiteralPath $Temporary -Force
        }
        else {
            Move-Item -LiteralPath $Temporary -Destination $Asset.Destination -Force
            $Changed++
        }
    }

    return $Changed
}

function Test-AnyManagedPath {
    param([Parameter(Mandatory)][string[]]$PathsToTest)

    foreach ($Candidate in $PathsToTest) {
        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            continue
        }

        $Expanded = [Environment]::ExpandEnvironmentVariables($Candidate)
        if (Test-Path -Path $Expanded) {
            return $true
        }
    }

    return $false
}

function Test-ManagedAppFast {
    param([Parameter(Mandatory)][string]$Id)

    switch ($Id) {
        'Google.Chrome' {
            return Test-AnyManagedPath @(
                '%ProgramFiles%\Google\Chrome\Application\chrome.exe'
                '%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe'
                '%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe'
            )
        }
        'Google.GoogleDrive' {
            return Test-AnyManagedPath @(
                '%ProgramFiles%\Google\Drive File Stream\GoogleDriveFS.exe'
                '%ProgramFiles%\Google\Drive File Stream\*\GoogleDriveFS.exe'
                '%LOCALAPPDATA%\Google\DriveFS\GoogleDriveFS.exe'
            )
        }
        'Tailscale.Tailscale' {
            return (Test-AnyManagedPath @(
                '%ProgramFiles%\Tailscale\tailscale.exe'
                '%LOCALAPPDATA%\Tailscale\tailscale.exe'
            )) -or ($null -ne (Get-Service -Name 'Tailscale' -ErrorAction SilentlyContinue))
        }
        'Git.Git' {
            return ($null -ne (Get-Command git.exe -ErrorAction SilentlyContinue)) -or
                (Test-AnyManagedPath @('%ProgramFiles%\Git\cmd\git.exe', '%LOCALAPPDATA%\Programs\Git\cmd\git.exe'))
        }
        'Microsoft.VisualStudioCode' {
            return ($null -ne (Get-Command code.cmd -ErrorAction SilentlyContinue)) -or
                (Test-AnyManagedPath @(
                    '%ProgramFiles%\Microsoft VS Code\Code.exe'
                    '%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe'
                ))
        }
        default {
            return $false
        }
    }
}

# =============================================================================
# WINGET EN BLOQUE
# =============================================================================

function Update-WingetSourceIfNeeded {
    if (-not $Script:WingetAvailable) {
        return
    }

    $NeedsUpdate = $true
    if ($Script:State.SourceUpdatedAt) {
        try {
            $LastUpdate = [datetime]::Parse($Script:State.SourceUpdatedAt)
            $NeedsUpdate = ((Get-Date) - $LastUpdate).TotalHours -ge $D3PL0Y.SourceMaxAgeHours
        }
        catch {
            $NeedsUpdate = $true
        }
    }

    if (-not $NeedsUpdate -and -not $Force) {
        Write-D3PL0YLog 'Las fuentes de WinGet siguen recientes; se evita una actualización redundante.' SKIP
        return
    }

    $Result = Invoke-NativeCommand -FilePath 'winget.exe' -ArgumentList @(
        'source', 'update', '--disable-interactivity', '--nowarn'
    ) -IgnoreExitCode

    if ($Result.ExitCode -eq 0) {
        $Script:State.SourceUpdatedAt = (Get-Date).ToString('s')
        Save-D3PL0YState
    }
    else {
        Write-D3PL0YLog 'No se pudieron actualizar las fuentes de WinGet; se continuará con la caché disponible.' WARN
    }
}

function New-WinGetImportManifest {
    param([Parameter(Mandatory)][string[]]$PackageIds)

    $Packages = foreach ($Id in $PackageIds) {
        [ordered]@{ PackageIdentifier = $Id }
    }

    $Manifest = [ordered]@{
        '$schema'    = 'https://aka.ms/winget-packages.schema.2.0.json'
        CreationDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        Sources       = @(
            [ordered]@{
                Packages      = @($Packages)
                SourceDetails = [ordered]@{
                    Argument   = 'https://cdn.winget.microsoft.com/cache'
                    Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'
                    Name       = 'winget'
                    Type       = 'Microsoft.PreIndexed.Package'
                }
            }
        )
    }

    $Json = $Manifest | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($WingetImportFile, $Json, ([System.Text.UTF8Encoding]::new($false)))
}

function Install-ManagedApplications {
    $DesiredIds = @($ManagedApps | ForEach-Object { [string]$_.Id })
    $RequiredIds = @($ManagedApps | Where-Object Required | ForEach-Object { [string]$_.Id })
    $MissingBefore = @($DesiredIds | Where-Object { -not (Test-ManagedAppFast -Id $_) })
    $Changes = 0

    if ($MissingBefore.Count -eq 0 -and -not $UpdateApps) {
        Write-D3PL0YLog 'Todas las aplicaciones se detectaron localmente; WinGet no necesita iniciarse.' SKIP
        return [pscustomobject]@{
            Changes = 0
            Detail  = "$($DesiredIds.Count) aplicaciones verificadas mediante detección local rápida; cero procesos de WinGet."
        }
    }

    Update-WingetSourceIfNeeded

    if ($MissingBefore.Count -gt 0) {
        Write-D3PL0YLog "Aplicaciones ausentes según detección local: $($MissingBefore -join ', ')"
        New-WinGetImportManifest -PackageIds $MissingBefore

        $Import = Invoke-NativeCommand -FilePath 'winget.exe' -ArgumentList @(
            'import', '--import-file', $WingetImportFile,
            '--ignore-unavailable', '--ignore-versions',
            '--accept-package-agreements', '--accept-source-agreements',
            '--disable-interactivity', '--nowarn'
        ) -IgnoreExitCode

        if ($Import.ExitCode -ne 0) {
            Write-D3PL0YLog 'La instalación en bloque terminó con incidencias; se comprobarán únicamente los paquetes pendientes.' WARN
        }

        $StillMissing = @($RequiredIds | Where-Object { -not (Test-ManagedAppFast -Id $_) })
        $Changes = $MissingBefore.Count - @($MissingBefore | Where-Object { $StillMissing -contains $_ }).Count

        if ($StillMissing.Count -gt 0) {
            Write-D3PL0YLog "Reintento individual para: $($StillMissing -join ', ')" WARN

            foreach ($Id in @($StillMissing)) {
                $Retry = Invoke-NativeCommand -FilePath 'winget.exe' -ArgumentList @(
                    'install', '--id', $Id, '--exact', '--silent',
                    '--accept-package-agreements', '--accept-source-agreements',
                    '--disable-interactivity', '--nowarn'
                ) -IgnoreExitCode

                if ($Retry.ExitCode -ne 0) {
                    Write-D3PL0YLog "El reintento de $Id devolvió $($Retry.ExitCode)." WARN
                }
            }

            $StillMissing = @($RequiredIds | Where-Object { -not (Test-ManagedAppFast -Id $_) })
        }

        if ($StillMissing.Count -gt 0) {
            throw "No se pudieron instalar estas aplicaciones obligatorias: $($StillMissing -join ', ')."
        }

        $Changes = $MissingBefore.Count
        if ($Changes -gt 0) {
            $Script:RestartRecommended = $true
        }
    }

    $UpdateChecks = 0
    if ($UpdateApps) {
        Write-D3PL0YLog 'Comprobando actualizaciones de las aplicaciones gestionadas.'

        foreach ($Id in $DesiredIds) {
            $Upgrade = Invoke-NativeCommand -FilePath 'winget.exe' -ArgumentList @(
                'upgrade', '--id', $Id, '--exact', '--silent',
                '--accept-package-agreements', '--accept-source-agreements',
                '--disable-interactivity', '--nowarn'
            ) -IgnoreExitCode -Quiet

            $UpdateChecks++
            if ($Upgrade.ExitCode -notin @(0, -1978335189, -1978335212)) {
                Write-D3PL0YLog "La comprobación de actualización de $Id devolvió $($Upgrade.ExitCode); se conserva la instalación actual." WARN
            }
        }
    }

    $DetailText = if ($Changes -gt 0 -and $UpdateApps) {
        "$Changes aplicaciones instaladas y $UpdateChecks actualizaciones comprobadas."
    }
    elseif ($Changes -gt 0) {
        "$Changes aplicaciones instaladas; $($DesiredIds.Count) verificadas."
    }
    elseif ($UpdateApps) {
        "$UpdateChecks aplicaciones verificadas para actualización; no faltaba ninguna."
    }
    else {
        "$($DesiredIds.Count) aplicaciones verificadas; no faltaba ninguna."
    }

    return [pscustomobject]@{
        Changes = $Changes
        Detail  = $DetailText
    }
}

# =============================================================================
# FASES DE CONFIGURACIÓN
# =============================================================================

function Remove-SelectedAppxPackages {
    $InstalledPackages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    $ProvisionedPackages = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
    $Removed = 0
    $Failures = 0

    foreach ($Target in $AppsToRemove) {
        foreach ($Package in @($InstalledPackages | Where-Object { $_.Name -eq $Target })) {
            try {
                Remove-AppxPackage -Package $Package.PackageFullName -AllUsers -ErrorAction Stop
                $Removed++
                Write-D3PL0YLog "Eliminado AppX: $($Package.Name)" OK
            }
            catch {
                $Failures++
                Write-D3PL0YLog "No se pudo eliminar $($Package.Name): $($_.Exception.Message)" WARN
            }
        }

        foreach ($Package in @($ProvisionedPackages | Where-Object { $_.DisplayName -eq $Target })) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $Package.PackageName -AllUsers -ErrorAction Stop | Out-Null
                $Removed++
                Write-D3PL0YLog "Desaprovisionado AppX: $Target" OK
            }
            catch {
                $Failures++
                Write-D3PL0YLog "No se pudo desaprovisionar $Target: $($_.Exception.Message)" WARN
            }
        }
    }

    if ($Removed -gt 0) {
        $Script:RestartRecommended = $true
    }

    return [pscustomobject]@{
        Changes = $Removed
        Detail  = "$Removed paquetes eliminados; $Failures incidencias no críticas."
    }
}

function Remove-ObsoleteDriveAutomation {
    $Removed = 0

    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        foreach ($Task in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            $ActionText = (@($Task.Actions) | ForEach-Object {
                '{0} {1}' -f ([string]$_.Execute), ([string]$_.Arguments)
            }) -join ' '

            $Description = [string]$Task.Description
            $IsObsolete = $ActionText -match '(?i)PrimerInicio\.ps1|[^\s"'']*Drive[^\s"'']*\.ps1' -or
                $Description -match '(?i)integraci[oó]n.+Google Drive|Google Drive.+primer inicio'

            if (-not $IsObsolete) {
                continue
            }

            foreach ($Action in @($Task.Actions)) {
                $Arguments = [string]$Action.Arguments
                if ($Arguments -match '(?i)-File\s+(?:"([^"]+)"|''([^'']+)''|(\S+))') {
                    $HelperPath = @($Matches[1], $Matches[2], $Matches[3]) |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Select-Object -First 1

                    if ($HelperPath -and [IO.Path]::GetFileName($HelperPath) -ieq 'PrimerInicio.ps1') {
                        Remove-Item -LiteralPath $HelperPath -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            try {
                Unregister-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath `
                    -Confirm:$false -ErrorAction Stop
                $Removed++
                Write-D3PL0YLog "Automatización antigua de Google Drive eliminada: $($Task.TaskPath)$($Task.TaskName)" OK
            }
            catch {
                Write-D3PL0YLog "No se pudo eliminar la tarea antigua $($Task.TaskName): $($_.Exception.Message)" WARN
            }
        }
    }

    $StartupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    if (Test-Path -LiteralPath $StartupFolder) {
        $Shell = New-Object -ComObject WScript.Shell
        foreach ($ShortcutFile in @(Get-ChildItem -LiteralPath $StartupFolder -Filter '*.lnk' -File -ErrorAction SilentlyContinue)) {
            try {
                $Shortcut = $Shell.CreateShortcut($ShortcutFile.FullName)
                $ShortcutText = '{0} {1}' -f ([string]$Shortcut.TargetPath), ([string]$Shortcut.Arguments)
                if ($ShortcutText -match '(?i)PrimerInicio\.ps1|[^\s"'']*Drive[^\s"'']*\.ps1') {
                    Remove-Item -LiteralPath $ShortcutFile.FullName -Force -ErrorAction Stop
                    $Removed++
                    Write-D3PL0YLog "Acceso de inicio antiguo eliminado: $($ShortcutFile.Name)" OK
                }
            }
            catch {
                Write-D3PL0YLog "No se pudo revisar el acceso de inicio $($ShortcutFile.Name): $($_.Exception.Message)" WARN
            }
        }
    }

    return [pscustomobject]@{
        Changes = $Removed
        Detail  = "$Removed automatizaciones antiguas de Google Drive eliminadas. D3PL0Y no crea sustitutas."
    }
}

function Ensure-LocalKnownFolders {
    $UserShellValues = [System.Collections.Generic.List[object]]::new()
    $ShellValues = [System.Collections.Generic.List[object]]::new()
    $Redirected = 0

    $UserShellPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'

    foreach ($Folder in $LocalKnownFolders) {
        $Relative = [string]$Folder.RelativePath
        $ExpandedTarget = Join-Path $env:USERPROFILE $Relative
        $ExpandableTarget = '%USERPROFILE%\' + $Relative

        New-Item -ItemType Directory -Path $ExpandedTarget -Force | Out-Null

        try {
            $Current = Get-ItemPropertyValue -LiteralPath $UserShellPath -Name ([string]$Folder.Name) -ErrorAction Stop
            $ExpandedCurrent = [Environment]::ExpandEnvironmentVariables([string]$Current).TrimEnd('\')
            if ($ExpandedCurrent -and $ExpandedCurrent -ne $ExpandedTarget.TrimEnd('\')) {
                $Redirected++
                Write-D3PL0YLog "Carpeta personal corregida: $($Folder.Name) apuntaba a '$Current'. Los datos antiguos no se eliminan." WARN
            }
        }
        catch {}

        $UserShellValues.Add(@{
            Name  = [string]$Folder.Name
            Value = $ExpandableTarget
            Kind  = 'ExpandString'
        })
        $ShellValues.Add(@{
            Name  = [string]$Folder.Name
            Value = $ExpandedTarget
            Kind  = 'String'
        })
    }

    $Changes = 0
    $Changes += Set-RegistryBatch -Hive CurrentUser `
        -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' `
        -Values ($UserShellValues.ToArray())
    $Changes += Set-RegistryBatch -Hive CurrentUser `
        -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' `
        -Values ($ShellValues.ToArray())

    if ($Changes -gt 0) {
        $Script:ExplorerRefreshNeeded = $true
    }

    return [pscustomobject]@{
        Changes = $Changes
        Detail  = "$($LocalKnownFolders.Count) carpetas personales verificadas; $Redirected redirecciones externas corregidas. No se movieron ni borraron datos existentes."
    }
}

function Apply-RegistryConfiguration {
    $Changes = 0

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Values @(
        @{ Name = 'SubscribedContent-338388Enabled'; Value = 0; Kind = 'DWord' }
        @{ Name = 'SubscribedContent-338389Enabled'; Value = 0; Kind = 'DWord' }
        @{ Name = 'SubscribedContent-353694Enabled'; Value = 0; Kind = 'DWord' }
        @{ Name = 'SubscribedContent-353696Enabled'; Value = 0; Kind = 'DWord' }
        @{ Name = 'SystemPaneSuggestionsEnabled';    Value = 0; Kind = 'DWord' }
        @{ Name = 'SilentInstalledAppsEnabled';      Value = 0; Kind = 'DWord' }
        @{ Name = 'SoftLandingEnabled';              Value = 0; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Policies\Microsoft\Windows\WindowsCopilot' -Values @(
        @{ Name = 'TurnOffWindowsCopilot'; Value = 1; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive LocalMachine -Path 'SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Values @(
        @{ Name = 'AllowTelemetry'; Value = 0; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive LocalMachine -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Values @(
        @{ Name = 'DisableWindowsConsumerFeatures'; Value = 1; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive LocalMachine -Path 'SYSTEM\CurrentControlSet\Control\FileSystem' -Values @(
        @{ Name = 'LongPathsEnabled'; Value = 1; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Values @(
        @{ Name = 'AppsUseLightTheme';    Value = 0; Kind = 'DWord' }
        @{ Name = 'SystemUsesLightTheme'; Value = 0; Kind = 'DWord' }
        @{ Name = 'ColorPrevalence';      Value = 1; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Values @(
        @{ Name = 'HideFileExt';        Value = 0; Kind = 'DWord' }
        @{ Name = 'Hidden';             Value = 1; Kind = 'DWord' }
        @{ Name = 'TaskbarAl';          Value = 1; Kind = 'DWord' }
        @{ Name = 'TaskbarDa';          Value = 0; Kind = 'DWord' }
        @{ Name = 'ShowTaskViewButton'; Value = 0; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\CurrentVersion\Search' -Values @(
        @{ Name = 'SearchboxTaskbarMode';      Value = 0; Kind = 'DWord' }
        @{ Name = 'SearchboxTaskbarModeCache'; Value = 0; Kind = 'DWord' }
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\DWM' -Values @(
        @{ Name = 'AccentColor';              Value = $D3PL0Y.AccentColor;       Kind = 'DWord' }
        @{ Name = 'ColorizationColor';        Value = $D3PL0Y.ColorizationColor; Kind = 'DWord' }
        @{ Name = 'EnableWindowColorization'; Value = 1;                         Kind = 'DWord' }
        @{ Name = 'ColorPrevalence';          Value = 1;                         Kind = 'DWord' }
    )

    $Palette = [byte[]](
        0x95,0xEF,0x81,0x00,
        0x45,0xE5,0x32,0x00,
        0x19,0xA1,0x15,0x00,
        0x10,0x7C,0x10,0x00,
        0x0E,0x6D,0x0E,0x00,
        0x08,0x4B,0x08,0x00,
        0x03,0x2B,0x03,0x00,
        0x4C,0x4A,0x48,0x00
    )

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' -Values @(
        @{ Name = 'AccentPalette';   Value = $Palette;                Kind = 'Binary' }
        @{ Name = 'AccentColorMenu'; Value = $D3PL0Y.AccentColor;     Kind = 'DWord' }
        @{ Name = 'StartColorMenu';  Value = $D3PL0Y.StartColorMenu;  Kind = 'DWord' }
    )

    if ($Changes -gt 0) {
        $Script:ExplorerRefreshNeeded = $true
    }

    return [pscustomobject]@{
        Changes = $Changes
        Detail  = "$Changes valores del Registro modificados; los valores ya correctos no se reescribieron."
    }
}

function Apply-CursorsAndWallpapers {
    $Changes = 0

    $CursorValues = [System.Collections.Generic.List[object]]::new()
    foreach ($Entry in $CursorMap.GetEnumerator()) {
        $CursorValues.Add(@{
            Name  = [string]$Entry.Key
            Value = Join-Path $Paths.Cursors ([string]$Entry.Value)
            Kind  = 'String'
        })
    }
    $CursorValues.Add(@{ Name = '';               Value = 'D3PL0Y'; Kind = 'String' })
    $CursorValues.Add(@{ Name = 'CursorBaseSize'; Value = 48;            Kind = 'DWord'  })

    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Control Panel\Cursors' -Values ($CursorValues.ToArray())
    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Control Panel\Mouse' -Values @(
        @{ Name = 'MouseSensitivity'; Value = $D3PL0Y.MouseSpeed; Kind = 'String' }
    )
    $Changes += Set-RegistryBatch -Hive CurrentUser -Path 'Software\Microsoft\Accessibility' -Values @(
        @{ Name = 'CursorType';  Value = 6;     Kind = 'DWord' }
        @{ Name = 'CursorColor'; Value = 65280; Kind = 'DWord' }
        @{ Name = 'CursorSize';  Value = 2;     Kind = 'DWord' }
    )

    $WallpaperFile = Join-Path $Paths.Wallpapers 'd3pl0y.png'
    $LockImage = Join-Path $Paths.Wallpapers 'lockscreen.png'

    if (-not (Test-Path -LiteralPath $WallpaperFile)) {
        throw "No existe el fondo esperado: $WallpaperFile"
    }
    if (-not (Test-Path -LiteralPath $LockImage)) {
        throw "No existe la pantalla de bloqueo esperada: $LockImage"
    }

    if (-not ('D3PL0YNativeMethodsV4' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class D3PL0YNativeMethodsV4
{
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(
        uint uiAction,
        uint uiParam,
        string pvParam,
        uint fWinIni
    );
}
'@
    }

    $CurrentWallpaper = $null
    try {
        $CurrentWallpaper = Get-ItemPropertyValue -LiteralPath 'HKCU:\Control Panel\Desktop' -Name 'WallPaper' -ErrorAction Stop
    }
    catch {}

    if ($Force -or $CurrentWallpaper -ne $WallpaperFile) {
        $Applied = [D3PL0YNativeMethodsV4]::SystemParametersInfo(20, 0, $WallpaperFile, 3)
        if (-not $Applied) {
            throw 'Windows no confirmó la aplicación del fondo de escritorio.'
        }
        $Changes++
    }

    $Changes += Set-RegistryBatch -Hive LocalMachine -Path 'SOFTWARE\Policies\Microsoft\Windows\Personalization' -Values @(
        @{ Name = 'LockScreenImage'; Value = $LockImage; Kind = 'String' }
    )

    if ($Changes -gt 0) {
        $Script:ExplorerRefreshNeeded = $true
    }

    return [pscustomobject]@{
        Changes = $Changes
        Detail  = "$Changes ajustes visuales modificados."
    }
}

function Refresh-InteractiveShell {
    if (-not $Script:ExplorerRefreshNeeded) {
        return [pscustomobject]@{
            Changes = 0
            Detail  = 'No había cambios visuales que recargar.'
        }
    }

    & rundll32.exe user32.dll,UpdatePerUserSystemParameters

    $Explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue
    if ($Explorer) {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        Start-Process explorer.exe
    }

    return [pscustomobject]@{
        Changes = 1
        Detail  = 'Entorno gráfico recargado una sola vez.'
    }
}

# =============================================================================
# EJECUCIÓN
# =============================================================================

try {
    $Script:Mutex = [System.Threading.Mutex]::new($false, 'Global\D3PL0Y')
    $Script:MutexAcquired = $Script:Mutex.WaitOne(0)
    if (-not $Script:MutexAcquired) {
        throw 'Ya hay otra instancia de D3PL0Y ejecutándose.'
    }

    Initialize-Log
    $Script:State = Read-D3PL0YState
    Set-D3PL0YStatus 'INICIANDO D3PL0Y'

    $Effective = [ordered]@{
        Project     = $D3PL0Y
        ManagedApps = $ManagedApps
        AppsToRemove = $AppsToRemove
        LocalKnownFolders = $LocalKnownFolders
        Assets      = $Assets
        Parameters  = [ordered]@{
            Force       = [bool]$Force
            UpdateApps  = [bool]$UpdateApps
            NoRestart   = [bool]$NoRestart
            OnlyPhase   = $OnlyPhase
            SkipPhase   = $SkipPhase
        }
    } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($EffectiveConfig, $Effective, ([System.Text.UTF8Encoding]::new($false)))

    $Banner = @"
============================================================
                           D3PL0Y
                Windows 11 Provisioning v4.0
============================================================
"@

    Write-Host $Banner -ForegroundColor Green
    Write-D3PL0YLog "$($D3PL0Y.Name) v$($D3PL0Y.Version)"
    Write-D3PL0YLog "Equipo: $env:COMPUTERNAME | Usuario: $env:USERNAME | PowerShell: $($PSVersionTable.PSVersion)"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Invoke-D3PL0YPhase -Key 'Preflight' -Name 'Comprobaciones previas' -Revision '4.0.0' `
        -FingerprintData $null -AlwaysRun -Critical -Action {
            $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
            if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw 'D3PL0Y debe ejecutarse como administrador.'
            }

            if (-not [Environment]::Is64BitOperatingSystem) {
                throw 'Se requiere Windows de 64 bits.'
            }

            $Os = Get-CimInstance Win32_OperatingSystem
            if ([version]$Os.Version -lt [version]'10.0.22000') {
                throw "Se requiere Windows 11. Versión detectada: $($Os.Version)."
            }

            $SystemDriveName = ([IO.Path]::GetPathRoot($env:SystemRoot)).TrimEnd('\').TrimEnd(':')
            $SystemDrive = Get-PSDrive -Name $SystemDriveName
            if ($SystemDrive.Free -lt $D3PL0Y.MinimumFreeSpaceBytes) {
                throw 'Hay menos de 5 GB libres en la unidad del sistema.'
            }

            $Script:WingetAvailable = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)
            if (-not $Script:WingetAvailable) {
                Write-D3PL0YLog 'WinGet no está disponible. La fase de aplicaciones fallará sin modificar las demás fases.' WARN
            }

            return [pscustomobject]@{
                Changes = 0
                Detail  = "Windows $($Os.Version); $([math]::Round($SystemDrive.Free / 1GB, 1)) GB libres; WinGet=$Script:WingetAvailable."
            }
        }

    Invoke-D3PL0YPhase -Key 'LegacyCleanup' -Name 'Eliminar automatizaciones antiguas de Google Drive' -Revision '4.0.0' `
        -FingerprintData @{ RemoveDriveHelperTasks = $true; RemoveStartupShortcuts = $true } -Action {
            Remove-ObsoleteDriveAutomation
        }

    Invoke-D3PL0YPhase -Key 'Power' -Name 'Configurar energía' -Revision '4.0.0' `
        -FingerprintData @{ Hibernate = $false; AcSleep = 0; DcSleep = 0; AcMonitor = 0; DcMonitor = 0 } -Action {
            Invoke-NativeCommand powercfg.exe @('-h', 'off') -Quiet | Out-Null
            Invoke-NativeCommand powercfg.exe @('/change', 'standby-timeout-ac', '0') -Quiet | Out-Null
            Invoke-NativeCommand powercfg.exe @('/change', 'monitor-timeout-ac', '0') -Quiet | Out-Null
            Invoke-NativeCommand powercfg.exe @('/change', 'standby-timeout-dc', '0') -Quiet | Out-Null
            Invoke-NativeCommand powercfg.exe @('/change', 'monitor-timeout-dc', '0') -Quiet | Out-Null
            return [pscustomobject]@{ Changes = 5; Detail = 'Hibernación y temporizadores de suspensión desactivados.' }
        }

    Invoke-D3PL0YPhase -Key 'Debloat' -Name 'Eliminar bloatware' -Revision '4.0.0' `
        -FingerprintData $AppsToRemove -Action {
            Remove-SelectedAppxPackages
        }

    Invoke-D3PL0YPhase -Key 'Registry' -Name 'Aplicar configuración de Windows' -Revision '4.0.0' `
        -FingerprintData @{
            AccentColor = $D3PL0Y.AccentColor
            MouseSpeed  = $D3PL0Y.MouseSpeed
            LongPaths   = $true
        } -AlwaysRun -Action {
            Apply-RegistryConfiguration
        }

    Invoke-D3PL0YPhase -Key 'KnownFolders' -Name 'Mantener carpetas personales en almacenamiento local' -Revision '4.0.0' `
        -FingerprintData $LocalKnownFolders -AlwaysRun -Action {
            Ensure-LocalKnownFolders
        }

    Invoke-D3PL0YPhase -Key 'Apps' -Name 'Verificar e instalar aplicaciones' -Revision '4.0.0' `
        -FingerprintData @{ Apps = $ManagedApps; UpdateApps = [bool]$UpdateApps } -AlwaysRun -Action {
            if (-not $Script:WingetAvailable) {
                throw 'WinGet no está disponible. Instala o repara App Installer y vuelve a ejecutar la fase Apps.'
            }
            Install-ManagedApplications
        }

    $AssetsRevision = '4.0.0'
    Invoke-D3PL0YPhase -Key 'Assets' -Name 'Sincronizar recursos visuales' -Revision $AssetsRevision `
        -FingerprintData $Assets -ComplianceTest {
            foreach ($Asset in $Assets) {
                if (-not (Test-Path -LiteralPath $Asset.Destination)) { return $false }
                if ((Get-Item -LiteralPath $Asset.Destination).Length -le 0) { return $false }
            }
            return $true
        } -Action {
            $CurrentAssetsFingerprint = Get-ObjectFingerprint -Revision $AssetsRevision -Data $Assets
            $RefreshExistingAssets = $Force -or -not $Script:State.Phases.ContainsKey('Assets') -or
                $Script:State.Phases['Assets'].Fingerprint -ne $CurrentAssetsFingerprint

            $AssetChanges = Sync-AssetBatch -AssetList ($Assets.ToArray()) -RefreshExisting:$RefreshExistingAssets
            return [pscustomobject]@{
                Changes = $AssetChanges
                Detail  = "$($Assets.Count) recursos verificados; $AssetChanges actualizados."
            }
        }

    Invoke-D3PL0YPhase -Key 'Visuals' -Name 'Aplicar cursores y fondos' -Revision '4.0.0' `
        -FingerprintData @{
            Cursors = $CursorMap
            Wallpaper = 'd3pl0y.png'
            LockScreen = 'lockscreen.png'
        } -AlwaysRun -Action {
            Apply-CursorsAndWallpapers
        }

    Invoke-D3PL0YPhase -Key 'Developer' -Name 'Optimizar entorno de desarrollo' -Revision '4.0.0' `
        -FingerprintData @{ GitLongPaths = $true } -AlwaysRun -Action {
            $Changed = 0
            if (Get-Command git.exe -ErrorAction SilentlyContinue) {
                $Current = (& git.exe config --system --get core.longpaths 2>$null | Out-String).Trim()
                if ($Current -ne 'true') {
                    Invoke-NativeCommand git.exe @('config', '--system', 'core.longpaths', 'true') -Quiet | Out-Null
                    $Changed++
                }
            }
            $DeveloperDetail = if ($Changed) {
                'Rutas largas activadas también en Git.'
            }
            else {
                'Git ya estaba optimizado o aún no estaba disponible.'
            }

            return [pscustomobject]@{
                Changes = $Changed
                Detail  = $DeveloperDetail
            }
        }

    Invoke-D3PL0YPhase -Key 'Shell' -Name 'Actualizar entorno gráfico' -Revision '4.0.0' `
        -FingerprintData @{ RefreshOnlyWhenChanged = $true } -AlwaysRun -Action {
            Refresh-InteractiveShell
        }

    Invoke-D3PL0YPhase -Key 'Cleanup' -Name 'Limpiar archivos temporales' -Revision '4.0.0' `
        -FingerprintData @{ LogRetention = $D3PL0Y.LogRetention } -AlwaysRun -Action {
            Remove-Item -Path "$($Paths.Cache)\*.download" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $WingetImportFile -Force -ErrorAction SilentlyContinue
            Remove-OldLogs
            return [pscustomobject]@{ Changes = 0; Detail = 'Caché temporal y logs antiguos revisados.' }
        }

    $ErrorCount = @($Script:Results | Where-Object Status -eq 'ERROR').Count
    $SkippedCount = @($Script:Results | Where-Object Status -eq 'SKIP').Count
    $FinalStatus = if ($ErrorCount -eq 0) { 'COMPLETADO' } else { 'COMPLETADO CON ERRORES' }
    $Elapsed = (Get-Date) - $Script:StartedAt

    $Summary = [ordered]@{
        Project        = $D3PL0Y.Name
        Version        = $D3PL0Y.Version
        Status         = $FinalStatus
        Computer       = $env:COMPUTERNAME
        User           = $env:USERNAME
        StartedAt      = $Script:StartedAt.ToString('s')
        FinishedAt     = (Get-Date).ToString('s')
        DurationSeconds = [math]::Round($Elapsed.TotalSeconds, 2)
        Changes        = $Script:Changes
        ErrorCount     = $ErrorCount
        WarningCount   = $Script:Warnings
        SkippedCount   = $SkippedCount
        LogFile        = $LogFile
        StateFile      = $StateFile
        Results        = $Script:Results
    }

    $SummaryJson = $Summary | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($SummaryFile, $SummaryJson, ([System.Text.UTF8Encoding]::new($false)))

    $ReadableSummary = @"
=================================
$($D3PL0Y.Name)
=================================

Versión: $($D3PL0Y.Version)
Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Estado: $FinalStatus
Equipo: $env:COMPUTERNAME
Usuario: $env:USERNAME
Duración: $([math]::Round($Elapsed.TotalSeconds, 1)) segundos
Cambios realizados: $($Script:Changes)
Fases omitidas: $SkippedCount
Errores: $ErrorCount
Avisos: $($Script:Warnings)
Log: $LogFile
Estado reanudable: $StateFile
Resumen JSON: $SummaryFile
"@
    [System.IO.File]::WriteAllText($LatestSummaryFile, $ReadableSummary, ([System.Text.UTF8Encoding]::new($false)))

    Set-D3PL0YStatus $FinalStatus
    $FinalLogLevel = if ($ErrorCount) { 'WARN' } else { 'OK' }
    Write-D3PL0YLog "D3PL0Y finalizado: $FinalStatus en $([math]::Round($Elapsed.TotalSeconds, 1)) segundos." $FinalLogLevel

    $PendingReboot = Test-PendingReboot
    $ShouldRestart = -not $NoRestart -and $ErrorCount -eq 0 -and ($Script:RestartRecommended -or $PendingReboot)

    if ($ShouldRestart) {
        Write-D3PL0YLog 'Hay cambios que recomiendan reiniciar. Reinicio programado en 60 segundos; usa shutdown /a para cancelarlo.' WARN
        shutdown.exe /r /t 60 /c "D3PL0Y v$($D3PL0Y.Version) completado"
    }
    elseif ($NoRestart) {
        Write-D3PL0YLog 'Reinicio automático omitido mediante -NoRestart.' SKIP
    }
    else {
        Write-D3PL0YLog 'No se necesita reiniciar el equipo.' SKIP
    }
}
catch {
    try {
        Set-D3PL0YStatus 'ERROR CRÍTICO'
        Write-D3PL0YLog "ERROR CRÍTICO: $($_.Exception.Message)" ERROR

        $Failure = [ordered]@{
            Project    = $D3PL0Y.Name
            Version    = $D3PL0Y.Version
            Status     = 'ERROR CRÍTICO'
            Computer   = $env:COMPUTERNAME
            User       = $env:USERNAME
            FinishedAt = (Get-Date).ToString('s')
            Error      = $_.Exception.ToString()
            Results    = $Script:Results
        } | ConvertTo-Json -Depth 8

        [System.IO.File]::WriteAllText($SummaryFile, $Failure, ([System.Text.UTF8Encoding]::new($false)))
    }
    catch {}

    exit 1
}
finally {
    if ($null -ne $Script:LogWriter) {
        Flush-D3PL0YLog
        $Script:LogWriter.Dispose()
    }

    if ($null -ne $Script:Mutex) {
        if ($Script:MutexAcquired) {
            try {
                $Script:Mutex.ReleaseMutex()
            }
            catch {}
        }
        $Script:Mutex.Dispose()
    }
}
