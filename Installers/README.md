# Installers

Place local installation packages in this folder before running the deployment.
Installer binaries are intentionally excluded from GitHub.

| Application | Expected filename or pattern |
| --- | --- |
| Google Chrome Enterprise | `googlechromestandaloneenterprise64.msi` |
| Microsoft 365 Deployment Tool | `OfficeSetup.exe` |
| Slack | `Slack*.msix` |
| NinjaOne | `NinjaOne-Agent*-Auto-*.msi` |
| RamSoft App Launcher | `RamSoftLauncherSetup.exe` |
| AutoHotkey v2 | `AutoHotkey_2.0.26_setup.exe` |
| Google Credential Provider | `gcpwstandaloneenterprise64.exe` |
| Razer Synapse | `RazerSynapseInstaller.exe` |
| NVIDIA graphics driver | `NVIDIA-Driver*.exe` or the original NVIDIA filename |
| AMD graphics driver | `AMD-Driver*.exe` or the original AMD filename |

Run `Download-Installers.ps1` from the project root to download the supported
public packages into this folder. Add customer-specific packages such as
RamSoft manually.

Generated NinjaOne packages contain organization enrollment information and
must never be committed.
