# Extract All with 7-Zip

**Make Windows 11's right-click "Extract All" use 7-Zip, with one click and no clicking through 7-Zip's menus.**

Right-click any zip, rar, 7z, tar or gz file and choose **Extract All (7-Zip)**, right under **Share with**. Everything is extracted into a folder named after the archive, next to it, using fast 7-Zip instead of Windows' slow built-in extractor.

## ⬇️ Download

**[Download the latest version](../../releases/latest)**: open the release and click **`Extract-All-with-7-Zip.zip`** under *Assets*.

Free. No account and no ads. If 7-Zip isn't installed, it's downloaded for you from its official source.

## How to use

1. Unzip the download anywhere.
2. Double-click **`Extract All with 7-Zip.cmd`** and click **Yes** when Windows asks for administrator permission.
   > If Windows shows *"Windows protected your PC"*, click **More info → Run anyway**. Windows shows this for any downloaded script that isn't from a large publisher.
3. Click **Install / Apply**. When it asks, let it restart File Explorer.

That's it. Right-click any archive to see **Extract All (7-Zip)**.

## What it sets up

| | |
|---|---|
| ✅ Right-click **Extract All (7-Zip)** | Right under *Share with*, replacing Windows' own *Extract All…* |
| ✅ Toolbar **Extract all** button | Uses 7-Zip too |
| ☑️ Double-click opens archives in 7-Zip | Optional |
| ☑️ Hide *Ask Copilot* from the right-click menu | Optional |
| ☑️ Survives Windows updates | Optional small startup task that puts the settings back if an update undoes them |
| ✅ 7-Zip | Downloaded and installed automatically if missing (via `winget`, or from www.7-zip.org) |

Works for zip, 7z, rar, tar, gz, tgz, bz2, xz, zst, lzh, arj, cpio, rpm, deb, dmg, squashfs and split `.001` archives. Select several archives to extract each one into its own folder.

## Going back to the Windows default

- Open the tool again and click **Undo – back to Windows default** (tick *Undo also uninstalls 7-Zip* to remove 7-Zip too), **or**
- **Settings → Apps → Installed apps → Extract All with 7-Zip → Uninstall**.

Undo restores Windows' original right-click menu, toolbar button and file associations.

## For IT / power users

Run from an administrator PowerShell:

```powershell
# install with all options, no window
powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Install -Silent
#   options: -NoToolbar -NoDefaultApp -NoCopilotHide -NoKeeper -NoExplorerRestart

# undo
powershell -ExecutionPolicy Bypass -File ExtractAllWith7Zip.ps1 -Undo -Silent [-RemoveSevenZip]
```

<details>
<summary>What exactly it changes (all reversed by Undo)</summary>

- `HKLM\SOFTWARE\Classes\SystemFileAssociations\.<type>\shell\extract`: the *Extract All (7-Zip)* entry. It's registered PC-wide on purpose, because Windows 11 only shows built-in command names like `extract` in the top part of its new right-click menu when they're registered for the whole PC.
- `Shell Extensions\Blocked`: hides Windows' own Extract All handlers (and *Ask Copilot*, if chosen).
- `Explorer\CommandStore\shell\Windows.CompressedFile.extract`: the toolbar button. Windows' original definition is saved first and restored by Undo, and the key is handed back to TrustedInstaller.
- 7-Zip file-type registrations (if *double-click* is chosen). Windows 11 may ask you to confirm the default app once in *Settings → Default apps*.
- `C:\Program Files\Extract All with 7-Zip\`, the startup task *Extract All with 7-Zip keeper*, and an entry in *Settings → Apps*.

The whole tool is one readable PowerShell script: [`ExtractAllWith7Zip.ps1`](ExtractAllWith7Zip.ps1).
</details>

## Notes

- Made for and tested on **Windows 11 (25H2)**. On Windows 10 you get the classic right-click entry.
- This project isn't made by or affiliated with 7-Zip. [7-Zip](https://www.7-zip.org) is free software by Igor Pavlov.
- License: [MIT](LICENSE).
