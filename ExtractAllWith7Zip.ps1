<#
    Extract All with 7-Zip   -   free tool, version 1.0.1
    =========================================================
    Makes Windows 11 use 7-Zip for "Extract All":
      * Right-click any archive -> "Extract All (7-Zip)", right under "Share with"
        (it replaces Windows' own "Extract All...").
      * The "Extract all" button in File Explorer's toolbar runs 7-Zip.
      * Double-click opens archives in 7-Zip                          (optional)
      * Hides "Ask Copilot" from the right-click menu                 (optional)
      * A small startup task puts everything back if a Windows update
        undoes it                                                     (optional)
    7-Zip itself is downloaded and installed if it is missing (free, official source).
    "Undo" puts everything back to the Windows default and can uninstall 7-Zip too.

    This tool is not made by or affiliated with 7-Zip. 7-Zip is free software by Igor Pavlov.

    How to use:  double-click "Extract All with 7-Zip.cmd"  (asks for administrator permission once)

    Command line (works from any PowerShell; asks for admin permission if needed):
      ExtractAllWith7Zip.ps1 -Install -Silent [-NoToolbar] [-NoCopilotHide] [-NoKeeper]
      ExtractAllWith7Zip.ps1 -Undo    -Silent [-RemoveSevenZip]
      Add -NoExplorerRestart to skip restarting File Explorer at the end.
#>
[CmdletBinding()]
param(
    [switch]$Install, [switch]$Undo, [switch]$Keep, [switch]$Silent, [switch]$RemoveSevenZip,
    [switch]$NoToolbar, [switch]$NoCopilotHide, [switch]$NoKeeper, [switch]$NoExplorerRestart
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------ constants
$AppName      = 'Extract All with 7-Zip'
$AppVersion   = '1.0.1'
$Marker       = 'hidden by Extract All with 7-Zip'
$InstallDir   = Join-Path $env:ProgramFiles 'Extract All with 7-Zip'
$ScriptName   = 'ExtractAllWith7Zip.ps1'
$TaskName     = 'Extract All with 7-Zip keeper'
$SettingsKey  = 'SOFTWARE\ExtractAllWith7Zip'
$UninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ExtractAllWith7Zip'
$BlockedKey   = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'
$ToolbarKey   = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\Windows.CompressedFile.extract'
$CapsKey      = 'SOFTWARE\ExtractAllWith7Zip\Capabilities'
$RegAppName   = '7-Zip File Manager'
# names used by an earlier hand-made version of this setup - cleaned up automatically
$LegacyTask   = '7-Zip Extract All keeper'
$LegacyDir    = Join-Path $env:ProgramFiles '7-Zip ExtractAll Keeper'

# archive types -> icon number inside 7-Zip's 7z.dll
$Icons = [ordered]@{
    '7z'=0; 'zip'=1; 'rar'=3; 'tar'=13; 'gz'=14; 'gzip'=14; 'tgz'=14; 'tpz'=14; 'bz2'=2; 'bzip2'=2
    'tbz'=2; 'tbz2'=2; 'xz'=23; 'txz'=23; 'zst'=26; 'tzst'=26; 'lzma'=16; 'z'=5; 'taz'=5; 'arj'=4
    'lzh'=6; 'lha'=6; 'cpio'=12; 'rpm'=10; 'deb'=11; 'dmg'=17; 'xar'=19; 'squashfs'=24; 'apfs'=25; '001'=9
}
$Exts = @($Icons.Keys)

# Windows' own "Extract All..." right-click handlers
$WindowsExtractMenus = [ordered]@{
    '{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af}' = 'Windows Extract All (zip)'
    '{EE07CEF5-3441-4CFB-870A-4002C724783A}' = 'Windows Extract All (7z, rar, tar and others)'
}
# "Ask Copilot" right-click entry (current and older Copilot versions)
$CopilotMenus = [ordered]@{
    '{ED215C26-C810-49CE-929E-31D7E83A82E9}' = 'Ask Copilot'
    '{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}' = 'Ask Copilot (older versions)'
}

$LM = [Microsoft.Win32.Registry]::LocalMachine
$CU = [Microsoft.Win32.Registry]::CurrentUser
$script:Form = $null
$script:LogBox = $null
$script:LogLines = New-Object System.Collections.Generic.List[string]

if (-not ('EA7Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class EA7Native {
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr h, uint access, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool LookupPrivilegeValue(string sys, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool disableAll, ref TOKPRIV np, int len, IntPtr prev, IntPtr ret);
    [StructLayout(LayoutKind.Sequential, Pack=4)] struct TOKPRIV { public int Count; public long Luid; public int Attr; }
    public static bool EnablePrivilege(string name) {
        IntPtr tok; if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, 0x28, out tok)) return false;
        long luid; if (!LookupPrivilegeValue(null, name, out luid)) return false;
        TOKPRIV tp; tp.Count = 1; tp.Luid = luid; tp.Attr = 2;
        return AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
    [DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
    [DllImport("shlwapi.dll", CharSet=CharSet.Unicode)] static extern int AssocQueryString(int flags, int str, string assoc, string extra, StringBuilder outp, ref int cch);
    public static string AssocExe(string ext) {
        int n = 1024; var sb = new StringBuilder(n);
        return AssocQueryString(0, 2, ext, "open", sb, ref n) == 0 ? sb.ToString() : "";
    }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
}

# ------------------------------------------------------------------ helpers
function Pump { if ($script:Form) { [System.Windows.Forms.Application]::DoEvents() } }

function Write-Log([string]$Text) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text
    $script:LogLines.Add($line)
    if ($script:LogBox) { $script:LogBox.AppendText($line + "`r`n"); Pump }
    elseif (-not $Keep) { Write-Host $line }
}

function Start-Hidden([string]$Exe, [string]$Arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo($Exe, $Arguments)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    while (-not $p.HasExited) { Pump; Start-Sleep -Milliseconds 200 }
    return $p.ExitCode
}

function Get-SevenZipDir {
    foreach ($view in 'Registry64', 'Registry32') {
        try {
            $k = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', $view).OpenSubKey('SOFTWARE\7-Zip')
            if ($k) {
                foreach ($n in 'Path64', 'Path') {
                    $p = $k.GetValue($n)
                    if ($p -and (Test-Path -LiteralPath (Join-Path $p '7zG.exe'))) { $k.Close(); return $p.TrimEnd('\') }
                }
                $k.Close()
            }
        } catch { }
    }
    foreach ($p in "$env:ProgramFiles\7-Zip", "${env:ProgramFiles(x86)}\7-Zip") {
        if ($p -and (Test-Path -LiteralPath (Join-Path $p '7zG.exe'))) { return $p }
    }
    return $null
}

function Get-ExtractCommand([string]$Dir) { return "`"$Dir\7zG.exe`" x `"%1`" -o`"%1\..\*`" -spe" }

function Send-AssocChanged { [EA7Native]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero) }

# ------------------------------------------------------------------ 7-Zip download / removal
function Install-SevenZip {
    Write-Log '7-Zip is not installed - getting it now (free, official source) ...'
    $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wg) {
        Write-Log '  Installing with winget (Windows'' own app installer) ...'
        $code = Start-Hidden $wg.Source 'install --id 7zip.7zip --exact --silent --scope machine --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget'
        if (Get-SevenZipDir) { Write-Log '  7-Zip installed.'; return }
        Write-Log "  winget could not install it (code $code) - downloading from www.7-zip.org instead ..."
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $arch = (Get-CimInstance Win32_Processor | Select-Object -First 1).Architecture
    $suffix = switch ($arch) { 12 { '-arm64' } 9 { '-x64' } default { '' } }
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExtractAllWith7Zip')
    $html = $wc.DownloadString('https://www.7-zip.org/download.html')
    # The page lists several versions (the newest is hosted on 7-Zip's official GitHub) - pick the newest one.
    $pattern = '(?:https://github\.com/ip7z/7zip/releases/download/[0-9.]+/|a/)7z(\d{3,4})' + [regex]::Escape($suffix) + '\.exe'
    $best = $null; $bestVersion = -1
    foreach ($m in [regex]::Matches($html, $pattern)) {
        $v = [int]$m.Groups[1].Value
        if ($v -gt $bestVersion) { $bestVersion = $v; $best = $m.Value }
    }
    if (-not $best) { throw 'Could not find the 7-Zip download on www.7-zip.org.' }
    $url  = if ($best -like 'https://*') { $best } else { 'https://www.7-zip.org/' + $best }
    $file = Join-Path $env:TEMP ([IO.Path]::GetFileName($best))
    Write-Log "  Downloading $url ..."
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExtractAllWith7Zip')
    $task = $wc.DownloadFileTaskAsync($url, $file)
    while (-not $task.IsCompleted) { Pump; Start-Sleep -Milliseconds 150 }
    if ($task.IsFaulted) { throw $task.Exception.InnerException }
    if ((Get-Item -LiteralPath $file).Length -lt 500KB) { throw 'The 7-Zip download looks incomplete. Please try again.' }
    Write-Log '  Installing 7-Zip ...'
    [void](Start-Hidden $file '/S')
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 30 -and -not (Get-SevenZipDir); $i++) { Pump; Start-Sleep -Seconds 1 }
    if (Get-SevenZipDir) { Write-Log '  7-Zip installed.' }
}

function Uninstall-SevenZip {
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $apps = @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '7-Zip*' })
    if ($apps.Count -eq 0) { Write-Log '7-Zip is not installed.'; return }
    foreach ($a in $apps) {
        Write-Log "Uninstalling $($a.DisplayName) ..."
        if ($a.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
            [void](Start-Hidden "$env:windir\System32\msiexec.exe" "/x $($a.PSChildName) /qn /norestart")
        } else {
            $exe = [regex]::Match([string]$a.UninstallString, '"?([^"]+?\.exe)').Groups[1].Value
            if ($exe -and (Test-Path -LiteralPath $exe)) { [void](Start-Hidden $exe '/S') }
        }
    }
    for ($i = 0; $i -lt 60 -and (Get-SevenZipDir); $i++) { Pump; Start-Sleep -Seconds 1 }
    if (Get-SevenZipDir) { Write-Log '7-Zip is still partly installed - check Settings > Apps after a restart.' }
    else { Write-Log '7-Zip uninstalled.' }
}

