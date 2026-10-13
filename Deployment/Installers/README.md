# Installers

Place local installation packages in this folder before running the deployment.
Installer binaries are intentionally excluded from GitHub.

| Application | Expected filename or pattern |
| --- | --- |
| Google Chrome Enterprise | `googlechromestandaloneenterprise64.msi` |
| Microsoft 365 Deployment Tool | `OfficeSetup.exe` |
| Slack | `Slack*.msix` |
| NinjaOne | `installer.msi` (preferred) or `NinjaOne*.msi` |
| RamSoft App Launcher | `RamSoftLauncherSetup.exe` |
| AutoHotkey v2 | `AutoHotkey_2*_setup.exe` |
| Razer Synapse | `RazerSynapseInstaller.exe` |

Run `Deployment\Download-Installers.ps1` from the project root to download the supported
public packages into this folder. Add customer-specific packages such as
NinjaOne and RamSoft manually. NinjaOne no longer requires a private URL file.

Generated NinjaOne packages contain organization enrollment information and
must never be committed.
