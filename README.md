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

## Folder layout

```text
ExRad_Workstation_Deployment/
|-- Branding/                 ExRad wallpaper
|-- Config/                   Non-secret deployment configuration
|-- Installers/               Local MSI, MSIX, and EXE packages
|-- Private/                  Ignored enrollment inputs
|-- Scripts/                  Modular deployment components
|   |-- AppCatalog.ps1        Application definitions
|   |-- ChromePolicies.ps1    Managed Chrome bookmarks
|   |-- DeploymentUI.ps1      Preflight window and workflow
|   |-- Gcpw.ps1              GCPW enrollment
|   |-- InstallerEngine.ps1   Detection and installation logic
|   |-- Tartarus.ps1          Synapse profile preparation
|   |-- UnattendedImage.ps1   Audit Mode and Sysprep image workflow
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
| AutoHotkey v2 | `AutoHotkey_2.0.26_setup.exe` |
| Google Credential Provider for Windows | `gcpwstandaloneenterprise64.exe` |
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

Optionally place `set_gcpw_token.reg` in `Private`. The preflight screen
will offer **Apply GCPW enrollment token**. The script reads only the
`EnrollmentToken` value for the approved Google CloudManagement policy key,
writes that value after installation, and verifies it without displaying it.
The file is ignored by Git and must remain private. Restart Windows after the
token is applied and before the first GCPW sign-in.

## Run

1. Create `Private\ninjaone-url.txt` and paste the generated NinjaOne
   Auto-installer URL into it. This ignored file must never be committed.
2. Run `Download-Installers.ps1`. It downloads public vendor installers and the
   local NinjaOne package, then verifies signatures or the published hash.
3. If GCPW enrollment is needed, add `Private\set_gcpw_token.reg`.
4. Add `RamSoftLauncherSetup.exe` to `Installers` manually because it is
   customer-specific.
5. Review `Config\Microsoft365-Configuration.xml` and the bookmarks in
   `Scripts\ChromePolicies.ps1`.
6. Double-click `START-EXRAD-DEPLOYMENT.bat` and approve the Administrator prompt.
7. Select the applications, GCPW token, wallpaper, and optional Tartarus profile
   preparation.
8. Click **Start Installation**.

## Optional generalized image workflow

On a reference PC, enter Windows Audit Mode, run the deployment, and manually
enable **Generalize image after deployment (Sysprep + shutdown)**. This option is
disabled outside Audit Mode and is never selected by **Select All**.

After the normal deployment finishes successfully, the script:

1. Prompts twice for a password of at least 12 characters for the local `Admin`
   account. The password is never saved in the repository.
2. Generates a temporary Windows answer file from
   `Config\Unattend-OOBE-Template.xml`.
3. Adds pre-login `SetupComplete.cmd` cleanup, with first-login cleanup as a
   fallback, to remove cached answer files containing the reversible password
   value.
4. Requests final confirmation, then runs `Sysprep /generalize /oobe /shutdown`.
5. Shuts down the reference PC so the generalized Windows volume can be captured
   offline with the organization's imaging tool.

The answer file creates a local `Admin` account without auto-logon and automates
the supported Windows 11 OOBE pages, so a deployed workstation should stop at
the Windows login screen. Microsoft warns against using `SkipMachineOOBE`, so
the template intentionally omits both legacy `SkipMachineOOBE` and
`SkipUserOOBE`. Unattend-created local accounts do not require interactive
security-question answers.

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
- Windows support information is configured under the standard OEM information
  key. Windows can display `Email: support@expertradiology.com` as the support
  provider and link `https://expertradiology.com` as the support website. The
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
