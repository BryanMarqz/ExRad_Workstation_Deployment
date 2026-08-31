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
or `set_gcpw_token.reg`: both contain organization enrollment information.

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
| NVIDIA graphics driver | `NVIDIA-Driver*.exe` or `*-desktop-win10-win11-64bit-*-dch-whql.exe` |
| AMD graphics driver (optional) | `AMD-Driver*.exe` or `*amd-software-adrenalin-edition-*.exe` |

Installer binaries are ignored by Git and remain local to the deployment folder.

`Tartarus_Keybindings` contains the exported Synapse profile and its optional
AutoHotkey v2 actions:

- `Default-Profile.synapse4`
- `Play.ahk`
- `Record.ahk`

Optionally place `set_gcpw_token.reg` beside `setup.ps1`. The preflight screen
will offer **Apply GCPW enrollment token**. The script reads only the
`EnrollmentToken` value for the approved Google CloudManagement policy key,
writes that value after installation, and verifies it without displaying it.
The file is ignored by Git and must remain private. Restart Windows after the
token is applied and before the first GCPW sign-in.

## Run

1. Create a local `ninjaone-url.txt` beside the scripts and paste the generated
   NinjaOne Auto-installer URL into it. This ignored file must never be committed.
2. Run `Download-Installers.ps1`. It downloads public vendor installers and the
   local NinjaOne package, then verifies signatures or the published hash.
3. If GCPW enrollment is needed, add the private `set_gcpw_token.reg` file.
4. Add `RamSoftLauncherSetup.exe` manually because it is customer-specific.
5. Review `configuration.xml` and the bookmarks in `setup.ps1`.
6. Double-click `run.bat` and approve the Administrator prompt.
7. Select the applications, GCPW token, wallpaper, and optional Tartarus profile
   preparation.
8. Click **Start Installation**.

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
  decodes every base64 profile payload. If it finds an AHK path containing a
  different `C:\Users\<name>` value, it substitutes the current Windows
  username, re-encodes the payload, and recalculates the profile MD5 field.
- The prepared `.synapse4` file is kept in `Documents\Tartarus Keybindings` and
  staged in the detected Synapse 3 or Synapse 4 profile directory. Any included
  `.ahk` files are also copied to the current user's `Downloads` folder so
  exported launch paths remain valid.
- This workflow intentionally leaves the final import confirmation to the
  technician. On first Synapse launch, choose **Use without account**, open the
  profile import screen, and select the path displayed by the deployment
  completion message. Importing the prepared profile applies all mappings; the
  technician does not recreate them individually.
- AutoHotkey v2 detection checks system-wide and per-user installation paths,
  uninstall registry records, and executables available on `PATH`.
- Chrome receives managed bookmarks for RamSoft, Zetta Health, and Gmail.
- The included image in `Branding` is copied to
  `C:\ProgramData\ExpertRadiology\Branding`, applied immediately to the current
  desktop, seeded for new Windows profiles, and configured as the managed
  lock/sign-in image. Windows 11 Enterprise and Education honor the managed
  lock/sign-in policy most consistently; behavior can vary on unmanaged Pro
  editions.
- Graphics-driver packages are not downloaded automatically. Supply the correct
  package for the exact GPU, computer manufacturer, and Windows version.
- NVIDIA uses display-driver-only silent installation and is selected only when
  NVIDIA hardware is detected without its vendor driver.
- AMD is optional and excluded from **Select All**. The script does not disable
  the AMD iGPU; it only leaves its driver installation unchecked by default.
- AMD `minimalsetup_web` packages require internet access and technician input.
  Full offline AMD packages use unattended mode and fall back to the interactive
  installer if the AMD driver cannot be confirmed.
