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
  <link rel="icon" href="data:,">
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
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 14px;
      align-items: center;
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      box-shadow: var(--shadow);
    }
    .filter-grid {
      display: grid;
      grid-template-columns: minmax(260px, 2fr) repeat(3, minmax(160px, 1fr));
      gap: 12px;
      align-items: end;
    }
    label {
      display: block;
      color: var(--muted);
      font-size: 12px;
      font-weight: 600;
      margin-bottom: 6px;
      text-transform: uppercase;
    }
    input, select {
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
      grid-template-columns: minmax(150px, 1.5fr) minmax(90px, 1fr) 28px;
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
      font-size: 11px;
      font-weight: 600;
      line-height: 1.15;
      overflow-wrap: break-word;
      word-break: normal;
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
      min-width: 760px;
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
    .workbench-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(320px, .85fr);
      gap: 16px;
      align-items: start;
    }
    .workbench-stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 10px;
      margin: 0;
    }
    .workbench-stats div {
      border-left: 4px solid var(--accent);
      background: var(--panel);
      border-radius: 6px;
      padding: 10px 12px;
      min-height: 76px;
    }
    .workbench-stats dt {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      margin: 0 0 6px;
      text-transform: uppercase;
    }
    .workbench-stats dd {
      font-size: 24px;
      font-weight: 700;
      margin: 0;
    }
    .compact-scroll {
      max-height: 245px;
    }
    @media (max-width: 940px) {
      header { padding: 26px 20px 18px; }
      main { padding: 18px 20px 28px; }
      .hero-grid, .toolbar, .filter-grid, .two-column, .workbench-grid { grid-template-columns: 1fr; }
      .summary, .visual-grid { grid-template-columns: 1fr; }
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
      <div class="filter-grid">
        <div>
          <label for="filter">Dashboard Filters</label>
          <input id="filter" type="search" placeholder="Search findings, conflicts, owners, groups, events, or paths">
        </div>
        <div>
          <label for="business-unit-filter">Business Unit</label>
          <select id="business-unit-filter" aria-label="Filter by business unit"></select>
        </div>
        <div>
          <label for="owner-filter">Data Owner</label>
          <select id="owner-filter" aria-label="Filter by data owner"></select>
        </div>
        <div>
          <label for="risk-filter">Review Risk</label>
          <select id="risk-filter" aria-label="Filter by review risk"></select>
        </div>
      </div>
      <nav class="view-tabs" aria-label="Dashboard views">
        <button type="button" data-view="overview" aria-selected="true">Overview</button>
        <button type="button" data-view="findings" aria-selected="false">Findings</button>
        <button type="button" data-view="conflicts" aria-selected="false">Conflicts</button>
        <button type="button" data-view="owners" aria-selected="false">Owners</button>
        <button type="button" data-view="groups" aria-selected="false">Groups</button>
        <button type="button" data-view="diagnostics" aria-selected="false">Diagnostics</button>
        <button type="button" data-view="org" aria-selected="false">Org & Logs</button>
      </nav>
    </section>

    <section class="view-panel active" id="view-overview" data-panel="overview">
      <div class="panel">
        <h2>Executive Summary</h2>
        <div class="summary" id="summary"></div>
      </div>
      <div class="panel" id="review-workbench">
        <div class="table-header">
          <h2>Review Workbench</h2>
          <span class="count" id="workbench-count"></span>
        </div>
        <p class="note" id="workbench-context"></p>
        <div class="workbench-grid">
          <div>
            <h3>Context Snapshot</h3>
            <dl class="workbench-stats" id="workbench-stats"></dl>
          </div>
          <div>
            <h3>Recommended Review</h3>
            <ul class="actions" id="workbench-actions"></ul>
          </div>
        </div>
        <div class="workbench-grid">
          <div>
            <h3>Related Groups</h3>
            <div class="scroll compact-scroll"><table id="workbench-groups"></table></div>
          </div>
          <div>
            <h3>Top Findings and Conflicts</h3>
            <div class="scroll compact-scroll"><table id="workbench-risks"></table></div>
          </div>
        </div>
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
          <div class="chart" data-chart="collection-error">
            <h3>Collection Errors by Type</h3>
            <div class="bar-list" id="collection-error-chart"></div>
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
        <p class="note" id="active-filter-note"></p>
        <p class="note">Owner Risk Pivots combine mapped paths with item, finding, conflict, and partial-share counts so each business unit can see why it is being asked to review access.</p>
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

    <section class="view-panel" id="view-diagnostics" data-panel="diagnostics">
      <div class="panel">
        <div class="table-header">
          <h2>Collection Error Drilldown</h2>
          <span class="count" id="collection-errors-count"></span>
        </div>
        <p class="note">Use this view when a share is marked partial. Collection errors identify the share, path, error type, and message that prevented a complete inventory.</p>
        <div class="scroll"><table id="collection-errors"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Collection Error Rollups</h2>
          <span class="count" id="collection-error-rollups-count"></span>
        </div>
        <div class="scroll"><table id="collection-error-rollups"></table></div>
      </div>
      <div class="panel">
        <div class="table-header">
          <h2>Scan Events</h2>
          <span class="count" id="events-count"></span>
        </div>
        <div class="scroll"><table id="events"></table></div>
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
    function sortedDistinct(rows, field) {
      return Array.from(new Set(asRows(rows).map(row => String(row[field] || '').trim()).filter(Boolean))).sort((a, b) => a.localeCompare(b));
    }
    function appendSelectOption(select, value, label) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = label;
      select.appendChild(option);
    }
    function populateSelect(id, values, allLabel) {
      const select = document.getElementById(id);
      select.textContent = '';
      appendSelectOption(select, '', allLabel);
      values.forEach(value => appendSelectOption(select, value, value));
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
        addPriorityAction(list, 'warning', 'Investigate partial collection', String(partialShares) + ' share(s) have incomplete metadata. Open Diagnostics for collection-error detail.');
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
      const riskOrder = { High: 0, Review: 1, Monitor: 2 };
      if (Array.isArray(data.owner_risk_pivots) && data.owner_risk_pivots.length > 0) {
        return data.owner_risk_pivots.slice().sort((a, b) => Number(riskOrder[a.RiskLevel] ?? 99) - Number(riskOrder[b.RiskLevel] ?? 99) || String(a.BusinessUnit).localeCompare(String(b.BusinessUnit)) || String(a.Owner).localeCompare(String(b.Owner)));
      }
      const pivots = new Map();
      data.owner_mappings.forEach(mapping => {
        const matchedItems = data.items.filter(item => wildcardMatch(mapping.Pattern, item.FullPath));
        const matchedItemIds = new Set(matchedItems.map(item => String(item.ItemId || '')).filter(Boolean));
        const matchedShareIds = new Set(matchedItems.map(item => String(item.ShareId || '')).filter(Boolean));
        data.shares.forEach(share => {
          const sharePaths = [share.UNCPath, share.LocalPath].map(value => String(value || '')).filter(Boolean);
          if (sharePaths.some(path => wildcardMatch(mapping.Pattern, path))) {
            const shareId = String(share.ShareId || '');
            if (shareId) { matchedShareIds.add(shareId); }
          }
        });
        const mappedFindings = data.findings.filter(finding => {
          const itemId = String(finding.ItemId || '');
          const shareId = String(finding.ShareId || '');
          const fullPath = String(finding.FullPath || '');
          return (itemId && matchedItemIds.has(itemId)) ||
            (shareId && matchedShareIds.has(shareId)) ||
            (fullPath && wildcardMatch(mapping.Pattern, fullPath));
        });
        const mappedConflicts = data.conflicts.filter(conflict => {
          const itemId = String(conflict.ItemId || '');
          const shareId = String(conflict.ShareId || '');
          return (itemId && matchedItemIds.has(itemId)) ||
            (shareId && matchedShareIds.has(shareId));
        });
        const partialShares = data.shares.filter(share => matchedShareIds.has(String(share.ShareId || '')) && String(share.PartialData) === 'True');
        const highRiskCount = mappedFindings.filter(isHighRisk).length + mappedConflicts.filter(isHighRisk).length;
        const riskLevel = highRiskCount > 0 ? 'High' : ((mappedFindings.length + mappedConflicts.length + partialShares.length) > 0 ? 'Review' : 'Monitor');
        const key = [mapping.BusinessUnit || '', mapping.Owner || '', mapping.Pattern || ''].join('|');
        pivots.set(key, {
          BusinessUnit: mapping.BusinessUnit || '',
          Owner: mapping.Owner || '',
          Pattern: mapping.Pattern || '',
          Source: mapping.Source || '',
          MatchingItems: matchedItems.length,
          Directories: matchedItems.filter(item => item.ItemType === 'Directory').length,
          Files: matchedItems.filter(item => item.ItemType === 'File').length,
          FindingCount: mappedFindings.length,
          ConflictCount: mappedConflicts.length,
          PartialShareCount: partialShares.length,
          RiskLevel: riskLevel
        });
      });
      return Array.from(pivots.values()).sort((a, b) => Number(riskOrder[a.RiskLevel] ?? 99) - Number(riskOrder[b.RiskLevel] ?? 99) || String(a.BusinessUnit).localeCompare(String(b.BusinessUnit)) || String(a.Owner).localeCompare(String(b.Owner)));
    }
    const itemById = new Map(data.items.map(item => [String(item.ItemId || ''), item]));
    const shareById = new Map(data.shares.map(share => [String(share.ShareId || ''), share]));
    function getDashboardFilterState() {
      return {
        query: document.getElementById('filter').value.toLowerCase(),
        businessUnit: document.getElementById('business-unit-filter').value,
        owner: document.getElementById('owner-filter').value,
        riskLevel: document.getElementById('risk-filter').value
      };
    }
    function hasOwnerContextFilter(state) {
      return Boolean(state.businessUnit || state.owner || state.riskLevel);
    }
    function pivotMatchesState(pivot, state) {
      return (!state.businessUnit || String(pivot.BusinessUnit || '') === state.businessUnit) &&
        (!state.owner || String(pivot.Owner || '') === state.owner) &&
        (!state.riskLevel || String(pivot.RiskLevel || '') === state.riskLevel);
    }
    function rowMatchesSearch(row, state) {
      return JSON.stringify(row).toLowerCase().includes(state.query);
    }
    function rowMatchesPivot(row, pivot) {
      const pattern = String(pivot.Pattern || '');
      if (!pattern) { return false; }
      if (String(row.Pattern || '') === pattern) { return true; }
      if (String(row.BusinessUnit || '') === String(pivot.BusinessUnit || '') && String(row.Owner || '') === String(pivot.Owner || '')) { return true; }

      const fullPath = String(row.FullPath || '');
      if (fullPath && wildcardMatch(pattern, fullPath)) { return true; }

      const item = itemById.get(String(row.ItemId || ''));
      if (item && wildcardMatch(pattern, item.FullPath)) { return true; }

      const share = shareById.get(String(row.ShareId || ''));
      if (share) {
        const sharePaths = [share.UNCPath, share.LocalPath].map(value => String(value || '')).filter(Boolean);
        if (sharePaths.some(path => wildcardMatch(pattern, path))) { return true; }
      }
      return false;
    }
    function rowMatchesOwnerContext(row, state) {
      if (!hasOwnerContextFilter(state)) { return true; }
      return owner_pivots.filter(pivot => pivotMatchesState(pivot, state)).some(pivot => rowMatchesPivot(row, pivot));
    }
    function filterRows(rows, state, ownerAware) {
      return asRows(rows).filter(row => rowMatchesSearch(row, state) && (!ownerAware || rowMatchesOwnerContext(row, state)));
    }
    function filterOwnerPivots(rows, state) {
      return asRows(rows).filter(row => rowMatchesSearch(row, state) && pivotMatchesState(row, state));
    }
    function populateDashboardFilters() {
      populateSelect('business-unit-filter', sortedDistinct(owner_pivots, 'BusinessUnit'), 'All business units');
      populateSelect('owner-filter', sortedDistinct(owner_pivots, 'Owner'), 'All data owners');
      populateSelect('risk-filter', sortedDistinct(owner_pivots, 'RiskLevel'), 'All review risks');
    }
    function updateFilterNote(state) {
      const labels = [];
      if (state.businessUnit) { labels.push('Business Unit: ' + state.businessUnit); }
      if (state.owner) { labels.push('Data Owner: ' + state.owner); }
      if (state.riskLevel) { labels.push('Review Risk: ' + state.riskLevel); }
      if (state.query) { labels.push('Search: ' + state.query); }
      document.getElementById('active-filter-note').textContent = labels.length > 0 ? ('Active dashboard filters: ' + labels.join('; ')) : 'Showing all owner and business-unit review rows.';
    }
    function setWorkbenchStat(target, label, value) {
      const wrapper = document.createElement('div');
      const dt = document.createElement('dt');
      dt.textContent = label;
      const dd = document.createElement('dd');
      dd.textContent = String(value);
      wrapper.appendChild(dt);
      wrapper.appendChild(dd);
      target.appendChild(wrapper);
    }
    function renderWorkbenchStats(stats) {
      const target = document.getElementById('workbench-stats');
      target.textContent = '';
      stats.forEach(stat => setWorkbenchStat(target, stat.label, stat.value));
    }
    function normalizeIdentity(value) {
      return String(value || '').trim().toLowerCase();
    }
    function addIdentity(identitySet, value) {
      const key = normalizeIdentity(value);
      if (key) { identitySet.add(key); }
    }
    function getItemPath(row) {
      const item = itemById.get(String(row.ItemId || ''));
      return String(row.FullPath || (item ? item.FullPath : '') || '');
    }
    function getWorkbenchRiskRows(state) {
      const findings = filterRows(data.findings, state, true).map(row => ({
        Source: 'Finding',
        Type: row.FindingType || '',
        Severity: row.Severity || '',
        Identity: row.Identity || '',
        Path: getItemPath(row),
        Message: row.Message || ''
      }));
      const conflicts = filterRows(data.conflicts, state, true).map(row => ({
        Source: 'Conflict',
        Type: row.ConflictType || '',
        Severity: row.Severity || '',
        Identity: row.Identity || '',
        Path: getItemPath(row),
        Message: row.Message || ''
      }));
      return findings.concat(conflicts)
        .sort((a, b) => Number(severityRank[b.Severity] ?? -1) - Number(severityRank[a.Severity] ?? -1) || String(a.Type).localeCompare(String(b.Type)) || String(a.Path).localeCompare(String(b.Path)))
        .slice(0, 10);
    }
    function getWorkbenchGroupRows(state, riskRows) {
      const identitySet = new Set();
      riskRows.forEach(row => addIdentity(identitySet, row.Identity));
      filterRows(data.acl_entries, state, true).forEach(row => addIdentity(identitySet, row.Identity));
      filterRows(data.share_permissions, state, true).forEach(row => addIdentity(identitySet, row.Identity));
      const rows = group_browser_rows.filter(row => {
        const parent = normalizeIdentity(row.ParentGroup);
        const child = normalizeIdentity(row.ChildIdentity);
        if (identitySet.size === 0) {
          return rowMatchesSearch(row, state);
        }
        return identitySet.has(parent) || identitySet.has(child);
      });
      return rows
        .sort((a, b) => String(a.ParentGroup).localeCompare(String(b.ParentGroup)) || Number(a.Depth || 0) - Number(b.Depth || 0) || String(a.ChildIdentity).localeCompare(String(b.ChildIdentity)))
        .slice(0, 12);
    }
    function renderWorkbenchActions(state, pivots, riskRows, groupRows) {
      const list = document.getElementById('workbench-actions');
      list.textContent = '';
      const highRisks = riskRows.filter(row => Number(severityRank[row.Severity] ?? -1) >= 3).length;
      const longPathRisks = riskRows.filter(row => row.Type === 'LongPathOperationalPolicy' || row.Type === 'AzureFullPathLimit' || row.Type === 'AzurePathComponentLimit').length;
      const deepAccessRisks = riskRows.filter(row => row.Type === 'DeepExplicitAce' || row.Type === 'BrokenInheritance').length;
      const truncatedGroups = groupRows.filter(row => String(row.IsTruncated) === 'True').length;
      if (pivots.length === 0 && hasOwnerContextFilter(state)) {
        addPriorityAction(list, 'warning', 'Check owner mapping coverage', 'No owner pivot matched the active business-unit, owner, or risk filter.');
      }
      if (highRisks > 0) {
        addPriorityAction(list, 'high', 'Start with high-priority rows', String(highRisks) + ' finding or conflict row(s) in this context need review first.');
      }
      if (longPathRisks > 0) {
        addPriorityAction(list, 'warning', 'Confirm migration path handling', String(longPathRisks) + ' path row(s) need remediation planning or migration exception review.');
      }
      if (deepAccessRisks > 0) {
        addPriorityAction(list, 'warning', 'Validate delegated folder access', String(deepAccessRisks) + ' inheritance or deep explicit permission row(s) should be reviewed with the data owner.');
      }
      if (truncatedGroups > 0) {
        addPriorityAction(list, 'warning', 'Rerun with deeper group expansion', String(truncatedGroups) + ' related group edge(s) were truncated.');
      }
      if (groupRows.length > 0) {
        addPriorityAction(list, 'good', 'Use related groups for access review', String(groupRows.length) + ' group edge(s) are shown for the current review context.');
      }
      if (list.children.length === 0) {
        addPriorityAction(list, 'good', 'Review context is low risk', 'Use the owner pivot and related rows to confirm ownership before migration planning continues.');
      }
    }
    function renderReviewWorkbench(state) {
      const pivots = filterOwnerPivots(owner_pivots, state);
      const riskRows = getWorkbenchRiskRows(state);
      const groupRows = getWorkbenchGroupRows(state, riskRows);
      const businessUnits = distinctCount(pivots, 'BusinessUnit');
      const owners = distinctCount(pivots, 'Owner');
      const matchingItems = pivots.reduce((sum, pivot) => sum + Number(pivot.MatchingItems || 0), 0);
      const partialShares = pivots.reduce((sum, pivot) => sum + Number(pivot.PartialShareCount || 0), 0);
      const directIdentities = pivots.reduce((sum, pivot) => sum + Number(pivot.DirectIdentityCount || 0), 0);
      const expandedMembers = pivots.reduce((sum, pivot) => sum + Number(pivot.ExpandedMemberCount || 0), 0);
      const labels = [];
      if (state.businessUnit) { labels.push(state.businessUnit); }
      if (state.owner) { labels.push(state.owner); }
      if (state.riskLevel) { labels.push(state.riskLevel + ' risk'); }
      if (state.query) { labels.push('search "' + state.query + '"'); }
      document.getElementById('workbench-context').textContent = labels.length > 0 ? ('Reviewing ' + labels.join(' / ') + '. Use this snapshot to brief the owner before opening the detailed tables.') : 'Enterprise-wide review snapshot. Select a business unit, data owner, or risk level to narrow this workbench.';
      document.getElementById('workbench-count').textContent = String(pivots.length) + ' owner pivot' + (pivots.length === 1 ? '' : 's');
      renderWorkbenchStats([
        { label: 'Business Units', value: businessUnits },
        { label: 'Data Owners', value: owners },
        { label: 'Matching Items', value: matchingItems },
        { label: 'Direct Identities', value: directIdentities },
        { label: 'Expanded Members', value: expandedMembers },
        { label: 'Top Risks', value: riskRows.length },
        { label: 'Related Groups', value: groupRows.length },
        { label: 'Partial Shares', value: partialShares }
      ]);
      renderWorkbenchActions(state, pivots, riskRows, groupRows);
      renderTable('workbench-risks', riskRows);
      renderTable('workbench-groups', groupRows);
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
    const collection_errors = data.findings.filter(row => row.FindingType === 'CollectionError');
    const finding_rollups = buildRollups(data.findings, ['FindingType', 'Severity']);
    const conflict_rollups = buildRollups(data.conflicts, ['ConflictType', 'Severity']);
    const collection_error_rollups = buildRollups(collection_errors, ['ObservedValue', 'ShareId']);
    const org_rollups = buildOrgChainRollups();
    const group_browser_rows = buildGroupBrowserRows();
    const finding_chart_rows = buildRollups(data.findings, ['FindingType']).map(row => ({ Label: row.FindingType || 'Unspecified', Count: row.Count, FilterValue: row.FindingType || '' }));
    const conflict_chart_rows = buildRollups(data.conflicts, ['ConflictType']).map(row => ({ Label: row.ConflictType || 'Unspecified', Count: row.Count, FilterValue: row.ConflictType || '' }));
    const owner_chart_rows = buildOwnerChartRows();
    const collection_error_chart_rows = buildRollups(collection_errors, ['ObservedValue']).map(row => ({ Label: row.ObservedValue || 'Unspecified', Count: row.Count, FilterValue: row.ObservedValue || '' }));
    function applyGroupBrowser() {
      const q = document.getElementById('group-filter').value.toLowerCase();
      const match = row => JSON.stringify(row).toLowerCase().includes(q);
      renderTable('group-browser', group_browser_rows.filter(match));
    }
    function applyFilter() {
      const state = getDashboardFilterState();
      updateFilterNote(state);
      renderTable('findings', filterRows(data.findings, state, true));
      renderTable('finding-rollups', filterRows(finding_rollups, state, false));
      renderTable('conflicts', filterRows(data.conflicts, state, true));
      renderTable('conflict-rollups', filterRows(conflict_rollups, state, false));
      renderTable('owners', filterRows(data.owner_mappings, state, true));
      renderTable('owner-pivots', filterOwnerPivots(owner_pivots, state));
      renderTable('groups', filterRows(data.group_edges, state, false));
      renderTable('collection-errors', filterRows(collection_errors, state, true));
      renderTable('collection-error-rollups', filterRows(collection_error_rollups, state, false));
      renderTable('org-rollups', filterRows(org_rollups, state, false));
      renderTable('events', filterRows(data.scan_events, state, false));
      renderReviewWorkbench(state);
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
    document.getElementById('business-unit-filter').addEventListener('change', applyFilter);
    document.getElementById('owner-filter').addEventListener('change', applyFilter);
    document.getElementById('risk-filter').addEventListener('change', applyFilter);
    document.getElementById('group-filter').addEventListener('input', applyGroupBrowser);
    populateDashboardFilters();
    renderSummary();
    renderBarChart('finding-chart', finding_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'warning', viewName: 'findings' });
    renderBarChart('conflict-chart', conflict_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'high', viewName: 'conflicts' });
    renderBarChart('owner-chart', owner_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'owner', viewName: 'owners' });
    renderBarChart('collection-error-chart', collection_error_chart_rows, { labelField: 'Label', valueField: 'Count', fillClass: 'warning', viewName: 'diagnostics' });
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
