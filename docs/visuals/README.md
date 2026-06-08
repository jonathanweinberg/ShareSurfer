# ShareSurfer Visual Assets

This folder contains user-facing workflow visuals and current example screenshots of the offline HTML report.

The report screenshots use synthetic CONTOSO-style demo data. They are meant to show first-time operators and management readers what the dashboard looks like before they run ShareSurfer. They are not live customer evidence or future-design mockups.

## Workflow Illustrations

The current workflow illustrations are:

- `share-surfer-workflow-concept.png`
- `nonpermissive-collector-workflow.png`
- `dataset-transfer-dashboard-workflow.png`
- `collector-to-report.svg`
- `enterprise-lab-validation.svg`
- `support-bundle-diagnostics.svg`

Use `nonpermissive-collector-workflow.png` when explaining read-only collection inside a restricted network. Use `dataset-transfer-dashboard-workflow.png` when explaining how a validated dataset moves to a separate dashboard review workstation.

## Report Screenshots

The current report screenshots are:

- `report-dashboard-overview.png`
- `report-dashboard-workbench.png`
- `report-dashboard-findings.png`
- `report-dashboard-migration.png`

Refresh them from a trusted docs-maintainer workstation when the dashboard layout changes:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\New-ShareSurferDashboardScreenshots.ps1
```

The script generates a synthetic export under `docs\.generated\dashboard-screenshots`, builds `report.html`, and captures the four screenshots with Playwright. Use this dry run when you only want to verify the report generation path without browser capture:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\New-ShareSurferDashboardScreenshots.ps1 -SkipBrowserCapture
```

If Playwright is not available, keep the existing screenshots and rerun the capture from a workstation where the Playwright Node package and browser binaries are installed.