# ------------------------------------------------------------------ hide / show right-click handlers
function Set-Blocked($Map, [switch]$IncludeUser) {
    $roots = @($LM); if ($IncludeUser) { $roots += $CU }
    foreach ($root in $roots) {
        $b = $root.CreateSubKey($BlockedKey)
        foreach ($id in $Map.Keys) { $b.SetValue($id, "$($Map[$id]) - $Marker") }
        $b.Close()
    }
}

function Remove-Blocked($Map, [switch]$OnlyOurs) {
    foreach ($root in @($LM, $CU)) {
        $b = $root.OpenSubKey($BlockedKey, $true)
        if (-not $b) { continue }
        foreach ($id in $Map.Keys) {
            $d = $b.GetValue($id)
            if ($null -ne $d -and (-not $OnlyOurs -or "$d" -like "*$Marker*")) { $b.DeleteValue($id, $false) }
        }
        $b.Close()
    }
}

function Test-Blocked($Map) {
    $b = $LM.OpenSubKey($BlockedKey)
    if (-not $b) { return $false }
    foreach ($id in $Map.Keys) { if ($null -eq $b.GetValue($id)) { $b.Close(); return $false } }
    $b.Close(); return $true
}

# ------------------------------------------------------------------ right-click "Extract All (7-Zip)"
# Registered PC-wide (HKLM). Windows 11 then shows it in the top part of its new menu,
# where Windows' own "Extract All..." used to be. A per-user copy would hide it, so it is removed.
function Set-ContextMenu([string]$Dir, [switch]$IncludeUser) {
    $cmd = Get-ExtractCommand $Dir
    foreach ($e in $Exts) {
        $v = $LM.CreateSubKey("SOFTWARE\Classes\SystemFileAssociations\.$e\shell\extract")
        $v.SetValue('', 'Extract All (7-Zip)')
        $v.SetValue('MultiSelectModel', 'Document')
        $v.SetValue('Icon', "$Dir\7zG.exe,0")
        $c = $v.CreateSubKey('command'); $c.SetValue('', $cmd); $c.Close(); $v.Close()
        if ($IncludeUser) { $CU.DeleteSubKeyTree("Software\Classes\SystemFileAssociations\.$e\shell\extract", $false) }
    }
    Set-Blocked $WindowsExtractMenus
    Write-Log ('Right-click "Extract All (7-Zip)" added for {0} archive types; Windows'' own "Extract All..." hidden.' -f $Exts.Count)
}

