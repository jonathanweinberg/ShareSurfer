[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ExportPath,

    [ValidateRange(50, 5000)]
    [int] $PageSize = 500,

    [string] $InitialDataset = 'owner_review_packets',

    [switch] $ValidateOnly,

    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ShareSurferNativeViewerWindows {
    $isWindowsVariable = Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $isWindowsVariable) {
        return [bool]$isWindowsVariable.Value
    }

    [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Get-ShareSurferNativeViewerCsvColumns {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $sampleRows = @(Import-Csv -LiteralPath $Path | Select-Object -First 1)
    if ($sampleRows.Count -gt 0) {
        return @($sampleRows[0].PSObject.Properties.Name)
    }

    $reader = New-Object System.IO.StreamReader($Path, [System.Text.Encoding]::UTF8, $true)
    try {
        $header = [string]$reader.ReadLine()
    }
    finally {
        $reader.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($header)) {
        return @()
    }

    @($header -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ -ne '' })
}

function Get-ShareSurferNativeViewerCsvRowCount {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $lineCount = 0
    Get-Content -LiteralPath $Path -ReadCount 5000 | ForEach-Object {
        $lineCount += @($_).Count
    }

    [Math]::Max(0, $lineCount - 1)
}

function Get-ShareSurferNativeViewerDatasets {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath
    )

    if (-not (Test-Path -LiteralPath $ExportPath -PathType Container)) {
        throw ('ShareSurfer export folder was not found: {0}' -f $ExportPath)
    }

    $manifestPath = Join-Path $ExportPath 'scan_manifest.csv'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw ('ShareSurfer export folder does not contain scan_manifest.csv: {0}' -f $ExportPath)
    }

    $preferredOrder = @(
        'scan_manifest',
        'evidence_confidence',
        'owner_review_packets',
        'related_data_areas',
        'findings',
        'conflicts',
        'collection_errors',
        'permissioned_groups',
        'identities',
        'group_edges',
        'shares',
        'items',
        'share_permissions',
        'acl_entries',
        'owner_risk_pivots',
        'scan_events'
    )

    $rank = @{}
    for ($index = 0; $index -lt $preferredOrder.Count; $index++) {
        $rank[$preferredOrder[$index]] = $index
    }

    @(Get-ChildItem -LiteralPath $ExportPath -Filter '*.csv' -File |
        ForEach-Object {
            $datasetKey = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $columns = @(Get-ShareSurferNativeViewerCsvColumns -Path $_.FullName)
            $rowCount = Get-ShareSurferNativeViewerCsvRowCount -Path $_.FullName
            [pscustomobject]@{
                DatasetKey = $datasetKey
                DisplayName = ('{0} ({1:N0} rows)' -f $_.Name, $rowCount)
                FileName = $_.Name
                Path = $_.FullName
                RowCount = $rowCount
                SourceBytes = [Int64]$_.Length
                Columns = $columns
                SortRank = if ($rank.ContainsKey($datasetKey)) { [int]$rank[$datasetKey] } else { 1000 }
            }
        } |
        Sort-Object -Property SortRank, DatasetKey)
}

function Get-ShareSurferNativeViewerRows {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [int] $Offset = 0,

        [int] $PageSize = 500
    )

    @(Import-Csv -LiteralPath $Path | Select-Object -Skip $Offset -First $PageSize)
}

function ConvertTo-ShareSurferNativeViewerDataTable {
    param(
        $Rows,
        [string[]] $Columns
    )

    $table = New-Object System.Data.DataTable
    foreach ($column in @($Columns)) {
        if ([string]::IsNullOrWhiteSpace($column)) {
            continue
        }

        [void]$table.Columns.Add($column)
    }

    foreach ($row in @($Rows)) {
        $dataRow = $table.NewRow()
        foreach ($column in @($Columns)) {
            if ([string]::IsNullOrWhiteSpace($column) -or -not $row.PSObject.Properties[$column]) {
                continue
            }

            $dataRow[$column] = [string]$row.PSObject.Properties[$column].Value
        }

        [void]$table.Rows.Add($dataRow)
    }

    $table
}

function New-ShareSurferNativeViewerSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        $Datasets,

        [string] $ViewerMode = 'HeadlessValidation'
    )

    $manifest = @()
    $manifestRows = @($Datasets | Where-Object { $_.DatasetKey -eq 'scan_manifest' })
    if ($manifestRows.Count -gt 0) {
        $manifest = @(Import-Csv -LiteralPath $manifestRows[0].Path | Select-Object -First 1)
    }

    [pscustomobject]@{
        ViewerMode = $ViewerMode
        ExportPath = (Resolve-Path -LiteralPath $ExportPath).Path
        DatasetCount = @($Datasets).Count
        TotalRows = [int](@($Datasets) | Measure-Object -Property RowCount -Sum).Sum
        TotalSourceBytes = [Int64](@($Datasets) | Measure-Object -Property SourceBytes -Sum).Sum
        ScanGeneratedAt = if ($manifest.Count -gt 0 -and $manifest[0].PSObject.Properties['GeneratedAt']) { [string]$manifest[0].GeneratedAt } else { '' }
        AclExportMode = if ($manifest.Count -gt 0 -and $manifest[0].PSObject.Properties['AclExportMode']) { [string]$manifest[0].AclExportMode } else { '' }
        Datasets = @($Datasets | Select-Object DatasetKey, FileName, RowCount, SourceBytes, Columns)
    }
}

