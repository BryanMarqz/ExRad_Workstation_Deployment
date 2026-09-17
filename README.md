# ExRad Workstation Deployment

PowerShell-based Windows workstation deployment utility with a graphical app
selector. It installs locally supplied software packages, copies optional Razer
Tartarus keybindings, applies ExRad desktop and lock/sign-in branding, and
configures managed Chrome bookmarks.

The preflight view shows the current state of every application before the
deployment starts: **Installed**, **Installer ready**, **Installer missing**,
**Download required**, **Manual installation required**, or **GPU not detected**.

## Security

This public repository intentionally contains **no installer binaries** and no
enrollment tokens. In particular, do not commit a generated NinjaOne installer
because it contains organization enrollment information.

Download all installers from their official vendor portals and verify their
digital signatures or published SHA256 checksums before use.

## Folder layout

```text
ExRad_Workstation_Deployment/
|-- Branding/                 ExRad wallpaper
|-- Config/                   Non-secret deployment configuration
|-- Installers/               Local MSI, MSIX, and EXE packages
|-- Private/                  Ignored NinjaOne enrollment input
|-- Scripts/                  Modular deployment components
|   |-- AppCatalog.ps1        Application definitions
|   |-- ChromePolicies.ps1    Managed Chrome bookmarks
|   |-- DeploymentUI.ps1      Preflight window and workflow
|   |-- InstallerEngine.ps1   Detection and installation logic
|   |-- Tartarus.ps1          Synapse profile preparation
|   |-- Wallpaper.ps1         Desktop and lock-screen branding
|   `-- WindowsSupport.ps1    Windows support-provider information
|-- Tartarus_Keybindings/     Synapse profile and AHK actions
|-- Download-Installers.ps1   Verified installer downloader
|-- START-EXRAD-DEPLOYMENT.bat  Double-click this to begin
`-- setup.ps1                 Small component loader/entry point
```

Installer binaries inside `Installers` remain ignored by Git. For backward
compatibility, `setup.ps1` also detects installers left beside the script, but
new downloads and manually supplied packages should use `Installers`.

## Required local files

Place these files in `Installers` after cloning or downloading the repository:

| Application | Expected filename/pattern |
| --- | --- |
| Google Chrome Enterprise | `googlechromestandaloneenterprise64.msi` |
| Microsoft 365 Deployment Tool | `OfficeSetup.exe` |
| Slack | `Slack*.msix` |
| NinjaOne | `NinjaOne-Agent*-Auto-*.msi` |
| RamSoft App Launcher | `RamSoftLauncherSetup.exe` |
| AutoHotkey v2 | `AutoHotkey_2*_setup.exe` |
| Razer Synapse | `RazerSynapseInstaller.exe` |
| NVIDIA graphics driver | `NVIDIA-Driver*.exe` or `*-desktop-win10-win11-64bit-*-dch-whql.exe` |
| AMD graphics driver (optional) | `AMD-Driver*.exe` or `*amd-software-adrenalin-edition-*.exe` |

Installer binaries are ignored by Git and remain local to the `Installers`
folder.

`Tartarus_Keybindings` contains the exported Synapse profile and its optional
AutoHotkey v2 actions:

- `Default-Profile.synapse4`
- `Play.ahk`
- `Record.ahk`

## Run

1. Create `Private\ninjaone-url.txt` and paste the generated NinjaOne
   Auto-installer URL into it. This ignored file must never be committed.
2. Run `Download-Installers.ps1`. It downloads public vendor installers and the
   local NinjaOne package, then verifies their digital signatures or published
   SHA256 checksums.
3. Add `RamSoftLauncherSetup.exe` to `Installers` manually because it is
   customer-specific.
4. Review `Config\Microsoft365-Configuration.xml` and the bookmarks in
   `Scripts\ChromePolicies.ps1`.
5. Double-click `START-EXRAD-DEPLOYMENT.bat` and approve the Administrator prompt.
6. Select the applications, wallpaper, and optional Tartarus profile
   preparation.
7. Click **Start Installation**.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Download-Installers.ps1
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
- NinjaOne is off by default and excluded from **Select All** so it can be
  installed separately after imaging without cloning an existing device
  identity.
- Chrome receives managed bookmarks for RamSoft, Zetta Health, and Gmail.
- The included image in `Branding` is copied to
  `C:\ProgramData\ExpertRadiology\Branding`, applied immediately to the current
  desktop, seeded for new Windows profiles, and configured as the managed
  lock/sign-in image. Windows 11 Enterprise and Education honor the managed
  lock/sign-in policy most consistently; behavior can vary on unmanaged Pro
  editions.
- Windows website information is configured under the standard OEM information
  key. Windows displays
  `support@expertradiology.com | expertradiology.com` as the provider link and
  opens `https://expertradiology.com` when it is selected. The
  exact placement varies by Windows 11 build; Windows does not offer a separate
  modern OEM email field.
- Graphics-driver packages are not downloaded automatically. Supply the correct
  package for the exact GPU, computer manufacturer, and Windows version.
- NVIDIA uses display-driver-only silent installation and is selected only when
  NVIDIA hardware is detected without its vendor driver.
- AMD is optional and excluded from **Select All**. The script does not disable
  the AMD iGPU; it only leaves its driver installation unchecked by default.
- AMD `minimalsetup_web` packages require internet access and technician input.
  Full offline AMD packages use unattended mode and fall back to the interactive
  installer if the AMD driver cannot be confirmed.
