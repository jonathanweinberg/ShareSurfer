# ShareSurfer WebView2 Dashboard Viewer Concept

Status: concept branch
Scope: future signed Windows viewer for already-packaged standalone dashboards

## Purpose

The pre-1.0 release path now produces a fully built static dashboard package. A future Windows dashboard viewer should build on that stable package instead of replacing it.

The viewer is a small signed Windows executable that opens a local ShareSurfer standalone dashboard folder in Microsoft WebView2. It does not scan file shares, change permissions, call cloud services, or require a local web server.

## What This Branch Shows

- A proposed WPF/WebView2 project under `apps/ShareSurfer.DashboardViewer`.
- A viewer trust model for local dashboard packages.
- A release path that keeps static dashboard output as the source of truth.
- The intended signing boundary for a future signed executable.
- The operator workflow for opening a dashboard package on a review workstation.

## Why This Comes After Static Packaging

The static dashboard package remains the portable evidence artifact:

- `index.html`
- `sharesurfer-data.js`
- `dashboard-manifest.json`
- `assets/*`

That package works without an executable and should keep working in airgapped or nonpermissive environments. The WebView2 viewer adds a more enterprise-friendly Windows shell around the same files.

## Operator Workflow

1. Run the collector and validate exports.
2. Build a standalone dashboard folder with `scripts/New-ShareSurferStandaloneDashboard.ps1`.
3. Move the standalone dashboard folder through the approved transfer process.
4. Open the folder with `ShareSurfer Dashboard Viewer.exe`.
5. Review the dashboard locally. No scan rights are needed on the review workstation.

## Trust Model

The signed executable proves the viewer binary came from the ShareSurfer release pipeline. It does not automatically prove that a selected dashboard folder is trustworthy.

The viewer should verify local package evidence before loading:

| Evidence | Purpose |
| --- | --- |
| `dashboard-manifest.json` | Confirms this is a ShareSurfer dashboard package and shows row counts, generation time, and schema warnings. |
| `index.html` | Entry point for the static dashboard. |
| `sharesurfer-data.js` | Local data snapshot generated from CSV exports. |
| File hash manifest | Future package integrity proof for dashboard assets and data. |
| Release signature | Future Authenticode signature for the viewer executable and supporting binaries. |

Initial viewer behavior should be conservative:

- Load only local `file://` dashboard content.
- Block external navigation.
- Disable developer tools and default browser context menus in production builds.
- Do not enable host objects or web messages unless a future feature requires them.
- Show a clear warning if manifest, data script, or hash evidence is missing.

## Runtime Distribution Choice

The first production viewer should prefer the WebView2 Evergreen Runtime as a prerequisite because it keeps the viewer smaller and lets Microsoft service the runtime. A fixed-version runtime can be considered later for environments that require a bundled browser runtime and accept the larger package/update responsibility.

## Proposed Release Artifacts

Future signed release output should look like this:

```text
ShareSurfer-<version>/
  src/
  scripts/
  docs/
  interface/standalone-dashboard/dist/
  apps/ShareSurfer.DashboardViewer/
  viewer/
    ShareSurfer Dashboard Viewer.exe
    ShareSurfer Dashboard Viewer.exe.sigcheck.txt
    dashboard-viewer-manifest.json
  release-manifest.json
  SHA256SUMS.txt
```

The `release-manifest.json` should move from `UnsignedPre1.0` to a signed status only after the executable and release package have verifiable signatures.

## Signing Path

The future signing slice should:

1. Build the static dashboard.
2. Publish the WebView2 viewer for Windows.
3. Sign the viewer executable and required binaries with Authenticode.
4. Verify signatures.
5. Package the module, scripts, docs, static dashboard assets, viewer, manifest, and hash files.
6. Publish a GitHub release artifact with clear signed/unsigned status.

Signing should happen in release automation, not on collector workstations.

## Non-Goals

- No live remediation.
- No embedded web server.
- No cloud upload.
- No requirement that every ShareSurfer user run the viewer.
- No replacement for opening the static `index.html` directly.

## Open Decisions

- Whether the viewer should accept only a standalone dashboard folder or also build one from a raw export folder.
- Whether the hash manifest belongs in `New-ShareSurferStandaloneDashboard.ps1` or only in release packaging.
- Whether a future installer should require Evergreen WebView2 Runtime, ship an offline installer, or bundle a fixed runtime.
- Whether filtered owner review packets should be exportable from the viewer.

## References

- [Microsoft WebView2 runtime distribution guidance](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/deployment-distribution)
- [Evergreen vs fixed WebView2 Runtime](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/evergreen-vs-fixed-version)
- [Microsoft.Web.WebView2 NuGet package](https://www.nuget.org/packages/Microsoft.Web.WebView2)
