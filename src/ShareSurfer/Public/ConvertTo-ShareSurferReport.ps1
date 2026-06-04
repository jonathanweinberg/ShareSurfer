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
  <title>ShareSurfer Business Review Dashboard</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #16202a;
      --muted: #5b6673;
      --line: #d8dee8;
      --panel: #f6f8fb;
      --panel-strong: #eef3f8;
      --accent: #0f766e;
      --accent-dark: #115e59;
      --blue: #2563eb;
      --warn: #b45309;
      --bad: #b91c1c;
      --good: #15803d;
      --shadow: 0 12px 34px rgba(22, 32, 42, .08);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", Arial, sans-serif;
      color: var(--ink);
      background: #ffffff;
    }
    header {
      padding: 34px 40px 24px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(180deg, #f9fbfc 0%, #ffffff 100%);
    }
    h1 {
      margin: 0 0 8px;
      font-size: 34px;
      line-height: 1.1;
      letter-spacing: 0;
    }
    h2 {
      margin: 0 0 12px;
      font-size: 21px;
      letter-spacing: 0;
    }
    h3 {
      margin: 0 0 8px;
      font-size: 16px;
      letter-spacing: 0;
    }
    main {
      padding: 22px 40px 40px;
      display: grid;
      gap: 18px;
    }
    .hero-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 22px;
      align-items: end;
      max-width: 1260px;
    }
    .subtitle {
      margin: 0;
      color: var(--muted);
      max-width: 900px;
      line-height: 1.5;
      font-size: 16px;
    }
    .risk-badge {
      display: inline-flex;
      align-items: center;
      min-height: 30px;
      padding: 5px 10px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: #ffffff;
      color: var(--ink);
      font-size: 13px;
      font-weight: 600;
      white-space: nowrap;
    }
    .risk-badge.high { border-color: #fecaca; background: #fff1f2; color: var(--bad); }
    .risk-badge.warning { border-color: #fed7aa; background: #fff7ed; color: var(--warn); }
    .risk-badge.good { border-color: #bbf7d0; background: #f0fdf4; color: var(--good); }
    .toolbar {
      display: grid;
      grid-template-columns: minmax(220px, 520px) auto;
      gap: 14px;
      align-items: center;
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    label {
      display: block;
      color: var(--muted);
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 6px;
      text-transform: uppercase;
    }
    input {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid var(--line);
      border-radius: 6px;
      font-size: 14px;
      background: #ffffff;
      color: var(--ink);
    }
    .view-tabs {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    button {
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #ffffff;
      color: var(--ink);
      padding: 9px 11px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
    }
    button[aria-selected="true"] {
      background: var(--accent);
      border-color: var(--accent);
      color: #ffffff;
    }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
      gap: 12px;
    }
    .metric {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: #ffffff;
      box-shadow: var(--shadow);
      min-height: 98px;
    }
    .metric strong {
      display: block;
      font-size: 28px;
      line-height: 1;
      margin-bottom: 8px;
    }
    .metric span {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.35;
    }
    .visual-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 14px;
    }
    .chart {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: var(--panel);
      min-height: 210px;
    }
    .chart h3 {
      margin-bottom: 12px;
    }
    .bar-list {
      display: grid;
      gap: 9px;
    }
    .bar-row {
      display: grid;
      grid-template-columns: minmax(86px, 1fr) minmax(120px, 2fr) auto;
      gap: 8px;
      align-items: center;
      width: 100%;
      border: 0;
      border-radius: 6px;
      padding: 8px;
      background: #ffffff;
      cursor: pointer;
      text-align: left;
    }
    .bar-row:hover, .bar-row:focus {
      outline: 2px solid #99f6e4;
      outline-offset: 1px;
    }
    .bar-label {
      color: var(--ink);
      font-size: 12px;
      font-weight: 600;
      overflow-wrap: anywhere;
    }
    .bar-track {
      height: 12px;
      border-radius: 999px;
      background: #e5e7eb;
      overflow: hidden;
    }
    .bar-fill {
      height: 100%;
      min-width: 3px;
      border-radius: 999px;
      background: var(--blue);
    }
    .bar-fill.high { background: var(--bad); }
    .bar-fill.warning { background: var(--warn); }
    .bar-fill.owner { background: var(--accent); }
    .bar-value {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      min-width: 28px;
      text-align: right;
    }
    .panel {
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #ffffff;
      padding: 18px;
      box-shadow: var(--shadow);
    }
    .view-panel { display: none; }
    .view-panel.active {
      display: grid;
      gap: 18px;
    }
    .two-column {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(280px, 420px);
      gap: 18px;
      align-items: start;
    }
    .note {
      color: var(--muted);
      max-width: 980px;
      line-height: 1.45;
      margin: 0;
    }
    .actions {
      margin: 0;
      padding: 0;
      list-style: none;
      display: grid;
      gap: 10px;
    }
    .actions li {
      border: 1px solid var(--line);
      border-left: 5px solid var(--accent);
      border-radius: 8px;
      padding: 11px 12px;
      background: var(--panel);
    }
    .actions li.high { border-left-color: var(--bad); }
    .actions li.warning { border-left-color: var(--warn); }
    .actions strong {
      display: block;
      margin-bottom: 4px;
    }
    .table-header {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: baseline;
      margin-bottom: 8px;
    }
    .count {
      color: var(--muted);
      font-size: 12px;
      white-space: nowrap;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      font-size: 13px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 8px;
      text-align: left;
      vertical-align: top;
      max-width: 360px;
      word-break: break-word;
    }
    th {
      background: var(--panel-strong);
      position: sticky;
      top: 0;
      z-index: 1;
    }
    .scroll {
      overflow: auto;
      max-height: 390px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #ffffff;
    }
    .empty {
      color: var(--muted);
      padding: 16px;
    }
    .controls {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      align-items: center;
      margin-bottom: 10px;
    }
    .controls input { max-width: 360px; }
    @media (max-width: 940px) {
      header { padding: 26px 20px 18px; }
      main { padding: 18px 20px 28px; }
      .hero-grid, .toolbar, .two-column { grid-template-columns: 1fr; }
      .view-tabs { justify-content: flex-start; }
      h1 { font-size: 28px; }
    }
  </style>
</head>
<body>
  <header>
    <div class="hero-grid">
      <div>
        <h1>ShareSurfer Business Review Dashboard</h1>
        <p class="subtitle">Offline SMB share, NTFS ACL, identity, organization, and Azure Files migration-readiness report for business-unit and data-owner review.</p>
      </div>
      <span class="risk-badge" id="overall-risk">Review Needed</span>
    </div>
  </header>
  <main>
    <section class="toolbar" aria-label="Dashboard Filters">
      <div>
        <label for="filter">Dashboard Filters</label>
        <input id="filter" type="search" placeholder="Search findings, conflicts, owners, groups, events, or paths">
      </div>
      <nav class="view-tabs" aria-label="Dashboard views">
        <button type="button" data-view="overview" aria-selected="true">Overview</button>
        <button type="button" data-view="findings" aria-selected="false">Findings</button>
        <button type="button" data-view="conflicts" aria-selected="false">Conflicts</button>
        <button type="button" data-view="owners" aria-selected="false">Owners</button>
        <button type="button" data-view="groups" aria-selected="false">Groups</button>
        <button type="button" data-view="org" aria-selected="false">Org & Logs</button>
      </nav>
    </section>

    <section class="view-panel active" id="view-overview" data-panel="overview">
      <div class="panel">
        <h2>Executive Summary</h2>
        <div class="summary" id="summary"></div>
      </div>
      <div class="panel">
        <h2>Visual Risk Rollups</h2>
        <p class="note">Click a bar to filter the dashboard to that risk, conflict, owner, or business unit.</p>
        <div class="visual-grid">
          <div class="chart" data-chart="finding">
            <h3>Findings by Type</h3>
            <div class="bar-list" id="finding-chart"></div>
          </div>
          <div class="chart" data-chart="conflict">
            <h3>Conflicts by Type</h3>
            <div class="bar-list" id="conflict-chart"></div>
          </div>
          <div class="chart" data-chart="owner">
            <h3>Business Units by Matching Items</h3>
            <div class="bar-list" id="owner-chart"></div>
          </div>
        </div>
      </div>
      <div class="two-column">
        <div class="panel">
          <h2>Priority Actions</h2>
          <ul class="actions" id="priority-actions"></ul>
        </div>
        <div class="panel">
          <h2>Azure Files Path Policy</h2>
          <p class="note">Microsoft documents 255-character path components and 2,048-character full paths for Azure Files. ShareSurfer's default 256-character finding is an operational migration policy warning for complex Windows file-share moves, not a statement that Azure Files cannot store the path.</p>
        </div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Business Unit Pivots</h2>
          <span class="count" id="owner-pivots-count"></span>
        </div>
        <div class="scroll"><table id="owner-pivots"></table></div>
      </div>
    </section>

    <section class="view-panel" id="view-findings" data-panel="findings">
      <div class="panel">
        <div class="table-header">
          <h2>Findings</h2>
          <span class="count" id="findings-count"></span>
        </div>
        <div class="scroll"><table id="findings"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Finding Rollups</h2>
          <span class="count" id="finding-rollups-count"></span>
        </div>
        <div class="scroll"><table id="finding-rollups"></table></div>
      </div>
    </section>

    <section class="view-panel" id="view-conflicts" data-panel="conflicts">
      <div class="panel">
        <div class="table-header">
          <h2>Share vs NTFS Conflicts</h2>
          <span class="count" id="conflicts-count"></span>
        </div>
        <div class="scroll"><table id="conflicts"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Conflict Rollups</h2>
          <span class="count" id="conflict-rollups-count"></span>
        </div>
        <div class="scroll"><table id="conflict-rollups"></table></div>
      </div>
    </section>

    <section class="view-panel" id="view-owners" data-panel="owners">
      <div class="panel">
        <div class="table-header">
          <h2>Owner and Business Unit Mappings</h2>
          <span class="count" id="owners-count"></span>
        </div>
        <div class="scroll"><table id="owners"></table></div>
      </div>
    </section>

    <section class="view-panel" id="view-groups" data-panel="groups">
      <div class="panel">
        <h2>Group Browser</h2>
        <div class="controls">
          <input id="group-filter" type="search" placeholder="Filter group or member">
          <span class="count" id="group-browser-count"></span>
        </div>
        <div class="scroll"><table id="group-browser"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Group Expansion</h2>
          <span class="count" id="groups-count"></span>
        </div>
        <div class="scroll"><table id="groups"></table></div>
      </div>
    </section>

    <section class="view-panel" id="view-org" data-panel="org">
      <div class="panel">
        <div class="table-header">
          <h2>Org Chain Rollups</h2>
          <span class="count" id="org-rollups-count"></span>
        </div>
        <div class="scroll"><table id="org-rollups"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Scan Events</h2>
          <span class="count" id="events-count"></span>
        </div>
        <div class="scroll"><table id="events"></table></div>
      </div>
    </section>
  </main>
  <script id="sharesurfer-data" type="application/json">__SHARESURFER_DATA__</script>
  <script>
    const data = JSON.parse(document.getElementById('sharesurfer-data').textContent);
    function asRows(rows) {
      return Array.isArray(rows) ? rows : [];
    }
    const severityRank = { Critical: 4, High: 3, Medium: 2, Warning: 2, Low: 1, Informational: 0, Info: 0 };
    function isHighRisk(row) {
      const severity = String(row.Severity || '');
      return severityRank[severity] >= 3;
    }
    function distinctCount(rows, field) {
      const values = new Set();
      asRows(rows).forEach(row => {
        const value = String(row[field] || '').trim();
        if (value) { values.add(value); }
      });
      return values.size;
    }
    function countWhere(rows, predicate) {
      return asRows(rows).filter(predicate).length;
    }
    function setCount(id, rows) {
      const target = document.getElementById(id + '-count');
      if (target) {
        target.textContent = String(asRows(rows).length) + ' row' + (asRows(rows).length === 1 ? '' : 's');
      }
    }
    function updateOverallRisk() {
      const risk = document.getElementById('overall-risk');
      const highFindings = countWhere(data.findings, isHighRisk);
      const highConflicts = countWhere(data.conflicts, isHighRisk);
      if (highFindings + highConflicts > 0) {
        risk.className = 'risk-badge high';
        risk.textContent = String(highFindings + highConflicts) + ' high-priority items';
      } else if (data.findings.length + data.conflicts.length > 0) {
        risk.className = 'risk-badge warning';
        risk.textContent = 'Review recommended';
      } else {
        risk.className = 'risk-badge good';
        risk.textContent = 'No findings in export';
      }
    }
    function renderSummary() {
      const metrics = [
        { label: 'Shares scanned', value: data.shares.length, hint: 'Collected SMB shares' },
        { label: 'Items reviewed', value: data.items.length, hint: 'Folders and files in scope' },
        { label: 'Findings', value: data.findings.length, hint: 'Migration and governance risks' },
        { label: 'High-priority findings', value: countWhere(data.findings, isHighRisk), hint: 'Start here for remediation' },
        { label: 'Access conflicts', value: data.conflicts.length, hint: 'Share and NTFS mismatch checks' },
        { label: 'Business units', value: distinctCount(data.owner_mappings, 'BusinessUnit'), hint: 'Owner mapping pivots' },
        { label: 'Expanded groups', value: distinctCount(data.group_edges, 'ParentGroup'), hint: 'Security groups with membership edges' },
        { label: 'Partial shares', value: countWhere(data.shares, row => String(row.PartialData) === 'True'), hint: 'Collection gaps to review' }
      ];
      const summary = document.getElementById('summary');
      summary.textContent = '';
      metrics.forEach(metric => {
        const div = document.createElement('div');
        div.className = 'metric';
        const strong = document.createElement('strong');
        strong.textContent = metric.value;
        const label = document.createElement('span');
        label.textContent = metric.label + '. ' + metric.hint + '.';
        div.appendChild(strong);
        div.appendChild(label);
        summary.appendChild(div);
      });
    }
    function addPriorityAction(list, severity, title, detail) {
      const li = document.createElement('li');
      li.className = severity;
      const strong = document.createElement('strong');
      strong.textContent = title;
      const span = document.createElement('span');
      span.textContent = detail;
      li.appendChild(strong);
      li.appendChild(span);
      list.appendChild(li);
    }
    function renderPriorityActions() {
      const list = document.getElementById('priority-actions');
      list.textContent = '';
      const highFindings = countWhere(data.findings, isHighRisk);
      const highConflicts = countWhere(data.conflicts, isHighRisk);
      const longPaths = countWhere(data.findings, row => row.FindingType === 'LongPathOperationalPolicy');
      const deepAces = countWhere(data.findings, row => row.FindingType === 'DeepExplicitAce');
      const inheritanceBreaks = countWhere(data.findings, row => row.FindingType === 'BrokenInheritance');
      const partialShares = countWhere(data.shares, row => String(row.PartialData) === 'True');
      const truncatedGroups = countWhere(data.group_edges, row => String(row.IsTruncated) === 'True');
      if (highFindings > 0) {
        addPriorityAction(list, 'high', 'Review high-severity findings', String(highFindings) + ' finding(s) need owner or business-unit review.');
      }
      if (highConflicts > 0) {
        addPriorityAction(list, 'high', 'Resolve high-severity access conflicts', String(highConflicts) + ' conflict(s) show share-vs-NTFS mismatch risk.');
      }
      if (longPaths > 0) {
        addPriorityAction(list, 'warning', 'Plan long-path remediation', String(longPaths) + ' path finding(s) exceed the operational migration threshold.');
      }
      if (deepAces > 0 || inheritanceBreaks > 0) {
        addPriorityAction(list, 'warning', 'Confirm delegated folder access', String(deepAces) + ' deep explicit ACE(s) and ' + String(inheritanceBreaks) + ' inheritance break(s) need review.');
      }
      if (partialShares > 0) {
        addPriorityAction(list, 'warning', 'Investigate partial collection', String(partialShares) + ' share(s) have incomplete metadata.');
      }
      if (truncatedGroups > 0) {
        addPriorityAction(list, 'warning', 'Revisit group expansion depth', String(truncatedGroups) + ' group edge(s) were truncated.');
      }
      if (list.children.length === 0) {
        addPriorityAction(list, 'good', 'No immediate high-priority actions', 'Review owner mappings and rerun after any cleanup or migration planning changes.');
      }
    }
    function renderTable(id, rows) {
      const table = document.getElementById(id);
      table.innerHTML = '';
      const safeRows = asRows(rows);
      setCount(id, safeRows);
      if (safeRows.length === 0) {
        const tr = document.createElement('tr');
        const td = document.createElement('td');
        td.className = 'empty';
        td.textContent = 'No matching rows';
        tr.appendChild(td);
        table.appendChild(tr);
        return;
      }
      const columns = Object.keys(safeRows[0]);
      const thead = document.createElement('thead');
      const headerRow = document.createElement('tr');
      columns.forEach(c => {
        const th = document.createElement('th');
        th.textContent = c;
        headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      const tbody = document.createElement('tbody');
      safeRows.forEach(row => {
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
    function wildcardMatch(pattern, value) {
      const escaped = String(pattern || '').replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.');
      return new RegExp('^' + escaped + '$', 'i').test(String(value || ''));
    }
    function buildOwnerPivots() {
      const pivots = new Map();
      data.owner_mappings.forEach(mapping => {
        const matchedItems = data.items.filter(item => wildcardMatch(mapping.Pattern, item.FullPath));
        const key = [mapping.BusinessUnit || '', mapping.Owner || '', mapping.Pattern || ''].join('|');
        pivots.set(key, {
          BusinessUnit: mapping.BusinessUnit || '',
          Owner: mapping.Owner || '',
          Pattern: mapping.Pattern || '',
          Source: mapping.Source || '',
          MatchingItems: matchedItems.length,
          Directories: matchedItems.filter(item => item.ItemType === 'Directory').length,
          Files: matchedItems.filter(item => item.ItemType === 'File').length
        });
      });
      return Array.from(pivots.values()).sort((a, b) => String(a.BusinessUnit).localeCompare(String(b.BusinessUnit)) || String(a.Owner).localeCompare(String(b.Owner)));
    }
    function buildRollups(rows, fields) {
      const rollups = new Map();
      asRows(rows).forEach(row => {
        const keyValues = fields.map(field => String(row[field] || ''));
        const key = keyValues.join('|');
        if (!rollups.has(key)) {
          const record = {};
          fields.forEach((field, index) => { record[field] = keyValues[index]; });
          record.Count = 0;
          rollups.set(key, record);
        }
        rollups.get(key).Count += 1;
      });
      return Array.from(rollups.values()).sort((a, b) => String(a[fields[0]] || '').localeCompare(String(b[fields[0]] || '')));
    }
    function buildOrgChainRollups() {
      const rollups = new Map();
      data.org_chains.forEach(chain => {
        const key = [chain.ObsPath || '', chain.ManagerLevel1 || '', chain.ManagerLevel2 || ''].join('|');
        if (!rollups.has(key)) {
          rollups.set(key, {
            ObsPath: chain.ObsPath || '',
            ManagerLevel1: chain.ManagerLevel1 || '',
            ManagerLevel2: chain.ManagerLevel2 || '',
            Identities: 0
          });
        }
        rollups.get(key).Identities += 1;
      });
      return Array.from(rollups.values()).sort((a, b) => String(a.ObsPath).localeCompare(String(b.ObsPath)) || String(a.ManagerLevel1).localeCompare(String(b.ManagerLevel1)));
    }
    function buildGroupBrowserRows() {
      return data.group_edges.map(edge => ({
        ParentGroup: edge.ParentGroup || '',
        ChildIdentity: edge.ChildIdentity || '',
        ChildObjectClass: edge.ChildObjectClass || '',
        Depth: edge.Depth || '',
        IsCycle: edge.IsCycle || '',
        IsTruncated: edge.IsTruncated || ''
      }));
    }
    function takeTopRows(rows, valueField, limit) {
      return asRows(rows)
        .slice()
        .sort((a, b) => Number(b[valueField] || 0) - Number(a[valueField] || 0))
        .slice(0, limit);
    }
    function buildOwnerChartRows() {
      const rollups = new Map();
      owner_pivots.forEach(pivot => {
        const key = pivot.BusinessUnit || pivot.Owner || 'Unmapped';
        if (!rollups.has(key)) {
          rollups.set(key, { Label: key, Count: 0, FilterValue: key });
        }
        rollups.get(key).Count += Number(pivot.MatchingItems || 0);
      });
      return takeTopRows(Array.from(rollups.values()), 'Count', 6);
    }
    function focusDashboardValue(value, viewName) {
      const filter = document.getElementById('filter');
      filter.value = String(value || '');
      applyFilter();
      showView(viewName || 'findings');
      filter.focus();
    }
    function renderBarChart(id, rows, options) {
      const target = document.getElementById(id);
      target.textContent = '';
      const safeRows = takeTopRows(rows, options.valueField, options.limit || 6);
      if (safeRows.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = 'No data to chart';
        target.appendChild(empty);
        return;
      }
      const maxValue = Math.max(...safeRows.map(row => Number(row[options.valueField] || 0)), 1);
      safeRows.forEach(row => {
        const label = String(row[options.labelField] || 'Unspecified');
        const value = Number(row[options.valueField] || 0);
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'bar-row';
        button.title = 'Filter dashboard to ' + label;
        button.addEventListener('click', () => focusDashboardValue(row.FilterValue || label, options.viewName));

        const labelSpan = document.createElement('span');
        labelSpan.className = 'bar-label';
        labelSpan.textContent = label;
        const track = document.createElement('span');
        track.className = 'bar-track';
        const fill = document.createElement('span');
        fill.className = 'bar-fill ' + (options.fillClass || '');
        fill.style.width = String(Math.max(4, Math.round((value / maxValue) * 100))) + '%';
        track.appendChild(fill);
        const valueSpan = document.createElement('span');
        valueSpan.className = 'bar-value';
        valueSpan.textContent = String(value);

        button.appendChild(labelSpan);
        button.appendChild(track);
        button.appendChild(valueSpan);
        target.appendChild(button);
      });
    }
    const owner_pivots = buildOwnerPivots();
    const finding_rollups = buildRollups(data.findings, ['FindingType', 'Severity']);
    const conflict_rollups = buildRollups(data.conflicts, ['ConflictType', 'Severity']);
    const org_rollups = buildOrgChainRollups();
    const group_browser_rows = buildGroupBrowserRows();
    const finding_chart_rows = buildRollups(data.findings, ['FindingType']).map(row => ({ Label: row.FindingType || 'Unspecified', Count: row.Count, FilterValue: row.FindingType || '' }));
    const conflict_chart_rows = buildRollups(data.conflicts, ['ConflictType']).map(row => ({ Label: row.ConflictType || 'Unspecified', Count: row.Count, FilterValue: row.ConflictType || '' }));
    const owner_chart_rows = buildOwnerChartRows();
    function applyGroupBrowser() {
      const q = document.getElementById('group-filter').value.toLowerCase();
      const match = row => JSON.stringify(row).toLowerCase().includes(q);
      renderTable('group-browser', group_browser_rows.filter(match));
    }
    function applyFilter() {
      const q = document.getElementById('filter').value.toLowerCase();
      const match = row => JSON.stringify(row).toLowerCase().includes(q);
      renderTable('findings', data.findings.filter(match));
      renderTable('finding-rollups', finding_rollups.filter(match));
      renderTable('conflicts', data.conflicts.filter(match));
      renderTable('conflict-rollups', conflict_rollups.filter(match));
      renderTable('owners', data.owner_mappings.filter(match));
      renderTable('owner-pivots', owner_pivots.filter(match));
      renderTable('groups', data.group_edges.filter(match));
      renderTable('org-rollups', org_rollups.filter(match));
      renderTable('events', data.scan_events.filter(match));
      applyGroupBrowser();
    }
    function showView(viewName) {
      document.querySelectorAll('[data-panel]').forEach(panel => {
        panel.classList.toggle('active', panel.dataset.panel === viewName);
      });
      document.querySelectorAll('[data-view]').forEach(button => {
        button.setAttribute('aria-selected', String(button.dataset.view === viewName));
      });
    }
    document.querySelectorAll('[data-view]').forEach(button => {
      button.addEventListener('click', () => showView(button.dataset.view));
    });
    document.getElementById('filter').addEventListener('input', applyFilter);
    document.getElementById('group-filter').addEventListener('input', applyGroupBrowser);
    renderSummary();
    renderBarChart('finding-chart', finding_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'warning', viewName: 'findings' });
    renderBarChart('conflict-chart', conflict_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'high', viewName: 'conflicts' });
    renderBarChart('owner-chart', owner_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'owner', viewName: 'owners' });
    renderPriorityActions();
    updateOverallRisk();
    applyFilter();
    showView('overview');
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