function Start-ShareSurferNativeViewerForm {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        $Datasets,

        [int] $PageSize = 500,

        [string] $InitialDataset = 'owner_review_packets'
    )

    if (-not (Test-ShareSurferNativeViewerWindows)) {
        throw 'The ShareSurfer native viewer is Windows-only. Use -ValidateOnly on non-Windows systems, or use report.html / standalone-dashboard for cross-platform review.'
    }

    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
        throw 'The ShareSurfer native viewer uses WinForms and must run in an STA PowerShell session. Start it with: powershell.exe -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-ShareSurferNativeViewer.ps1 -ExportPath <export folder>'
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'ShareSurfer Native Viewer'
    $form.StartPosition = 'CenterScreen'
    $form.Width = 1280
    $form.Height = 820

    $main = New-Object System.Windows.Forms.TableLayoutPanel
    $main.Dock = 'Fill'
    $main.ColumnCount = 2
    $main.RowCount = 3
    [void]$main.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle -ArgumentList @([System.Windows.Forms.SizeType]::Absolute, 310)))
    [void]$main.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle -ArgumentList @([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle -ArgumentList @([System.Windows.Forms.SizeType]::Absolute, 78)))
    [void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle -ArgumentList @([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle -ArgumentList @([System.Windows.Forms.SizeType]::Absolute, 42)))
    $form.Controls.Add($main)

    $header = New-Object System.Windows.Forms.Label
    $header.Dock = 'Fill'
    $header.Font = New-Object System.Drawing.Font -ArgumentList @('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $header.Text = "ShareSurfer export: $ExportPath`r`nRows are loaded by page from CSV files. No browser, WebView2, npm, or server is used."
    $header.Padding = New-Object System.Windows.Forms.Padding -ArgumentList 8
    $main.SetColumnSpan($header, 2)
    $main.Controls.Add($header, 0, 0)

    $datasetList = New-Object System.Windows.Forms.ListBox
    $datasetList.Dock = 'Fill'
    $datasetList.DisplayMember = 'DisplayName'
    foreach ($dataset in @($Datasets)) {
        [void]$datasetList.Items.Add($dataset)
    }
    $main.Controls.Add($datasetList, 0, 1)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = 'Fill'
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.AutoSizeColumnsMode = 'DisplayedCells'
    $main.Controls.Add($grid, 1, 1)

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Dock = 'Fill'
    $buttonPanel.FlowDirection = 'LeftToRight'
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding -ArgumentList 4
    $main.SetColumnSpan($buttonPanel, 2)
    $main.Controls.Add($buttonPanel, 0, 2)

    $previousButton = New-Object System.Windows.Forms.Button
    $previousButton.Text = 'Previous page'
    $previousButton.Width = 110
    $nextButton = New-Object System.Windows.Forms.Button
    $nextButton.Text = 'Next page'
    $nextButton.Width = 90
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = 'Refresh'
    $refreshButton.Width = 80
    $pageLabel = New-Object System.Windows.Forms.Label
    $pageLabel.AutoSize = $true
    $pageLabel.Padding = New-Object System.Windows.Forms.Padding -ArgumentList @(12, 8, 0, 0)
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.AutoSize = $true
    $statusLabel.Padding = New-Object System.Windows.Forms.Padding -ArgumentList @(12, 8, 0, 0)

    [void]$buttonPanel.Controls.Add($previousButton)
    [void]$buttonPanel.Controls.Add($nextButton)
    [void]$buttonPanel.Controls.Add($refreshButton)
    [void]$buttonPanel.Controls.Add($pageLabel)
    [void]$buttonPanel.Controls.Add($statusLabel)

    $script:ShareSurferNativeViewerOffset = 0

    $loadPage = {
        param([int] $RequestedOffset)

        $dataset = $datasetList.SelectedItem
        if ($null -eq $dataset) {
            return
        }

        $safeOffset = [Math]::Max(0, [Math]::Min([int]$RequestedOffset, [Math]::Max(0, [int]$dataset.RowCount - 1)))
        $script:ShareSurferNativeViewerOffset = $safeOffset
        $rows = @(Get-ShareSurferNativeViewerRows -Path $dataset.Path -Offset $safeOffset -PageSize $PageSize)
        $columns = @($dataset.Columns)
        if ($columns.Count -eq 0 -and $rows.Count -gt 0) {
            $columns = @($rows[0].PSObject.Properties.Name)
        }

        $grid.DataSource = ConvertTo-ShareSurferNativeViewerDataTable -Rows $rows -Columns $columns
        $startRow = if ($rows.Count -gt 0) { $safeOffset + 1 } else { 0 }
        $endRow = $safeOffset + $rows.Count
        $pageLabel.Text = ('Rows {0:N0}-{1:N0} of {2:N0}' -f $startRow, $endRow, [int]$dataset.RowCount)
        $statusLabel.Text = ('Dataset: {0}; source {1:N0} bytes' -f [string]$dataset.FileName, [Int64]$dataset.SourceBytes)
        $previousButton.Enabled = ($safeOffset -gt 0)
        $nextButton.Enabled = ($endRow -lt [int]$dataset.RowCount)
    }

    $datasetList.Add_SelectedIndexChanged({
            $script:ShareSurferNativeViewerOffset = 0
            & $loadPage 0
        })
    $previousButton.Add_Click({ & $loadPage ([Math]::Max(0, $script:ShareSurferNativeViewerOffset - $PageSize)) })
    $nextButton.Add_Click({ & $loadPage ($script:ShareSurferNativeViewerOffset + $PageSize) })
    $refreshButton.Add_Click({ & $loadPage $script:ShareSurferNativeViewerOffset })

    $initial = @($Datasets | Where-Object { $_.DatasetKey -eq $InitialDataset } | Select-Object -First 1)
    if ($initial.Count -eq 0) {
        $initial = @($Datasets | Select-Object -First 1)
    }

    if ($initial.Count -gt 0) {
        $datasetList.SelectedItem = $initial[0]
    }

    [void]$form.ShowDialog()
}

$resolvedExportPath = (Resolve-Path -LiteralPath $ExportPath).Path
$datasets = @(Get-ShareSurferNativeViewerDatasets -ExportPath $resolvedExportPath)
$summary = New-ShareSurferNativeViewerSummary -ExportPath $resolvedExportPath -Datasets $datasets -ViewerMode $(if ($ValidateOnly) { 'HeadlessValidation' } else { 'WinForms' })

if ($ValidateOnly) {
    if ($PassThru) {
        $summary
    }
    else {
        $summary | Format-List ViewerMode, ExportPath, DatasetCount, TotalRows, TotalSourceBytes, ScanGeneratedAt, AclExportMode
    }
    return
}

Start-ShareSurferNativeViewerForm -ExportPath $resolvedExportPath -Datasets $datasets -PageSize $PageSize -InitialDataset $InitialDataset

if ($PassThru) {
    $summary
}