function Remove-ContextMenu {
    foreach ($e in $Exts) {
        $p = "SOFTWARE\Classes\SystemFileAssociations\.$e\shell\extract"
        $c = $LM.OpenSubKey("$p\command")
        $ours = ($null -ne $c) -and ("$($c.GetValue(''))" -like '*7zG.exe*')
        if ($c) { $c.Close() }
        if ($ours) { $LM.DeleteSubKeyTree($p, $false) }
        $CU.DeleteSubKeyTree("Software\Classes\SystemFileAssociations\.$e\shell\extract", $false)
    }
    Remove-Blocked $WindowsExtractMenus
    Write-Log 'Right-click menu: Windows'' own "Extract All..." is back.'
}

function Test-ContextMenu([string]$Dir) {
    $cmd = Get-ExtractCommand $Dir
    foreach ($e in $Exts) {
        $c = $LM.OpenSubKey("SOFTWARE\Classes\SystemFileAssociations\.$e\shell\extract\command")
        if (-not $c) { return $false }
        $ok = ($c.GetValue('') -eq $cmd); $c.Close()
        if (-not $ok) { return $false }
    }
    return (Test-Blocked $WindowsExtractMenus)
}

# ------------------------------------------------------------------ toolbar "Extract all" button
# Windows protects this key (owner: TrustedInstaller). We take ownership briefly, change it,
# and hand it back to TrustedInstaller afterwards.
function New-AdminRule {
    $admins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    New-Object System.Security.AccessControl.RegistryAccessRule($admins, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
}

function Grant-KeyAccess([string]$Path) {
    [void][EA7Native]::EnablePrivilege('SeTakeOwnershipPrivilege')
    [void][EA7Native]::EnablePrivilege('SeRestorePrivilege')
    $admins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $k = $LM.OpenSubKey($Path, 'ReadWriteSubTree', 'TakeOwnership')
    $s = New-Object System.Security.AccessControl.RegistrySecurity
    $s.SetOwner($admins); $k.SetAccessControl($s); $k.Close()
    $k = $LM.OpenSubKey($Path, 'ReadWriteSubTree', 'ChangePermissions, ReadPermissions')
    $s = $k.GetAccessControl(); $s.AddAccessRule((New-AdminRule)); $k.SetAccessControl($s); $k.Close()
}

function Restore-KeyOwner([string]$Path) {
    try {
        [void][EA7Native]::EnablePrivilege('SeTakeOwnershipPrivilege')
        [void][EA7Native]::EnablePrivilege('SeRestorePrivilege')
        $k = $LM.OpenSubKey($Path, 'ReadWriteSubTree', 'ChangePermissions, ReadPermissions, TakeOwnership')
        $s = $k.GetAccessControl()
        [void]$s.RemoveAccessRule((New-AdminRule))
        $s.SetOwner((New-Object System.Security.Principal.NTAccount('NT SERVICE', 'TrustedInstaller')))
        $k.SetAccessControl($s); $k.Close()
    } catch { Write-Log "  (note: could not hand the toolbar key back to Windows: $($_.Exception.Message))" }
}

function Get-ToolbarState {
    $k = $LM.OpenSubKey($ToolbarKey)
    if (-not $k) { return 'missing' }
    $c = $k.OpenSubKey('command')
    $cmd = if ($c) { "$($c.GetValue(''))" } else { '' }
    if ($c) { $c.Close() }
    $handler = $k.GetValue('ExplorerCommandHandler'); $k.Close()
    if ($cmd -like '*7zG.exe*' -and $null -eq $handler) { return '7zip' }
    return 'windows'
}

function Set-Toolbar([string]$Dir) {
    $state = Get-ToolbarState
    if ($state -eq 'missing') { Write-Log 'Toolbar button: not found on this Windows version - skipped.'; return }
    $cmd = Get-ExtractCommand $Dir
    if ($state -eq 'windows') {
        # keep a copy of Windows' original definition for Undo
        $k = $LM.OpenSubKey($ToolbarKey)
        $b = $LM.CreateSubKey("$SettingsKey\ToolbarBackup")
        foreach ($n in $k.GetValueNames()) { $b.SetValue($n, $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames'), $k.GetValueKind($n)) }
        $b.Close(); $k.Close()
    }
    Grant-KeyAccess $ToolbarKey
    $k = $LM.OpenSubKey($ToolbarKey, $true)
    foreach ($v in 'ExplorerCommandHandler', 'VerbList', 'InvokeCommandOnSelection', 'StaticVerbOnly', 'ResolveLinksQueryBehavior', 'CommandStateSync') { $k.DeleteValue($v, $false) }
    $k.SetValue('MultiSelectModel', 'Document')
    $c = $k.CreateSubKey('command'); $c.SetValue('', $cmd); $c.Close(); $k.Close()
    Restore-KeyOwner $ToolbarKey
    Write-Log 'Toolbar "Extract all" button now uses 7-Zip.'
}

function Restore-Toolbar {
    if ((Get-ToolbarState) -ne '7zip') { return }
    Grant-KeyAccess $ToolbarKey
    $k = $LM.OpenSubKey($ToolbarKey, $true)
    $k.DeleteSubKeyTree('command', $false)
    $k.DeleteValue('MultiSelectModel', $false)
    $b = $LM.OpenSubKey("$SettingsKey\ToolbarBackup")
    if ($b) {
        foreach ($n in $b.GetValueNames()) { $k.SetValue($n, $b.GetValue($n, $null, 'DoNotExpandEnvironmentNames'), $b.GetValueKind($n)) }
        $b.Close()
    } else {
        # Windows 11 defaults
        $k.SetValue('CommandStateSync', '', 'String')
        $k.SetValue('ExplorerCommandHandler', '{AFA470FE-371D-4F98-9592-39E3C7227E5C}', 'String')
        $k.SetValue('VerbList', [string[]]@('Windows.CompressedFolder.extract', 'Windows.CompressedItem.extract'), 'MultiString')
    }
    $k.Close()
    Restore-KeyOwner $ToolbarKey
    Write-Log 'Toolbar "Extract all" button: Windows'' extractor is back.'
}

# ------------------------------------------------------------------ double-click (default app) - cleanup only
# This tool does NOT change your double-click default app (Windows only lets the user set that for
# common types like .zip/.rar/.7z). These functions only UNDO any default-app registration a
# previous build may have made, so Undo fully restores Windows' defaults.

# Cleanup only: remove the default-apps policy if any earlier build set it (it is not used - it only
# works on company/domain-joined PCs, not home PCs, so this tool does not rely on it).
function Remove-DefaultAppPolicy {
    $pol = $LM.OpenSubKey('SOFTWARE\Policies\Microsoft\Windows\System', $true)
    if ($pol) {
        if ($null -ne $pol.GetValue('DefaultAssociationsConfiguration')) { $pol.DeleteValue('DefaultAssociationsConfiguration', $false) }
        $pol.Close()
    }
    Remove-Item -LiteralPath (Join-Path $InstallDir 'DefaultAssociations.xml') -Force -ErrorAction SilentlyContinue
}

function Remove-DefaultApp {
    foreach ($e in $Exts) {
        $prog = "7-Zip.$e"
        $LM.DeleteSubKeyTree("SOFTWARE\Classes\$prog", $false)
        $ow = $LM.OpenSubKey("SOFTWARE\Classes\.$e\OpenWithProgids", $true); if ($ow) { $ow.DeleteValue($prog, $false); $ow.Close() }
        $ck = $CU.OpenSubKey("Software\Classes\.$e", $true)
        if ($ck) {
            if ("$($ck.GetValue(''))" -like '7-Zip.*') { $ck.DeleteValue('', $false) }
            $ow = $ck.OpenSubKey('OpenWithProgids', $true); if ($ow) { $ow.DeleteValue($prog, $false); $ow.Close() }
            $ck.Close()
        }
        $CU.DeleteSubKeyTree("Software\Classes\$prog", $false)
        # the user's own choice, if it points to 7-Zip
        $fe = "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.$e"
        foreach ($uc in 'UserChoice', 'UserChoiceLatest') {
            $k = $CU.OpenSubKey("$fe\$uc")
            if (-not $k) { continue }
            $progId = "$($k.GetValue('ProgId'))"
            $sub = $k.OpenSubKey('ProgId'); if ($sub) { $progId += "$($sub.GetValue('ProgId'))"; $sub.Close() }
            $k.Close()
            if ($progId -match '7-Zip|7zFM') { try { $CU.DeleteSubKeyTree("$fe\$uc", $false) } catch { } }
        }
    }
    $ra = $LM.OpenSubKey('SOFTWARE\RegisteredApplications', $true); if ($ra) { $ra.DeleteValue($RegAppName, $false); $ra.Close() }
    $LM.DeleteSubKeyTree($CapsKey, $false)
    Remove-DefaultAppPolicy
    Send-AssocChanged
    Write-Log 'Double-click: 7-Zip default-apps policy removed (Windows default is back after you sign out and back in).'
}

# ------------------------------------------------------------------ keeper, settings, Apps entry
function Copy-Self {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $dest = Join-Path $InstallDir $ScriptName
    if ($PSCommandPath -and ($PSCommandPath -ne $dest)) { Copy-Item -LiteralPath $PSCommandPath -Destination $dest -Force }
    try { Unblock-File -LiteralPath $dest } catch { }
}

function Register-Keeper {
    $ps = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
    $file = Join-Path $InstallDir $ScriptName
    $action    = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`" -Keep"
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
        -Description 'Extract All with 7-Zip: puts the 7-Zip right-click and toolbar settings back if a Windows update undid them.' -Force | Out-Null
    Write-Log 'Startup task added: the settings are put back automatically if a Windows update undoes them.'
}

function Unregister-Keeper {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log 'Startup task removed.'
    }
}

function Save-Settings($Opt) {
    $k = $LM.CreateSubKey($SettingsKey)
    foreach ($n in 'ContextMenu', 'Toolbar', 'HideCopilot', 'Keeper') { $k.SetValue($n, [int][bool]$Opt[$n], 'DWord') }
    $k.SetValue('Version', $AppVersion); $k.SetValue('InstalledOn', (Get-Date -Format 's')); $k.Close()
}

function Get-Settings {
    $k = $LM.OpenSubKey($SettingsKey)
    if (-not $k) { return $null }
    $o = [ordered]@{}
    foreach ($n in 'ContextMenu', 'Toolbar', 'HideCopilot', 'Keeper') { $o[$n] = [bool]$k.GetValue($n, 0) }
    $k.Close(); return $o
}

function Register-Uninstall([string]$Dir) {
    $ps = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
    $base = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir $ScriptName)`""
    $u = $LM.CreateSubKey($UninstallKey)
    $u.SetValue('DisplayName', $AppName)
    $u.SetValue('DisplayVersion', $AppVersion)
    $u.SetValue('Publisher', 'Free tool (not made by 7-Zip)')
    $u.SetValue('DisplayIcon', "$Dir\7zFM.exe,0")
    $u.SetValue('InstallLocation', $InstallDir)
    $u.SetValue('UninstallString', "$base -Undo")
    $u.SetValue('QuietUninstallString', "$base -Undo -Silent")
    $u.SetValue('ModifyPath', $base)
    $u.SetValue('NoRepair', 1, 'DWord')
    $u.SetValue('EstimatedSize', 100, 'DWord')
    $u.SetValue('InstallDate', (Get-Date -Format 'yyyyMMdd'))
    $u.Close()
}

function Remove-Legacy {
    if (Get-ScheduledTask -TaskName $LegacyTask -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $LegacyTask -Confirm:$false
        Write-Log 'Removed an older startup task from a previous setup.'
    }
    if (Test-Path -LiteralPath $LegacyDir) { Remove-Item -LiteralPath $LegacyDir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Restart-Explorer {
    Write-Log 'Restarting File Explorer ...'
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    for ($i = 0; $i -lt 16; $i++) {
        Start-Sleep -Milliseconds 500; Pump
        if (Get-Process explorer -ErrorAction SilentlyContinue) { return }
    }
    # Windows normally restarts it by itself; if not, start it again without admin rights
    Start-Process "$env:windir\System32\runas.exe" -ArgumentList '/trustlevel:0x20000', "$env:windir\explorer.exe" -WindowStyle Hidden
}

# ------------------------------------------------------------------ the three actions
function Get-DefaultOptions {
    [ordered]@{ ContextMenu = $true; Toolbar = $true; HideCopilot = $true; Keeper = $true }
}

function Invoke-Install($Opt) {
    Write-Log "Setting up $AppName $AppVersion ..."
    Remove-Legacy
    $dir = Get-SevenZipDir
    if (-not $dir) {
        Install-SevenZip
        $dir = Get-SevenZipDir
        if (-not $dir) { throw '7-Zip could not be installed. Check the internet connection and try again, or install 7-Zip from www.7-zip.org first.' }
    } else {
        Write-Log "7-Zip found in $dir"
    }
    if ($Opt.ContextMenu) { Set-ContextMenu $dir -IncludeUser } else { Remove-ContextMenu }
    if ($Opt.Toolbar) { Set-Toolbar $dir } else { Restore-Toolbar }
    if ($Opt.HideCopilot) { Set-Blocked $CopilotMenus -IncludeUser; Write-Log '"Ask Copilot" hidden from the right-click menu.' }
    else { Remove-Blocked $CopilotMenus -OnlyOurs }
    Copy-Self
    if ($Opt.Keeper) { Register-Keeper } else { Unregister-Keeper }
    Save-Settings $Opt
    Register-Uninstall $dir
    Send-AssocChanged
    Write-Log 'Done. "Extract All with 7-Zip" is listed in Settings > Apps > Installed apps (to change or remove it later).'
}

function Invoke-Undo([switch]$RemoveSevenZip) {
    Write-Log 'Putting Windows back to its default ...'
    Remove-Legacy
    Unregister-Keeper
    Remove-ContextMenu
    Restore-Toolbar
    Remove-DefaultApp
    Remove-Blocked $CopilotMenus -OnlyOurs
    $LM.DeleteSubKeyTree($UninstallKey, $false)
    $LM.DeleteSubKeyTree($SettingsKey, $false)
    if ($RemoveSevenZip) { Uninstall-SevenZip }
    if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
    Send-AssocChanged
    Write-Log 'Done - Windows default restored.'
}

function Invoke-Keep {
    $s = Get-Settings
    if (-not $s) { Write-Log 'Not installed - nothing to do.'; return }
    $dir = Get-SevenZipDir
    if (-not $dir) { Write-Log '7-Zip is not installed - nothing to do.'; return }
    $changed = $false
    if ($s.ContextMenu -and -not (Test-ContextMenu $dir)) { Set-ContextMenu $dir; $changed = $true }
    if ($s.Toolbar -and (Get-ToolbarState) -eq 'windows') { Set-Toolbar $dir; $changed = $true }
    if ($s.HideCopilot -and -not (Test-Blocked $CopilotMenus)) { Set-Blocked $CopilotMenus; Write-Log 'Put back: "Ask Copilot" hidden.'; $changed = $true }
    if (-not $changed) { Write-Log 'Everything already in place - nothing changed.' }
}

function Get-State {
    $dir = Get-SevenZipDir
    $ver = if ($dir) { (Get-Item -LiteralPath (Join-Path $dir '7zFM.exe')).VersionInfo.ProductVersion } else { '' }
    $c = $LM.OpenSubKey('SOFTWARE\Classes\SystemFileAssociations\.zip\shell\extract\command')
    $verb = ($null -ne $c) -and ("$($c.GetValue(''))" -like '*7zG.exe*'); if ($c) { $c.Close() }
    [pscustomobject]@{
        SevenZip      = [bool]$dir
        Version       = $ver
        Menu          = $verb -and (Test-Blocked $WindowsExtractMenus)
        Toolbar       = (Get-ToolbarState) -eq '7zip'
        DoubleClick   = [EA7Native]::AssocExe('.zip') -like '*7zFM.exe'
        CopilotHidden = Test-Blocked $CopilotMenus
        Keeper        = [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
    }
}

# ------------------------------------------------------------------ window
function Initialize-WinForms {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [void][EA7Native]::SetProcessDPIAware()
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $script:Scale = $g.DpiX / 96.0; $g.Dispose()
}

function Show-Message([string]$Text, [string]$Buttons = 'OK', [string]$Icon = 'Information') {
    $owner = $script:Form
    $temp = $null
    if (-not $owner) {
        $temp = New-Object System.Windows.Forms.Form
        $temp.TopMost = $true; $temp.ShowInTaskbar = $false; $temp.Opacity = 0; $temp.StartPosition = 'CenterScreen'
        $temp.Show(); $owner = $temp
    }
    $r = [System.Windows.Forms.MessageBox]::Show($owner, $Text, $AppName, [System.Windows.Forms.MessageBoxButtons]$Buttons, [System.Windows.Forms.MessageBoxIcon]$Icon)
    if ($temp) { $temp.Close() }
    return [string]$r
}

function S([double]$n) { [int][Math]::Round($n * $script:Scale) }

function New-Ctl([string]$Type, $X, $Y, $W, $H, [string]$Text) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.Location = New-Object System.Drawing.Point((S $X), (S $Y))
    $c.Size = New-Object System.Drawing.Size((S $W), (S $H))
    if ($Text) { $c.Text = $Text }
    return $c
}

function Get-UiOptions {
    [ordered]@{
        ContextMenu = $script:ChkMenu.Checked
        Toolbar     = $script:ChkToolbar.Checked
        HideCopilot = $script:ChkCopilot.Checked
        Keeper      = $script:ChkKeeper.Checked
    }
}

function Update-Status {
    $st = Get-State
    $rows = @(
        [pscustomobject]@{ On = $st.SevenZip;      Yes = "7-Zip $($st.Version) is installed";                 No = '7-Zip is not installed (Install downloads it for free)' }
        [pscustomobject]@{ On = $st.Menu;          Yes = 'Right-click "Extract All" uses 7-Zip';               No = 'Right-click "Extract All" uses Windows' }
        [pscustomobject]@{ On = $st.Toolbar;       Yes = 'Toolbar "Extract all" button uses 7-Zip';            No = 'Toolbar "Extract all" button uses Windows' }
        [pscustomobject]@{ On = $st.CopilotHidden; Yes = '"Ask Copilot" is hidden from the right-click menu';  No = '"Ask Copilot" is shown in the right-click menu' }
        [pscustomobject]@{ On = $st.Keeper;        Yes = 'Protected: Windows updates can''t undo the settings'; No = 'Not protected against Windows updates' }
    )
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $lbl = $script:StatusLabels[$i]
        if ($rows[$i].On) {
            $lbl.Text = [string][char]0x2714 + '  ' + $rows[$i].Yes
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
        } else {
            $lbl.Text = [string][char]0x25CB + '  ' + $rows[$i].No
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
        }
    }
}

function Invoke-UiAction([string]$What) {
    foreach ($b in $script:Buttons) { $b.Enabled = $false }
    $script:Form.UseWaitCursor = $true
    try {
        if ($What -eq 'install') { Invoke-Install (Get-UiOptions) }
        else { Invoke-Undo -RemoveSevenZip:($script:ChkRemove.Checked) }
        Update-Status
        $r = Show-Message ("Done.`n`nRestart File Explorer now so the right-click menu updates?`n(Open File Explorer windows will close.)") 'YesNo' 'Question'
        if ($r -eq 'Yes') { Restart-Explorer; Write-Log 'All set. Right-click any archive to see it.' }
        else { Write-Log 'The changes show up after File Explorer or the PC restarts.' }
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        [void](Show-Message "Something went wrong:`n`n$($_.Exception.Message)" 'OK' 'Error')
    } finally {
        foreach ($b in $script:Buttons) { $b.Enabled = $true }
        $script:Form.UseWaitCursor = $false
    }
}

function Show-Window {
    Initialize-WinForms
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "$AppName $AppVersion"
    $f.ClientSize = New-Object System.Drawing.Size((S 600), (S 678))
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedSingle'
    $f.MaximizeBox = $false
    $f.BackColor = [System.Drawing.Color]::White
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $dir = Get-SevenZipDir
    if ($dir) { try { $f.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $dir '7zFM.exe')) } catch { } }
    $script:Form = $f

    $title = New-Ctl Label 20 12 560 34 'Extract All with 7-Zip'
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    $sub = New-Ctl Label 20 48 560 42 'Right-click any zip, rar or 7z file and choose "Extract All (7-Zip)", right under "Share with". Free. 7-Zip is downloaded from its official source if it is missing.'
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 70)

    $grpState = New-Ctl GroupBox 20 96 560 155 'Right now on this PC'
    $script:StatusLabels = @()
    for ($i = 0; $i -lt 5; $i++) {
        $l = New-Ctl Label 14 (26 + $i * 25) 535 24 ''
        $grpState.Controls.Add($l); $script:StatusLabels += $l
    }

    $grpOpt = New-Ctl GroupBox 20 261 560 150 'What to set up'
    $script:ChkMenu    = New-Ctl CheckBox 14 26  535 26 'Right-click "Extract All (7-Zip)", right under "Share with"'
    $script:ChkToolbar = New-Ctl CheckBox 14 54  535 26 'Toolbar "Extract all" button uses 7-Zip'
    $script:ChkCopilot = New-Ctl CheckBox 14 82  535 26 'Hide "Ask Copilot" from the right-click menu'
    $script:ChkKeeper  = New-Ctl CheckBox 14 110 535 26 'Keep these settings after Windows updates (small startup task)'
    $saved = Get-Settings
    if (-not $saved) { $saved = Get-DefaultOptions }
    $script:ChkMenu.Checked = $saved.ContextMenu; $script:ChkToolbar.Checked = $saved.Toolbar
    $script:ChkCopilot.Checked = $saved.HideCopilot; $script:ChkKeeper.Checked = $saved.Keeper
    $grpOpt.Controls.AddRange(@($script:ChkMenu, $script:ChkToolbar, $script:ChkCopilot, $script:ChkKeeper))

    $btnInstall = New-Ctl Button 20 428 170 40 'Install / Apply'
    $btnInstall.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
    $btnUndo    = New-Ctl Button 200 428 260 40 'Undo - back to Windows default'
    $btnClose   = New-Ctl Button 470 428 110 40 'Close'
    $script:ChkRemove = New-Ctl CheckBox 200 472 380 26 'Undo also uninstalls 7-Zip'
    $script:Buttons = @($btnInstall, $btnUndo, $btnClose)

    $script:LogBox = New-Ctl TextBox 20 506 560 158 ''
    $script:LogBox.Multiline = $true; $script:LogBox.ReadOnly = $true; $script:LogBox.ScrollBars = 'Vertical'
    $script:LogBox.BackColor = [System.Drawing.Color]::FromArgb(246, 246, 246)
    $script:LogBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)

    $btnInstall.Add_Click({ Invoke-UiAction 'install' })
    $btnUndo.Add_Click({
        $extra = if ($script:ChkRemove.Checked) { "`n`n7-Zip will be uninstalled too." } else { "`n`n7-Zip stays installed." }
        if ((Show-Message ("Put the right-click menu and toolbar back to the Windows default?" + $extra) 'YesNo' 'Question') -eq 'Yes') { Invoke-UiAction 'undo' }
    })
    $btnClose.Add_Click({ $script:Form.Close() })
    $f.Add_Shown({ $script:Form.Activate() })

    $f.Controls.AddRange(@($title, $sub, $grpState, $grpOpt, $btnInstall, $btnUndo, $btnClose, $script:ChkRemove, $script:LogBox))
    Update-Status
    Write-Log 'Ready. Choose what you want, then click "Install / Apply" - or "Undo" to go back to the Windows default.'
    [void]$f.ShowDialog()
}

