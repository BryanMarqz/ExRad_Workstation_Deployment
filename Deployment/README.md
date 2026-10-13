# ExRad Workstation Deployment

PowerShell-based Windows workstation deployment utility with a graphical app
selector. It installs locally supplied software packages, copies optional Razer
Tartarus keybindings, applies ExRad desktop and lock/sign-in branding, and
configures managed Chrome bookmarks. It also configures the Windows About page
with **Expert Radiology**, **(415) 900-2000**, and the Expert Radiology website.

The preflight view shows the current state of every application before the
deployment starts: **Installed**, **Installer ready**, **Installer missing**,
**Download required**, or **Manual installation required**.

## Security

This public repository intentionally contains **no installer binaries** and no
enrollment tokens. In particular, do not commit a generated NinjaOne installer
because it contains organization enrollment information.

Download all installers from their official vendor portals and verify their
digital signatures or published SHA256 checksums before use.

## Folder layout

```text
ExRad_Workstation_Deployment/
|-- START-EXRAD-DEPLOYMENT.bat  Double-click this to begin
`-- Deployment/
    |-- Branding/             ExRad wallpaper
    |-- Config/               Microsoft 365 configuration
    |-- Installers/           Local MSI, MSIX, and EXE packages
    |-- Scripts/              Modular deployment components
    |-- Tartarus_Keybindings/ Synapse profile and AHK actions
    |-- Intune/
    |   `-- RadiologistBaseline/  Standalone Intune branding script
    |-- Download-Installers.ps1   Public installer downloader
    |-- setup.ps1             Component loader/entry point
    |-- README.md             Deployment instructions
    `-- LICENSE
```

Paths below are relative to `Deployment` unless stated otherwise. Git metadata
and `.gitignore` remain at the repository root.

Installer binaries inside `Deployment\Installers` remain ignored by Git. For backward
compatibility, `setup.ps1` also detects installers left beside the script, but
new downloads and manually supplied packages should use `Installers`.

## Required local files

Place these files in `Installers` after cloning or downloading the repository:

| Application | Expected filename/pattern |
| --- | --- |
| Google Chrome Enterprise | `googlechromestandaloneenterprise64.msi` |
| Microsoft 365 Deployment Tool | `OfficeSetup.exe` |
| Slack | `Slack*.msix` |
| NinjaOne | `installer.msi` (preferred) or `NinjaOne*.msi` |
| RamSoft App Launcher | `RamSoftLauncherSetup.exe` |
| AutoHotkey v2 | `AutoHotkey_2*_setup.exe` |
| Razer Synapse | `RazerSynapseInstaller.exe` |

Installer binaries are ignored by Git and remain local to the `Installers`
folder.

`Tartarus_Keybindings` contains the exported Synapse profile and its optional
AutoHotkey v2 actions:

- `Expert_Radiology.synapse4`
- `Fast_Foward.ahk`
- `Play_Pause.ahk`
- `Record.ahk`
- `Rewind.ahk`
- `Stop.ahk`

## Run

1. Run `Download-Installers.ps1` if you need the public vendor installers.
   It verifies their digital signatures or published
   SHA256 checksums.
2. Add the NinjaOne `installer.msi` and `RamSoftLauncherSetup.exe` to
   `Installers` manually. No private URL file is needed.
3. Review `Config\Microsoft365-Configuration.xml` and the bookmarks in
   `Scripts\ChromePolicies.ps1`.
4. Double-click `START-EXRAD-DEPLOYMENT.bat` at the repository root and approve
   the Administrator prompt.
5. All applications needing installation, Tartarus profile preparation,
   wallpaper, and dark mode are selected by default. Deselect any you do not need.
6. Click **Start Installation**. Installed applications are skipped; selected
   Tartarus and appearance settings are refreshed even if already configured.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Deployment\Download-Installers.ps1
```

Use `-Force` to replace installers that have already been downloaded.

RamSoft is attempted silently first and falls back to its interactive installer
when necessary. Razer Synapse uses its interactive installer.

## Notes

- Designed for Windows PowerShell 5.1 and Windows 10/11.
- Microsoft 365 configuration installs Word while excluding the other listed apps.
- When Tartarus profile preparation is selected, the script validates and
  decodes every base64 profile payload. It redirects embedded AHK paths to
  `Documents\Tartarus Keybindings`, re-encodes the payload, and recalculates
  the profile MD5 field.
- The prepared `.synapse4` file is kept in `Documents\Tartarus Keybindings` and
  staged in the detected Synapse 3 or Synapse 4 profile directory. Included
  `.ahk` files remain beside it in `Documents\Tartarus Keybindings`, which is
  also the location used by the imported launch mappings.
- This workflow intentionally leaves the final import confirmation to the
  technician. On first Synapse launch, choose **Use without account**, open the
  profile import screen, and select the path displayed by the deployment
  completion message. Importing the prepared profile applies all mappings; the
  technician does not recreate them individually.
- AutoHotkey v2 detection checks system-wide and per-user installation paths,
  uninstall registry records, and executables available on `PATH`. Installer
  discovery accepts any `AutoHotkey_2*_setup.exe` version and chooses the
  highest version when more than one is present. The downloader resolves the
  current AutoHotkey v2 release instead of pinning a version number.
- NinjaOne uses a locally supplied MSI and is selected by default, along with
  AutoHotkey and the other applications. **Select All** includes every application
  that still needs installation. The NinjaOne MSI is not downloaded automatically.
- Chrome receives managed bookmarks for RamSoft, RADAware, RADWorx, and Gmail.
- Windows dark mode is enabled by default for both apps and system surfaces. It
  is applied to the current user and seeded into the Default User profile so
  newly created Windows users inherit it.
- The included image in `Branding` is copied to
  `C:\ProgramData\ExpertRadiology\Branding`, applied immediately to the current
  desktop, seeded for new Windows profiles, and configured as the managed
  lock/sign-in image. Windows 11 Enterprise and Education honor the managed
  lock/sign-in policy most consistently; behavior can vary on unmanaged Pro
  editions.
- Windows OEM support information is configured with manufacturer **Expert
  Radiology**, phone **(415) 900-2000**, and online support URL
  **https://www.expertradiology.com/**. Windows controls the labels and their
  display order in the About page.
