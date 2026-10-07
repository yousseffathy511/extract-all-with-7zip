# Extract All with 7-Zip

**Make Windows 11's right-click "Extract All" use 7-Zip, with one click and no clicking through 7-Zip's menus.**

Right-click any zip, rar, 7z, tar or gz file and choose **Extract All (7-Zip)**, right under **Share with**. Everything is extracted into a folder named after the archive, next to it, using fast 7-Zip instead of Windows' slow built-in extractor.

## ⬇️ Download

**[Download the latest version](../../releases/latest)**: open the release and click **`Extract-All-with-7-Zip.zip`** under *Assets*.

Free. No account and no ads. If 7-Zip isn't installed, it's downloaded for you from its official source.

## How to use (one click)

1. Unzip the download anywhere.
2. Double-click **`Extract All with 7-Zip.cmd`** and click **Yes** when Windows asks for permission.
   > If Windows shows *"Windows protected your PC"*, click **More info → Run anyway**. Windows shows this for any downloaded script that isn't from a large publisher.
3. Wait about 30 seconds. It sets everything up by itself and says **"All done!"**

That's it. Right-click any archive and choose **Extract All (7-Zip)**.

To change options or go back to the Windows default later, double-click **`Options and Undo.cmd`**.

## What it sets up

| | |
|---|---|
| ✅ Right-click **Extract All (7-Zip)** | Right under *Share with*, replacing Windows' own *Extract All…* |
| ✅ Toolbar **Extract all** button | Uses 7-Zip too |
| ✅ Hide *Ask Copilot* from the right-click menu | Can be turned off in *Options and Undo* |
| ✅ Survives Windows updates | Small startup task that puts the settings back if an update undoes them |
| ✅ 7-Zip | Downloaded and installed automatically if missing (via `winget`, or from www.7-zip.org) |

Works for zip, 7z, rar, tar, gz, tgz, bz2, xz, zst, lzh, arj, cpio, rpm, deb, dmg, squashfs and split `.001` archives. Select several archives to extract each one into its own folder.

> **About double-click:** this tool changes the **right-click** menu and toolbar, not which app opens an archive when you **double-click** it. On a home (non-domain) PC, Windows only lets *you* set the double-click default — no app can do it silently (that's Windows stopping file-type hijacking). To make 7-Zip the double-click default, double-click an archive once → pick **7-Zip File Manager** → tick **Always**. The right-click *Extract All (7-Zip)* works either way.

## Going back to the Windows default

- Double-click **`Options and Undo.cmd`** and click **Undo – back to Windows default** (tick *Undo also uninstalls 7-Zip* to remove 7-Zip too), **or**
- **Settings → Apps → Installed apps → Extract All with 7-Zip → Uninstall**.

Undo restores Windows' original right-click menu, toolbar button and file associations.

## For IT / power users

Run from an administrator PowerShell:

```powershell
# install with all options, no window
powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Install -Silent
#   options: -NoToolbar -NoCopilotHide -NoKeeper -NoExplorerRestart

# undo
powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Undo -Silent [-RemoveSevenZip]
```

<details>
<summary>What exactly it changes (all reversed by Undo)</summary>

- `HKLM\SOFTWARE\Classes\SystemFileAssociations\.<type>\shell\extract`: the *Extract All (7-Zip)* entry. It's registered PC-wide on purpose, because Windows 11 only shows built-in command names like `extract` in the top part of its new right-click menu when they're registered for the whole PC.
- `Shell Extensions\Blocked`: hides Windows' own Extract All handlers (and *Ask Copilot*, if chosen).
- `Explorer\CommandStore\shell\Windows.CompressedFile.extract`: the toolbar button. Windows' original definition is saved first and restored by Undo, and the key is handed back to TrustedInstaller.
- `C:\Program Files\Extract All with 7-Zip\`, the startup task *Extract All with 7-Zip keeper*, and an entry in *Settings → Apps*.

The whole tool is one readable PowerShell script: [`ExtractAllWith7Zip.ps1`](ExtractAllWith7Zip.ps1).
</details>

## Notes

- Made for and tested on **Windows 11 (25H2)**. On Windows 10 you get the classic right-click entry.
- This project isn't made by or affiliated with 7-Zip. [7-Zip](https://www.7-zip.org) is free software by Igor Pavlov.
- License: [MIT](LICENSE).
