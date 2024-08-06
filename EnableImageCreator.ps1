# Image Creator is currently available only in the following regions – United States, France, UK, Australia, Canada, Italy and Germany.
# see https://support.microsoft.com/en-us/windows/use-image-creator-in-paint-to-generate-ai-art-107a2b3a-62ea-41f5-a638-7bc6e6ea718f

# This script changes the region ID inside mspaint.exe leveraging WinDbg (Preview)

# This is the script file contents for WinDbg(X)
# It sets a breakpoint in KernelBase.dll!GetGeoInfoW
# and sets the first parameter, Location, to 0xF4 which is United States 
# See https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
# Assumes 64-bit so uses the rcx register
$winDbgScript = @'
.symopt+ 0x40
bp kernelbase!GetGeoInfoW ".if (@$t0 == 0) {r @$t0 = 0}; .echo 'Hit count:'; r @$t0 = @$t0 + 1; .if (@rcx != 0xF4) { .echo 'Modifying rcx to 0xF4'; r @rcx = 0xF4 }; .if (@$t0 == 4) { .echo 'Detaching after 4 hits'; qqd } .else { g }"
g
'@

# Script file will be written to temp folder
$scriptFile = Join-Path -Path $env:TEMP -ChildPath 'windbg.txt'

# Arguments to pass to WinDbg(X)
$arguments = @"
-c `"`$`<$scriptFile`"
`"$mspaintPath`"
"@ -split "`n" | ForEach-Object { $_.Trim() }

# Write the script file
Set-Content -Path $scriptFile -Value $winDbgScript -ErrorAction Stop

try 
{
	 # Let's figure out where MSPaint is installed ...
 	 "Searching for Microsoft Paint..."
	 $mspaintPackage = Get-AppxPackage -Name *Microsoft.Paint* | Select-Object -First 1

    # Check if the Paint app package was found
    if (-not $mspaintPackage) 
    {
        throw "Paint app not found. Exiting script."
    }

    "Found Microsoft Paint at: $($mspaintPackage.InstallLocation)"
	 $mspaintPath = Join-Path $mspaintPackage.InstallLocation "PaintApp\mspaint.exe"

    
	 "Searching for WinDbg(X)..."
	 # Define the path for WinDbg Preview using LocalAppData special folder
    $windbgPreviewPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\WinDbgX.exe"

    # Determine the WinDbg path to use
    if (Test-Path $windbgPreviewPath) 
    {
        $windbgPath = $windbgPreviewPath
    } 
    else 
    {
        # Fallback to standard WinDbg
        $windbgPath = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\windbg.exe"
    }

    # Check if WinDbg is found
    if (-not (Test-Path $windbgPath)) 
    {
        throw "WinDbg(X) not found. Please ensure it is installed."
    }

	 "Found WingDbg(X) at: $($windbgPath)"
    # Launch WinDbg with the determined path and arguments
    
	 "Start WinDbg(X) and wait until if finishes"
	 
	 $psi = New-Object System.Diagnostics.ProcessStartInfo
	 $psi.FileName = $windbgPath
	 $psi.RedirectStandardError = $true
	 $psi.RedirectStandardOutput = $true
	 $psi.UseShellExecute = $false
	 $psi.Arguments = $arguments
	 $process = New-Object System.Diagnostics.Process
	 $process.StartInfo = $psi
	 $process.Start() | Out-Null
	 $process.WaitForExit()
	 
	 if (0 -ne $process.ExitCode)
	 {
	 	
		"WinDbg(X) failed with error: $(New-Object System.ComponentModel.Win32Exception($process.ExitCode))"
	 }
	 else
	 {
	 	"No errors returned"
	 }
}
finally 
{
    # Ensure we remove the script file
    if (Test-Path $scriptFile) 
    {
        Remove-Item -Path $scriptFile -Force
    }
}
