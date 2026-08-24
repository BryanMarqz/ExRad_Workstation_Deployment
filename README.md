# ExRad Workstation Deployment

PowerShell-based Windows workstation deployment utility with a graphical app
selector. It installs locally supplied software packages, copies optional Razer
Tartarus keybindings, and configures managed Chrome bookmarks.

## Security

This public repository intentionally contains **no installer binaries** and no
enrollment tokens. In particular, do not commit a generated NinjaOne installer:
the MSI contains an organization/location enrollment token.

Download all installers from their official vendor portals and verify their
digital signatures before use.

## Required local files

Place these files beside `setup.ps1` after cloning or downloading the repository:

| Application | Expected filename/pattern |
| --- | --- |
| Google Chrome Enterprise | `googlechromestandaloneenterprise64.msi` |
| Microsoft 365 Deployment Tool | `OfficeSetup.exe` |
| Slack | `Slack*.msix` |
| NinjaOne | `NinjaOne-Agent*-Auto-*.msi` |
| RamSoft App Launcher | `RamSoftLauncherSetup.exe` |
| AutoHotkey v2 | `AutoHotkey_2.0.26_setup.exe` |
| Google Credential Provider for Windows | `gcpwstandaloneenterprise64.exe` |
| Razer Synapse | `RazerSynapseInstaller.exe` |

Installer binaries are ignored by Git and remain local to the deployment folder.

## Run

1. Create a local `ninjaone-url.txt` beside the scripts and paste the generated
   NinjaOne Auto-installer URL into it. This ignored file must never be committed.
2. Add `RamSoftLauncherSetup.exe` manually because it is customer-specific.
3. Review `configuration.xml` and the bookmarks in `setup.ps1`.
4. Double-click `run.bat` and approve the Administrator prompt. The launcher
   downloads and verifies any missing installers before opening the app selector.
5. Select the applications and optional Tartarus copy operation.
6. Click **Start Installation**.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Download-Installers.ps1
```

The command above is optional and can be used to run the download step by itself.
Use `-Force` to replace installers that have already been downloaded.

RamSoft is attempted silently first and falls back to its interactive installer
when necessary. Razer Synapse uses its interactive installer.

## Notes

- Designed for Windows PowerShell 5.1 and Windows 10/11.
- Microsoft 365 configuration installs Word while excluding the other listed apps.
- Tartarus files are copied to `Documents\Tartarus Keybindings` only when selected.
- Chrome receives managed bookmarks for RamSoft, Zetta Health, and Gmail.
