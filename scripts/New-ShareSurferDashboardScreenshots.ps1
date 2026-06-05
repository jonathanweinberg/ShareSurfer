[CmdletBinding()]
param(
    [string] $OutputRoot = '',

    [string] $VisualOutputPath = '',

    [switch] $SkipBrowserCapture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (Join-Path $PSScriptRoot '..') 'docs\.generated\dashboard-screenshots'
}
if ([string]::IsNullOrWhiteSpace($VisualOutputPath)) {
    $VisualOutputPath = Join-Path (Join-Path $PSScriptRoot '..') 'docs\visuals'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleManifest = Join-Path $repoRoot 'src\ShareSurfer\ShareSurfer.psd1'
$exportPath = Join-Path $OutputRoot 'export'
$reportPath = Join-Path $OutputRoot 'report.html'
$captureScriptPath = Join-Path $OutputRoot 'capture-dashboard-screenshots.cjs'

function New-ShareSurferScreenshotDemoInventory {
    $longTail = ('QuarterlyCloseArchive-' + ('A' * 96) + '\' + ('VendorPacket-' + ('B' * 96)))
    $longPath = '\\files01\Finance\AccountsPayable\Vendors\' + $longTail

    [pscustomobject]@{
        Shares = @(
            [pscustomobject]@{ ShareId = 'share-finance'; Source = 'Demo'; ComputerName = 'files01'; ShareName = 'Finance'; UNCPath = '\\files01\Finance'; LocalPath = 'C:\ShareSurferLab\Finance'; Description = 'Finance shared data'; PartialData = $false; PartialReason = '' },
            [pscustomobject]@{ ShareId = 'share-operations'; Source = 'Demo'; ComputerName = 'files01'; ShareName = 'Operations'; UNCPath = '\\files01\Operations'; LocalPath = 'C:\ShareSurferLab\Operations'; Description = 'Operations shared data'; PartialData = $true; PartialReason = 'Scan errors recorded: AclReadError=1' }
        )
        Items = @(
            [pscustomobject]@{ ItemId = 'item-fin-root'; ShareId = 'share-finance'; ItemType = 'Directory'; FullPath = '\\files01\Finance'; RelativePath = ''; Depth = 0; Owner = 'CONTOSO\FinanceOwner'; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
            [pscustomobject]@{ ItemId = 'item-fin-ap'; ShareId = 'share-finance'; ItemType = 'Directory'; FullPath = '\\files01\Finance\AccountsPayable'; RelativePath = 'AccountsPayable'; Depth = 1; Owner = 'CONTOSO\FinanceOwner'; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
            [pscustomobject]@{ ItemId = 'item-fin-vendors'; ShareId = 'share-finance'; ItemType = 'Directory'; FullPath = '\\files01\Finance\AccountsPayable\Vendors'; RelativePath = 'AccountsPayable\Vendors'; Depth = 2; Owner = 'CONTOSO\FinanceOwner'; InheritanceEnabled = $false; InheritanceBrokenAt = '\\files01\Finance\AccountsPayable\Vendors' },
            [pscustomobject]@{ ItemId = 'item-fin-long'; ShareId = 'share-finance'; ItemType = 'Directory'; FullPath = $longPath; RelativePath = 'AccountsPayable\Vendors\' + $longTail; Depth = 5; Owner = 'CONTOSO\FinanceOwner'; InheritanceEnabled = $false; InheritanceBrokenAt = '\\files01\Finance\AccountsPayable\Vendors' },
            [pscustomobject]@{ ItemId = 'item-fin-conflict'; ShareId = 'share-finance'; ItemType = 'Directory'; FullPath = '\\files01\Finance\AccountsPayable\ReaderModify'; RelativePath = 'AccountsPayable\ReaderModify'; Depth = 2; Owner = 'CONTOSO\FinanceOwner'; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
            [pscustomobject]@{ ItemId = 'item-ops-root'; ShareId = 'share-operations'; ItemType = 'Directory'; FullPath = '\\files01\Operations'; RelativePath = ''; Depth = 0; Owner = 'CONTOSO\OperationsOwner'; InheritanceEnabled = $true; InheritanceBrokenAt = '' },
            [pscustomobject]@{ ItemId = 'item-ops-exec'; ShareId = 'share-operations'; ItemType = 'File'; FullPath = '\\files01\Operations\Restricted\FileOnly\executive-note.txt'; RelativePath = 'Restricted\FileOnly\executive-note.txt'; Depth = 3; Owner = 'CONTOSO\OperationsOwner'; InheritanceEnabled = $false; InheritanceBrokenAt = '\\files01\Operations\Restricted' }
        )
        SharePermissions = @(
            [pscustomobject]@{ ShareId = 'share-finance'; Identity = 'CONTOSO\SS-Finance-Readers'; Rights = 'Read'; AccessControlType = 'Allow'; Source = 'Get-SmbShareAccess' },
            [pscustomobject]@{ ShareId = 'share-operations'; Identity = 'CONTOSO\SS-Operations-Owners'; Rights = 'Full'; AccessControlType = 'Allow'; Source = 'Get-SmbShareAccess' }
        )
        AclEntries = @(
            [pscustomobject]@{ ItemId = 'item-fin-vendors'; ShareId = 'share-finance'; FullPath = '\\files01\Finance\AccountsPayable\Vendors'; Identity = 'CONTOSO\SS-Finance-Editors'; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = 2 },
            [pscustomobject]@{ ItemId = 'item-fin-long'; ShareId = 'share-finance'; FullPath = $longPath; Identity = 'CONTOSO\SS-Finance-Editors'; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = 5 },
            [pscustomobject]@{ ItemId = 'item-fin-conflict'; ShareId = 'share-finance'; FullPath = '\\files01\Finance\AccountsPayable\ReaderModify'; Identity = 'CONTOSO\SS-Finance-Readers'; Rights = 'Modify'; AccessControlType = 'Allow'; IsInherited = $false; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = 2 },
            [pscustomobject]@{ ItemId = 'item-fin-conflict'; ShareId = 'share-finance'; FullPath = '\\files01\Finance\AccountsPayable\ReaderModify'; Identity = 'CONTOSO\SS-Finance-Readers'; Rights = 'Read'; AccessControlType = 'Deny'; IsInherited = $false; InheritanceFlags = 'ContainerInherit,ObjectInherit'; PropagationFlags = 'None'; Depth = 2 },
            [pscustomobject]@{ ItemId = 'item-ops-exec'; ShareId = 'share-operations'; FullPath = '\\files01\Operations\Restricted\FileOnly\executive-note.txt'; Identity = 'CONTOSO\SS-Operations-Owners'; Rights = 'Read'; AccessControlType = 'Allow'; IsInherited = $false; InheritanceFlags = 'None'; PropagationFlags = 'None'; Depth = 3 }
        )
        Identities = @()
        GroupEdges = @()
        OrgChains = @()
        IdentityDirectory = @(
            [pscustomobject]@{ Identity = 'CONTOSO\SS-Finance-Readers'; SamAccountName = 'SS-Finance-Readers'; DistinguishedName = 'CN=SS-Finance-Readers,OU=Groups,DC=example,DC=test'; DisplayName = 'SS Finance Readers'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'finance.readers@example.test'; Department = 'Finance'; Title = ''; Company = 'Contoso'; Office = 'HQ-4'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.FIN.ACCESS.READ'; ObsAttribute = 'extensionAttribute10'; Members = @('CN=Ava Accounting,OU=Users,DC=example,DC=test') },
            [pscustomobject]@{ Identity = 'CONTOSO\SS-Finance-Editors'; SamAccountName = 'SS-Finance-Editors'; DistinguishedName = 'CN=SS-Finance-Editors,OU=Groups,DC=example,DC=test'; DisplayName = 'SS Finance Editors'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'finance.editors@example.test'; Department = 'Finance'; Title = ''; Company = 'Contoso'; Office = 'HQ-4'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.FIN.ACCESS.MODIFY'; ObsAttribute = 'extensionAttribute10'; Members = @('CN=SS-Finance-Readers,OU=Groups,DC=example,DC=test', 'CN=Morgan Manager,OU=Users,DC=example,DC=test') },
            [pscustomobject]@{ Identity = 'CONTOSO\SS-Operations-Owners'; SamAccountName = 'SS-Operations-Owners'; DistinguishedName = 'CN=SS-Operations-Owners,OU=Groups,DC=example,DC=test'; DisplayName = 'SS Operations Owners'; ObjectClass = 'group'; EmployeeId = ''; EmployeeNumber = ''; UserPrincipalName = ''; Mail = 'operations.owners@example.test'; Department = 'Operations'; Title = ''; Company = 'Contoso'; Office = 'HQ-2'; AccountEnabled = ''; Manager = ''; ManagerLevel1 = ''; ManagerLevel2 = ''; ObsPath = 'CORP.OPS.ACCESS.OWNER'; ObsAttribute = 'extensionAttribute10'; Members = @('CN=Leo Operations,OU=Users,DC=example,DC=test') },
            [pscustomobject]@{ Identity = 'CONTOSO\Ava.Accounting'; SamAccountName = 'Ava.Accounting'; DistinguishedName = 'CN=Ava Accounting,OU=Users,DC=example,DC=test'; DisplayName = 'Ava Accounting'; ObjectClass = 'user'; EmployeeId = 'E1001'; EmployeeNumber = '1001'; UserPrincipalName = 'ava.accounting@example.test'; Mail = 'ava.accounting@example.test'; Department = 'Accounts Payable'; Title = 'Accounting Analyst'; Company = 'Contoso'; Office = 'HQ-4'; AccountEnabled = 'True'; Manager = 'CONTOSO\Morgan.Manager'; ManagerLevel1 = 'CONTOSO\Morgan.Manager'; ManagerLevel2 = 'CONTOSO\Riley.Director'; ObsPath = 'CORP.FIN.AP'; ObsAttribute = 'extensionAttribute10'; Members = @() },
            [pscustomobject]@{ Identity = 'CONTOSO\Morgan.Manager'; SamAccountName = 'Morgan.Manager'; DistinguishedName = 'CN=Morgan Manager,OU=Users,DC=example,DC=test'; DisplayName = 'Morgan Manager'; ObjectClass = 'user'; EmployeeId = 'M1001'; EmployeeNumber = '9001'; UserPrincipalName = 'morgan.manager@example.test'; Mail = 'morgan.manager@example.test'; Department = 'Finance'; Title = 'Finance Manager'; Company = 'Contoso'; Office = 'HQ-4'; AccountEnabled = 'True'; Manager = 'CONTOSO\Riley.Director'; ManagerLevel1 = 'CONTOSO\Riley.Director'; ManagerLevel2 = ''; ObsPath = 'CORP.FIN'; ObsAttribute = 'extensionAttribute10'; Members = @() },
            [pscustomobject]@{ Identity = 'CONTOSO\Leo.Operations'; SamAccountName = 'Leo.Operations'; DistinguishedName = 'CN=Leo Operations,OU=Users,DC=example,DC=test'; DisplayName = 'Leo Operations'; ObjectClass = 'user'; EmployeeId = 'E3001'; EmployeeNumber = '3001'; UserPrincipalName = 'leo.operations@example.test'; Mail = 'leo.operations@example.test'; Department = 'Operations'; Title = 'Operations Lead'; Company = 'Contoso'; Office = 'HQ-2'; AccountEnabled = 'True'; Manager = 'CONTOSO\Quinn.Manager'; ManagerLevel1 = 'CONTOSO\Quinn.Manager'; ManagerLevel2 = 'CONTOSO\Riley.Director'; ObsPath = 'CORP.OPS.FILE'; ObsAttribute = 'extensionAttribute10'; Members = @() }
        )
        OwnerMappings = @(
            [pscustomobject]@{ Pattern = '\\files01\Finance*'; Owner = 'Finance Operations'; BusinessUnit = 'Finance'; Source = 'demo' },
            [pscustomobject]@{ Pattern = '\\files01\Operations*'; Owner = 'Operations Leadership'; BusinessUnit = 'Operations'; Source = 'demo' }
        )
        ScanErrors = @(
            [pscustomobject]@{ ShareId = 'share-operations'; ItemId = 'item-ops-exec'; FullPath = '\\files01\Operations\Restricted\FileOnly\executive-note.txt'; ErrorType = 'AclReadError'; Severity = 'High'; Source = 'Demo'; Message = 'Access denied while reading ACL.'; Detail = 'Synthetic screenshot evidence only.' }
        )
        ScanEvents = @(
            [pscustomobject]@{ EventId = 'demo-start'; Timestamp = (Get-Date).ToUniversalTime().ToString('o'); EventType = 'DemoDataLoaded'; Source = 'Demo'; ShareId = ''; ItemId = ''; FullPath = ''; Message = 'Loaded synthetic dashboard screenshot data.'; Detail = 'CONTOSO-style demo data only.' }
        )
    }
}

function Write-ShareSurferScreenshotCaptureScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    @'
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const reportPath = path.resolve(process.argv[2]);
const visualPath = path.resolve(process.argv[3]);

function fileUrl(localPath) {
  const normalized = localPath.replace(/\\/g, '/');
  return `file://${normalized.startsWith('/') ? '' : '/'}${normalized}`;
}

async function capture(page, name, width, height) {
  await page.setViewportSize({ width, height });
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(visualPath, name), fullPage: false });
}

(async () => {
  fs.mkdirSync(visualPath, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 1050 } });
  await page.goto(fileUrl(reportPath), { waitUntil: 'load' });
  await page.waitForSelector('#summary .metric');
  await capture(page, 'report-dashboard-overview.png', 1440, 1050);

  const firstPacket = page.locator('#owner-review-queue tbody tr').first();
  if (await firstPacket.count()) {
    await firstPacket.click();
  }
  await page.waitForSelector('#workbench-access');
  await capture(page, 'report-dashboard-workbench.png', 1280, 720);

  await page.click('button[data-view="findings"]');
  await page.waitForSelector('#findings');
  await capture(page, 'report-dashboard-findings.png', 1440, 1050);

  await page.click('button[data-view="migration"]');
  await page.waitForSelector('#migration-areas');
  const firstMigrationArea = page.locator('#migration-areas tbody tr').first();
  if (await firstMigrationArea.count()) {
    await firstMigrationArea.click();
  }
  await capture(page, 'report-dashboard-migration.png', 1440, 1000);
  await browser.close();
})();
'@ | Set-Content -LiteralPath $Path -Encoding UTF8
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
New-Item -ItemType Directory -Path $VisualOutputPath -Force | Out-Null

Import-Module $moduleManifest -Force
$inventory = New-ShareSurferScreenshotDemoInventory
Invoke-ShareSurferScan -InputObject $inventory -OutputPath $exportPath -AdLookupMode DirectoryOnly -ObsAttribute 'extensionAttribute10' | Out-Null
ConvertTo-ShareSurferReport -ExportPath $exportPath -OutputPath $reportPath | Out-Null
Write-ShareSurferScreenshotCaptureScript -Path $captureScriptPath

$captureSkipped = [bool]$SkipBrowserCapture
if (-not $SkipBrowserCapture) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCommand) {
        throw 'Node.js is required for browser screenshot capture. Re-run with -SkipBrowserCapture to generate only the demo export and report.'
    }

    $playwrightCheck = Start-Process -FilePath $nodeCommand.Source -ArgumentList @('-e', 'require("playwright")') -Wait -NoNewWindow -PassThru
    if ($playwrightCheck.ExitCode -ne 0) {
        throw 'The Playwright Node package is required for browser screenshot capture. Install it in a trusted docs-maintainer environment, or re-run with -SkipBrowserCapture.'
    }

    $captureProcess = Start-Process -FilePath $nodeCommand.Source -ArgumentList @($captureScriptPath, $reportPath, $VisualOutputPath) -Wait -NoNewWindow -PassThru
    if ($captureProcess.ExitCode -ne 0) {
        throw ('Dashboard screenshot capture failed with exit code {0}.' -f $captureProcess.ExitCode)
    }
}

[pscustomobject]@{
    OutputRoot = $OutputRoot
    ExportPath = $exportPath
    ReportPath = $reportPath
    VisualOutputPath = $VisualOutputPath
    CaptureScriptPath = $captureScriptPath
    CaptureSkipped = $captureSkipped
    Screenshots = @(
        'report-dashboard-overview.png',
        'report-dashboard-workbench.png',
        'report-dashboard-findings.png',
        'report-dashboard-migration.png'
    )
}
