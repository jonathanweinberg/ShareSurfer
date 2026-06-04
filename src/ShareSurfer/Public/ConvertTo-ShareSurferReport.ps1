function ConvertTo-ShareSurferReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ExportPath,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath
    )

    $schema = Get-ShareSurferExportSchema
    $data = [ordered]@{}
    foreach ($fileName in $schema.Keys) {
        $key = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $data[$key] = @(Read-ShareSurferCsv -Path (Join-Path $ExportPath $fileName))
    }

    $json = $data | ConvertTo-Json -Depth 6 -Compress
    $safeJson = $json.Replace('&', '\u0026').Replace('<', '\u003c').Replace('>', '\u003e')
    $htmlTemplate = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ShareSurfer Report</title>
  <style>
    :root { color-scheme: light; --ink: #17202a; --muted: #5d6d7e; --line: #d8dee9; --panel: #f7f9fb; --accent: #0b6e69; --warn: #ad5b00; --bad: #9f1d35; }
    body { margin: 0; font-family: Segoe UI, Arial, sans-serif; color: var(--ink); background: white; }
    header { padding: 24px 32px 16px; border-bottom: 1px solid var(--line); }
    h1 { margin: 0 0 6px; font-size: 28px; letter-spacing: 0; }
    h2 { margin: 0 0 12px; font-size: 18px; }
    main { padding: 20px 32px 32px; display: grid; gap: 18px; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
    .metric { border: 1px solid var(--line); border-radius: 8px; padding: 12px; background: var(--panel); }
    .metric strong { display: block; font-size: 24px; margin-bottom: 2px; }
    .metric span { color: var(--muted); font-size: 12px; }
    section { border-top: 1px solid var(--line); padding-top: 16px; }
    input { width: 100%; max-width: 520px; padding: 9px 10px; border: 1px solid var(--line); border-radius: 6px; font-size: 14px; }
    table { border-collapse: collapse; width: 100%; font-size: 13px; margin-top: 10px; }
    th, td { border-bottom: 1px solid var(--line); padding: 8px; text-align: left; vertical-align: top; }
    th { background: var(--panel); position: sticky; top: 0; }
    .scroll { overflow: auto; max-height: 360px; border: 1px solid var(--line); border-radius: 8px; }
    .high { color: var(--bad); font-weight: 600; }
    .warning { color: var(--warn); font-weight: 600; }
    .note { color: var(--muted); max-width: 980px; line-height: 1.45; }
  </style>
</head>
<body>
  <header>
    <h1>ShareSurfer</h1>
    <p class="note">Offline SMB share, NTFS ACL, identity, organization, and Azure Files migration-readiness report.</p>
  </header>
  <main>
    <div class="summary" id="summary"></div>
    <section>
      <h2>Azure Files Path Policy</h2>
      <p class="note">Microsoft documents 255-character path components and 2,048-character full paths for Azure Files. ShareSurfer's default 256-character finding is an operational migration policy warning for complex Windows file-share moves, not a statement that Azure Files cannot store the path.</p>
    </section>
    <section>
      <h2>Findings</h2>
      <input id="filter" type="search" placeholder="Filter tables">
      <div class="scroll"><table id="findings"></table></div>
    </section>
    <section>
      <h2>Share vs NTFS Conflicts</h2>
      <div class="scroll"><table id="conflicts"></table></div>
    </section>
    <section>
      <h2>Owner and Business Unit Mappings</h2>
      <div class="scroll"><table id="owners"></table></div>
    </section>
    <section>
      <h2>Group Expansion</h2>
      <div class="scroll"><table id="groups"></table></div>
    </section>
  </main>
  <script id="sharesurfer-data" type="application/json">__SHARESURFER_DATA__</script>
  <script>
    const data = JSON.parse(document.getElementById('sharesurfer-data').textContent);
    const counts = [
      ['Shares', data.shares.length],
      ['Items', data.items.length],
      ['ACL entries', data.acl_entries.length],
      ['Findings', data.findings.length],
      ['Conflicts', data.conflicts.length],
      ['Identities', data.identities.length]
    ];
    const summary = document.getElementById('summary');
    counts.forEach(([label, value]) => {
      const div = document.createElement('div');
      div.className = 'metric';
      const strong = document.createElement('strong');
      strong.textContent = value;
      const span = document.createElement('span');
      span.textContent = label;
      div.appendChild(strong);
      div.appendChild(span);
      summary.appendChild(div);
    });
    function renderTable(id, rows) {
      const table = document.getElementById(id);
      table.innerHTML = '';
      if (!rows || rows.length === 0) {
        const tr = document.createElement('tr');
        const td = document.createElement('td');
        td.textContent = 'No rows';
        tr.appendChild(td);
        table.appendChild(tr);
        return;
      }
      const columns = Object.keys(rows[0]);
      const thead = document.createElement('thead');
      const headerRow = document.createElement('tr');
      columns.forEach(c => {
        const th = document.createElement('th');
        th.textContent = c;
        headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      const tbody = document.createElement('tbody');
      rows.forEach(row => {
        const tr = document.createElement('tr');
        columns.forEach(c => {
          const td = document.createElement('td');
          td.textContent = String(row[c] ?? '');
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
      table.appendChild(thead);
      table.appendChild(tbody);
    }
    function applyFilter() {
      const q = document.getElementById('filter').value.toLowerCase();
      const match = row => JSON.stringify(row).toLowerCase().includes(q);
      renderTable('findings', data.findings.filter(match));
      renderTable('conflicts', data.conflicts.filter(match));
      renderTable('owners', data.owner_mappings.filter(match));
      renderTable('groups', data.group_edges.filter(match));
    }
    document.getElementById('filter').addEventListener('input', applyFilter);
    applyFilter();
  </script>
</body>
</html>
'@

    $html = $htmlTemplate.Replace('__SHARESURFER_DATA__', $safeJson)

    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $html -Encoding UTF8

    [pscustomobject]@{
        ReportPath = $OutputPath
        ExportPath = $ExportPath
    }
}
