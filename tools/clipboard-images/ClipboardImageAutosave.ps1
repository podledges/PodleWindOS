[CmdletBinding()]
param(
    [string]$DestinationPath = 'C:\Users\ayden\Pictures\Screenshots2',
    [string]$StateDirectory = "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\state"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
    throw 'ClipboardImageAutosave must be started in STA mode. Use Start-ClipboardImageAutosave.ps1.'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module "$PSScriptRoot\ClipboardImageAutosave.Core.psm1" -Force

$listenerType = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class PodleWindOSClipboardListener : NativeWindow, IDisposable
{
    private const int WM_CLIPBOARDUPDATE = 0x031D;
    private static readonly IntPtr HWND_MESSAGE = new IntPtr(-3);
    private bool disposed;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();

    public event EventHandler ClipboardUpdated;

    public PodleWindOSClipboardListener()
    {
        CreateParams parameters = new CreateParams();
        parameters.Caption = "PodleWindOS Clipboard Image Autosave";
        parameters.Parent = HWND_MESSAGE;
        CreateHandle(parameters);
        if (!AddClipboardFormatListener(Handle))
        {
            int error = Marshal.GetLastWin32Error();
            DestroyHandle();
            throw new InvalidOperationException("AddClipboardFormatListener failed with Win32 error " + error + ".");
        }
    }

    protected override void WndProc(ref Message message)
    {
        if (message.Msg == WM_CLIPBOARDUPDATE)
        {
            EventHandler handler = ClipboardUpdated;
            if (handler != null)
            {
                handler(this, EventArgs.Empty);
            }
        }
        base.WndProc(ref message);
    }

    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        if (Handle != IntPtr.Zero)
        {
            RemoveClipboardFormatListener(Handle);
            DestroyHandle();
        }
        GC.SuppressFinalize(this);
    }
}
'@
Add-Type -TypeDefinition $listenerType -ReferencedAssemblies System.Windows.Forms

function Write-HelperError {
    param([Parameter(Mandatory = $true)][string]$Message)

    try {
        [System.IO.Directory]::CreateDirectory($StateDirectory) | Out-Null
        $logPath = [System.IO.Path]::Combine($StateDirectory, 'errors.log')
        if ([System.IO.File]::Exists($logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 262144) {
            $oldPath = [System.IO.Path]::Combine($StateDirectory, 'errors.previous.log')
            Move-Item -LiteralPath $logPath -Destination $oldPath -Force
        }
        $line = '{0:o} | {1}' -f [DateTime]::Now, ($Message -replace '[\r\n]+', ' ')
        [System.IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine)
    }
    catch {
        # Error reporting must never interrupt the clipboard message loop.
    }
}

[System.IO.Directory]::CreateDirectory($DestinationPath) | Out-Null
[System.IO.Directory]::CreateDirectory($StateDirectory) | Out-Null

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
# Keep the deployed PodleShell mutex name across the ownership migration. This makes
# old and new source trees mutually exclusive during an explicit cutover.
$mutexName = 'Local\PodleShell.ClipboardImageAutosave.{0}' -f $identity.User.Value
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, ([ref]$createdNew))
if (-not $createdNew) {
    $mutex.Dispose()
    exit 0
}

$pidPath = [System.IO.Path]::Combine($StateDirectory, 'listener.pid')
$listener = $null
$clipboardHandler = $null
$script:lastImageHash = $null
$script:lastSequence = [PodleWindOSClipboardListener]::GetClipboardSequenceNumber()

try {
    $listener = New-Object PodleWindOSClipboardListener
    $clipboardHandler = [EventHandler] {
        $sequence = [PodleWindOSClipboardListener]::GetClipboardSequenceNumber()
        if ($sequence -eq $script:lastSequence) {
            return
        }
        $script:lastSequence = $sequence

        for ($attempt = 0; $attempt -lt 5; $attempt++) {
            $image = $null
            try {
                if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
                    $script:lastImageHash = $null
                    return
                }

                $image = [System.Windows.Forms.Clipboard]::GetImage()
                if ($null -eq $image) {
                    throw 'Clipboard advertised an image but returned no image data.'
                }

                $pngBytes = ConvertTo-ClipboardPngBytes -Image $image
                $result = Save-NewClipboardImage -PngBytes $pngBytes -DestinationPath $DestinationPath -PreviousHash $script:lastImageHash
                $script:lastImageHash = $result.Hash
                $pngBytes = $null
                return
            }
            catch {
                if ($attempt -eq 4) {
                    Write-HelperError -Message ('Could not save clipboard image after bounded retries: {0}' -f $_.Exception.Message)
                    return
                }
                Start-Sleep -Milliseconds (40 * ($attempt + 1))
            }
            finally {
                if ($null -ne $image) {
                    $image.Dispose()
                }
            }
        }
    }

    $listener.add_ClipboardUpdated($clipboardHandler)
    [System.IO.File]::WriteAllText($pidPath, ([string]$PID))
    [System.Windows.Forms.Application]::Run()
}
catch {
    Write-HelperError -Message ('Listener stopped unexpectedly: {0}' -f $_.Exception.Message)
    throw
}
finally {
    if ($null -ne $listener) {
        if ($null -ne $clipboardHandler) {
            $listener.remove_ClipboardUpdated($clipboardHandler)
        }
        $listener.Dispose()
    }
    if ([System.IO.File]::Exists($pidPath)) {
        $recordedPid = [System.IO.File]::ReadAllText($pidPath).Trim()
        if ($recordedPid -eq [string]$PID) {
            Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        }
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $identity.Dispose()
}
