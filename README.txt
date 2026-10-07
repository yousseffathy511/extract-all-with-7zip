Extract All with 7-Zip  -  free tool, version 1.0.1
====================================================

What it does (Windows 11)
-------------------------
* Right-click any zip, rar, 7z, tar, gz ... file  ->  "Extract All (7-Zip)",
  right under "Share with". One click extracts everything into a folder with the
  archive's name, next to the archive. Works on several selected archives at once.
  Windows' own slow "Extract All..." is hidden.
* The "Extract all" button in File Explorer's toolbar uses 7-Zip too.
* Hides "Ask Copilot" from the right-click menu               (optional)
* Keeps all of this after Windows updates (small startup task) (optional)
* If 7-Zip isn't installed, it is downloaded and installed automatically
  (free, from the official source: winget / www.7-zip.org).

How to use
----------
1. Unzip this folder anywhere.
2. Double-click  "Extract All with 7-Zip.cmd"  and click "Yes" when Windows asks
   for administrator permission.
   (If Windows shows "Windows protected your PC", click "More info" -> "Run anyway".
    That message appears for any downloaded script that isn't from a big publisher.)
3. Click "Install / Apply". When it asks, let it restart File Explorer.

Going back to the Windows default
---------------------------------
* Open the tool again and click "Undo - back to Windows default"
  (tick "Undo also uninstalls 7-Zip" to remove 7-Zip as well), or
* Settings -> Apps -> Installed apps -> "Extract All with 7-Zip" -> Uninstall.

For IT / power users (run in an administrator PowerShell)
---------------------------------------------------------
  powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Install -Silent
      options: -NoToolbar -NoCopilotHide -NoKeeper -NoExplorerRestart
  powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Undo -Silent [-RemoveSevenZip]

What it changes (all undone by Undo)
------------------------------------
* HKLM\SOFTWARE\Classes\SystemFileAssociations\.<archive type>\shell\extract  (the 7-Zip entry)
* Shell Extensions\Blocked: Windows' own Extract All handlers (and Ask Copilot, if chosen)
* The toolbar command Windows.CompressedFile.extract (Windows' original is saved and restored)
* C:\Program Files\Extract All with 7-Zip\  +  startup task "Extract All with 7-Zip keeper"
* An entry in Settings -> Apps -> Installed apps

About double-click
------------------
This tool does NOT change which app opens an archive when you DOUBLE-CLICK it. On a home
(non-domain) PC, Windows only lets YOU set that, to stop programs hijacking your files -
no app, including this one, can do it silently. To make 7-Zip the double-click default,
double-click an archive once, pick "7-Zip File Manager" and tick "Always" (per type), or
set it in Settings > Default apps. The right-click "Extract All (7-Zip)" works regardless.

Notes
-----
* Made and tested on Windows 11 25H2. Windows 10 gets the classic right-click entry.
* Not made by or affiliated with 7-Zip. 7-Zip is free software by Igor Pavlov (www.7-zip.org).
