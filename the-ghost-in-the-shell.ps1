# the ghost in the shell
# Ejecuta: .\the-ghost-in-the-shell.ps1 -Action Install
# Para quitarlo: .\the-ghost-in-the-shell.ps1 -Action Uninstall
param(
    [ValidateSet('Install', 'Start', 'Stop', 'Status', 'Uninstall', 'Launch', 'Run', 'Test')]
    [string]$Action = 'Status'
)

$ErrorActionPreference = 'Stop'
$taskName = 'the ghost in the shell'
$stateFolder = Join-Path $env:LOCALAPPDATA 'the-ghost-in-the-shell'
$pidPath = Join-Path $stateFolder 'worker.pid.json'

# Cambia estos dos valores si quieres otros tiempos.
$idleSeconds = 285       # 4 minutos y 45 segundos sin usar teclado ni mouse
$repeatSeconds = 60      # Repetir el movimiento cada minuto

function Get-GhostTask {
    Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

function Get-GhostWorker {
    if (-not (Test-Path -LiteralPath $pidPath)) { return $null }
    try {
        $record = Get-Content -LiteralPath $pidPath -Raw | ConvertFrom-Json
        $process = Get-Process -Id ([int]$record.pid) -ErrorAction Stop
        if ($process.StartTime.ToUniversalTime().Ticks -eq [long]$record.startedTicks) {
            return $process
        }
    } catch { }
    return $null
}

function Stop-GhostWorker {
    $worker = Get-GhostWorker
    if (-not $worker) { return }
    Stop-Process -Id $worker.Id -Force
    $worker.WaitForExit(5000) | Out-Null
    if (Get-GhostWorker) { throw 'The background process did not stop.' }
    Remove-Item -LiteralPath $pidPath -ErrorAction SilentlyContinue
}

switch ($Action) {
    'Install' {
        $powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $folder = Split-Path -Parent $PSCommandPath
        $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Action Launch'

        if (Get-GhostTask) { Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $stateFolder -Force | Out-Null
        Stop-GhostWorker

        $task = New-ScheduledTask `
            -Action (New-ScheduledTaskAction -Execute $powerShell -Argument $arguments -WorkingDirectory $folder) `
            -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $user) `
            -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited) `
            -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) `
            -Description 'Moves the mouse after inactivity while you are signed in.'

        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 2
        if (-not (Get-GhostWorker)) { throw 'The background process did not start.' }
        "Installed and started: $taskName"
        return
    }
    'Start' {
        if (-not (Get-GhostTask)) { throw 'Run -Action Install first.' }
        if (Get-GhostWorker) { 'Already running.'; return }
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 2
        if (-not (Get-GhostWorker)) { throw 'The background process did not start.' }
        'Started in the background.'
        return
    }
    'Stop' {
        if (Get-GhostTask) { Stop-ScheduledTask -TaskName $taskName }
        Stop-GhostWorker
        'Stopped. It will start again at your next sign-in.'
        return
    }
    'Status' {
        $task = Get-GhostTask
        $worker = Get-GhostWorker
        if (-not $task) { 'Not installed.' }
        elseif ($worker) { "Running in the background (PID $($worker.Id))." }
        else { 'Installed, but not running.' }
        return
    }
    'Launch' {
        if (Get-GhostWorker) { return }
        New-Item -ItemType Directory -Path $stateFolder -Force | Out-Null
        $powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Action Run'
        $worker = Start-Process -FilePath $powerShell -ArgumentList $arguments -WindowStyle Hidden -PassThru
        @{ pid = $worker.Id; startedTicks = $worker.StartTime.ToUniversalTime().Ticks } |
            ConvertTo-Json -Compress | Set-Content -LiteralPath $pidPath
        Start-Sleep -Milliseconds 700
        if (-not (Get-GhostWorker)) { throw 'The background process did not start.' }
        return
    }
    'Uninstall' {
        if (Get-GhostTask) {
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        Stop-GhostWorker
        Remove-Item -LiteralPath $pidPath -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stateFolder -ErrorAction SilentlyContinue
        'Stopped and removed from startup.'
        return
    }
}

# Funciones de Windows para leer la última actividad y mover el cursor.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class GhostMouse {
    [StructLayout(LayoutKind.Sequential)]
    public struct LastInputInfo {
        public uint Size;
        public uint Time;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MouseInput {
        public int X;
        public int Y;
        public uint Data;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Input {
        public uint Type;
        public MouseInput Mouse;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LastInputInfo info);

    [DllImport("user32.dll")]
    private static extern uint SendInput(uint count, ref Input input, int size);

    [DllImport("kernel32.dll")]
    private static extern uint GetTickCount();

    public static uint LastInputTime() {
        var info = new LastInputInfo();
        info.Size = (uint)Marshal.SizeOf(typeof(LastInputInfo));
        if (!GetLastInputInfo(ref info)) throw new InvalidOperationException("Cannot read last input time.");
        return info.Time;
    }

    public static uint Now() { return GetTickCount(); }
    public static uint MillisecondsSince(uint then) { return unchecked(Now() - then); }

    public static void MoveOnePixel() {
        var input = new Input();
        input.Type = 0;          // Mouse input
        input.Mouse.Flags = 1;   // Relative movement
        input.Mouse.X = 1;
        if (SendInput(1, ref input, Marshal.SizeOf(typeof(Input))) != 1)
            throw new InvalidOperationException("Cannot move the mouse.");
        input.Mouse.X = -1;
        if (SendInput(1, ref input, Marshal.SizeOf(typeof(Input))) != 1)
            throw new InvalidOperationException("Cannot move the mouse back.");
    }
}
'@

if ($Action -eq 'Test') {
    $before = [GhostMouse]::LastInputTime()
    Start-Sleep -Milliseconds 30
    [GhostMouse]::MoveOnePixel()
    if ([GhostMouse]::LastInputTime() -eq $before) { throw 'Windows did not register the movement.' }
    'Test passed: Windows registered the movement.'
    return
}

# Recordamos nuestro movimiento para distinguirlo del tuyo.
$ourLastInput = $null
$ourLastMove = $null

while ($true) {
    $lastInput = [GhostMouse]::LastInputTime()

    if ($null -ne $ourLastInput -and $lastInput -ne $ourLastInput) {
        $ourLastInput = $null   # Volviste a usar el equipo: reiniciamos la espera.
    }

    $shouldMove = if ($null -eq $ourLastInput) {
        [GhostMouse]::MillisecondsSince($lastInput) -ge ($idleSeconds * 1000)
    } else {
        [GhostMouse]::MillisecondsSince($ourLastMove) -ge ($repeatSeconds * 1000)
    }

    if ($shouldMove) {
        [GhostMouse]::MoveOnePixel()
        $ourLastInput = [GhostMouse]::LastInputTime()
        $ourLastMove = [GhostMouse]::Now()
    }

    Start-Sleep -Seconds 1
}
