# Optional Native Viewer

The ShareSurfer native viewer is an optional Windows-first review helper for very large exports. It is not a replacement for the collector, `report.html`, or the packaged standalone dashboard. It is a non-web escape hatch for cases where browser or WebView2 memory limits make large evidence review painful.

The first version is a PowerShell WinForms script:

```powershell
powershell.exe -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-ShareSurferNativeViewer.ps1 `
  -ExportPath 'C:\ShareSurfer\exports\startup-scan'
```

## What It Does

- Opens a ShareSurfer export folder directly from disk.
- Shows CSV datasets such as `owner_review_packets.csv`, `findings.csv`, `conflicts.csv`, `evidence_confidence.csv`, `collection_errors.csv`, `permissioned_groups.csv`, and raw evidence tables.
- Loads table rows by page instead of building one large HTML or JavaScript payload.
- Uses native Windows forms. It does not use npm, Vite, a browser, WebView2, Electron, a web server, or internet access at runtime.

## When To Use It

Use the native viewer when:

- `report.html` refuses a large export with an inline-data guardrail.
- The standalone dashboard package is still too large or browser-limited for the review workstation.
- An admin needs a simple local table browser for a very large export folder.

Use `report.html` when:

- The export is small or moderate.
- A single portable HTML file is more important than large-data paging.

Use the packaged standalone dashboard when:

- Business owners need the richer guided dashboard experience.
- The export is large but still works well with chunked offline dashboard data.

## Validate Without Opening The GUI

Headless validation is useful for testing a transfer, CI, or a locked-down collector where a GUI is not appropriate:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-ShareSurferNativeViewer.ps1 `
  -ExportPath 'C:\ShareSurfer\exports\startup-scan' `
  -ValidateOnly
```

With `-PassThru`, the command returns a summary object with dataset names, row counts, byte counts, scan date, and ACL export mode:

```powershell
$viewerCheck = powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-ShareSurferNativeViewer.ps1 `
  -ExportPath 'C:\ShareSurfer\exports\startup-scan' `
  -ValidateOnly `
  -PassThru
```

## Runtime Notes

- The GUI mode is Windows-only.
- Start GUI mode with `powershell.exe -STA`; WinForms needs a single-threaded apartment session.
- The viewer reads CSV files from the export folder. It does not rescan shares and does not change permissions.
- It is intentionally plain in this first slice. A future signed .NET viewer can improve packaging, styling, search, and richer review workflows while preserving the same large-data principle: keep evidence on disk and page it into the UI as needed.

## Current Limitations

- Filtering/search is intentionally minimal in this first version.
- CSV paging uses simple offset paging; very deep pages in very large files may take longer because the reader must skip earlier rows.
- It is Windows-first. macOS and Linux users should use `report.html` or the packaged standalone dashboard.
- This is not signed as a standalone executable yet.
