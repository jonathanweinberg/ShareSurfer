# ShareSurfer Dashboard Viewer

Status: concept scaffold

This app is a proposed Windows WebView2 wrapper for ShareSurfer standalone dashboard folders. It is meant to show the future executable shape after the static dashboard package path is stable.

The viewer should remain small and boring:

- Open a local standalone dashboard folder.
- Validate that `index.html`, `sharesurfer-data.js`, and `dashboard-manifest.json` exist.
- Load the dashboard through WebView2.
- Block external navigation.
- Stay read-only.

## Local Build Sketch

On a Windows development workstation with the .NET SDK and WebView2 prerequisites:

```powershell
dotnet restore .\apps\ShareSurfer.DashboardViewer\ShareSurfer.DashboardViewer.csproj
dotnet publish .\apps\ShareSurfer.DashboardViewer\ShareSurfer.DashboardViewer.csproj `
  -c Release `
  -r win-x64 `
  --self-contained false `
  -o .\artifacts\dashboard-viewer
```

Open an existing standalone dashboard:

```powershell
.\artifacts\dashboard-viewer\ShareSurfer.DashboardViewer.exe C:\ShareSurfer\exports\scan-001\standalone-dashboard
```

## Signing Sketch

The viewer should be signed in release automation after `dotnet publish`, alongside signature verification and package hash generation. Signing is intentionally not implemented in this concept scaffold.