# ------------------------------------------------------------------ main
if ($Keep) {
    # startup task (runs as SYSTEM): quietly put back anything a Windows update undid
    try { Invoke-Keep } catch { Write-Log "ERROR: $($_.Exception.Message)" }
    try { $script:LogLines | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'last-run.log') -Encoding UTF8 } catch { }
    exit 0
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass')
    if (-not $Silent) { $argList += @('-WindowStyle', 'Hidden') }
    $argList += @('-File', "`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) { if ($kv.Value -is [System.Management.Automation.SwitchParameter] -and $kv.Value.IsPresent) { $argList += "-$($kv.Key)" } }
    try {
        $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -PassThru -Wait:$Silent
        if ($Silent) { exit $p.ExitCode }
    } catch {
        if (-not $Silent) {
            Initialize-WinForms
            [void](Show-Message 'Administrator permission is needed to change the right-click menu. Please run it again and click "Yes".' 'OK' 'Warning')
        } else { Write-Host 'Administrator permission is needed.' }
        exit 1
    }
    exit 0
}

if ($Silent -and ($Install -or $Undo)) {
    try {
        if ($Install) {
            $opt = Get-DefaultOptions
            $opt.Toolbar = -not $NoToolbar; $opt.HideCopilot = -not $NoCopilotHide; $opt.Keeper = -not $NoKeeper
            Invoke-Install $opt
        } else {
            Invoke-Undo -RemoveSevenZip:$RemoveSevenZip
        }
        if (-not $NoExplorerRestart) { Restart-Explorer }
        exit 0
    } catch { Write-Log "ERROR: $($_.Exception.Message)"; exit 1 }
}

if ($Undo) {
    # started from Settings > Apps > Installed apps > Uninstall
    Initialize-WinForms
    $r = Show-Message "Remove ""$AppName"" and put Windows back to its default?`n`nYes  = remove it, keep 7-Zip installed`nNo   = remove it AND uninstall 7-Zip`nCancel = change nothing" 'YesNoCancel' 'Question'
    if ($r -eq 'Cancel') { exit 0 }
    try {
        Invoke-Undo -RemoveSevenZip:($r -eq 'No')
        Restart-Explorer
        [void](Show-Message 'Done. Windows is back to its default right-click menu and toolbar.' 'OK' 'Information')
    } catch { [void](Show-Message "Something went wrong:`n`n$($_.Exception.Message)" 'OK' 'Error') }
    exit 0
}

Show-Window
