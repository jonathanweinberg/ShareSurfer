import { useEffect, useMemo, useState } from "react";
import type { DataRow } from "../data/schema";

interface VirtualTableProps {
  rows: DataRow[];
  columns?: string[];
  selectableColumns?: string[];
  columnLabels?: Record<string, string>;
  pageSize?: number;
  title?: string;
  enableColumnSelection?: boolean;
  enableFieldFilters?: boolean;
  enableExport?: boolean;
  exportFileName?: string;
  onRowSelect?: (row: DataRow, absoluteIndex: number) => void;
  selectedKey?: string;
  rowKey?: (row: DataRow, index: number) => string;
}

type SortDirection = "asc" | "desc";

interface SortState {
  column: string;
  direction: SortDirection;
}

function getColumns(rows: DataRow[], columns?: string[]): string[] {
  if (columns && columns.length > 0) {
    return columns;
  }
  const first = rows[0];
  return first ? Object.keys(first).slice(0, 10) : [];
}

function getSelectableColumns(rows: DataRow[], columns?: string[], selectableColumns?: string[]): string[] {
  if (selectableColumns && selectableColumns.length > 0) {
    return selectableColumns;
  }

  const seen = new Set<string>();
  const result: string[] = [];
  for (const column of columns ?? []) {
    if (!seen.has(column)) {
      seen.add(column);
      result.push(column);
    }
  }
  for (const row of rows) {
    for (const column of Object.keys(row)) {
      if (!seen.has(column)) {
        seen.add(column);
        result.push(column);
      }
    }
  }
  return result;
}

function humanizeColumnName(column: string): string {
  return column
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
    .replace(/_/g, " ")
    .trim();
}

function compareCellValues(left: string, right: string): number {
  const leftNumber = Number(left.replace(/,/g, ""));
  const rightNumber = Number(right.replace(/,/g, ""));
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber) && left.trim() !== "" && right.trim() !== "") {
    return leftNumber - rightNumber;
  }

  return left.localeCompare(right, undefined, { numeric: true, sensitivity: "base" });
}

function sortIndicator(direction: SortDirection | null): string {
  if (direction === "asc") {
    return "▲";
  }
  if (direction === "desc") {
    return "▼";
  }
  return "↕";
}

function csvEscape(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function buildCsvDataUri(rows: Array<{ row: DataRow }>, columns: string[]): string {
  const csvRows = [
    columns.map(csvEscape).join(","),
    ...rows.map(({ row }) => columns.map((column) => csvEscape(row[column] ?? "")).join(","))
  ];
  return `data:text/csv;charset=utf-8,${encodeURIComponent(csvRows.join("\r\n"))}`;
}

function safeDownloadName(title: string): string {
  const normalized = title
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return `${normalized || "sharesurfer-evidence"}-filtered.csv`;
}

export function VirtualTable({
  rows,
  columns,
  selectableColumns,
  columnLabels,
  pageSize = 50,
  title = "Evidence table",
  enableColumnSelection = true,
  enableFieldFilters = false,
  enableExport = false,
  exportFileName,
  onRowSelect,
  selectedKey,
  rowKey
}: VirtualTableProps) {
  const [page, setPage] = useState(0);
  const [sort, setSort] = useState<SortState | null>(null);
  const [filterText, setFilterText] = useState("");
  const [columnFilters, setColumnFilters] = useState<Record<string, string>>({});
  const updateFilterText = (value: string) => setFilterText(value);
  const defaultColumns = useMemo(() => getColumns(rows, columns), [columns, rows]);
  const allColumns = useMemo(() => getSelectableColumns(rows, columns, selectableColumns), [columns, rows, selectableColumns]);
  const [selectedColumns, setSelectedColumns] = useState<string[]>(defaultColumns);
  const defaultColumnsKey = defaultColumns.join("\u001F");
  const visibleColumns = useMemo(
    () => (enableColumnSelection ? selectedColumns.filter((column) => allColumns.includes(column)) : defaultColumns),
    [allColumns, defaultColumns, enableColumnSelection, selectedColumns]
  );
  const activeColumnFilters = useMemo(
    () =>
      Object.entries(columnFilters)
        .map(([column, value]) => [column, value.trim().toLowerCase()] as const)
        .filter(([, value]) => value !== ""),
    [columnFilters]
  );
  const filteredRows = useMemo(() => {
    const normalizedFilter = filterText.trim().toLowerCase();
    const indexedRows = rows.map((row, index) => ({ row, index }));
    if (!normalizedFilter && activeColumnFilters.length === 0) {
      return indexedRows;
    }

    return indexedRows.filter(({ row }) => {
      const matchesGlobal = !normalizedFilter || Object.values(row).join(" ").toLowerCase().includes(normalizedFilter);
      const matchesColumns = activeColumnFilters.every(([column, value]) =>
        String(row[column] ?? "").toLowerCase().includes(value)
      );
      return matchesGlobal && matchesColumns;
    });
  }, [activeColumnFilters, filterText, rows]);
  const sortedRows = useMemo(() => {
    if (!sort) {
      return filteredRows;
    }

    return [...filteredRows].sort((left, right) => {
      const result = compareCellValues(left.row[sort.column] ?? "", right.row[sort.column] ?? "");
      return sort.direction === "asc" ? result : -result;
    });
  }, [filteredRows, sort]);
  const pageCount = Math.max(1, Math.ceil(sortedRows.length / pageSize));
  const safePage = Math.min(page, pageCount - 1);
  const start = safePage * pageSize;
  const visibleRows = sortedRows.slice(start, start + pageSize);
  const end = sortedRows.length === 0 ? 0 : Math.min(start + visibleRows.length, sortedRows.length);
  const pageSummary =
    sortedRows.length === 0 ? `Showing 0 of ${filteredRows.length}` : `Showing ${start + 1}-${end} of ${filteredRows.length}`;
  const filteredSummary =
    (filterText.trim() || activeColumnFilters.length > 0) && filteredRows.length !== rows.length ? `${pageSummary} (filtered from ${rows.length})` : pageSummary;
  const exportHref = useMemo(() => buildCsvDataUri(sortedRows, visibleColumns), [sortedRows, visibleColumns]);

  useEffect(() => {
    setPage(0);
  }, [activeColumnFilters, filterText, rows, visibleColumns]);

  useEffect(() => {
    setSelectedColumns(defaultColumns);
  }, [defaultColumnsKey]);

  useEffect(() => {
    setColumnFilters((current) =>
      Object.fromEntries(Object.entries(current).filter(([column]) => allColumns.includes(column)))
    );
  }, [allColumns]);

  const toggleSort = (column: string) => {
    setPage(0);
    setSort((current) => {
      if (!current || current.column !== column) {
        return { column, direction: "asc" };
      }

      return { column, direction: current.direction === "asc" ? "desc" : "asc" };
    });
  };

  const labelForColumn = (column: string) => columnLabels?.[column] ?? humanizeColumnName(column);
  const updateColumnFilter = (column: string, value: string) => {
    setColumnFilters((current) => ({ ...current, [column]: value }));
  };

  return (
    <div className="table-shell" aria-label={title}>
      <div className="table-meta">
        <span>{filteredSummary}</span>
        <div className="pager" aria-label={`${title} pages`}>
          {enableExport ? (
            <a className="link-button compact-action" href={exportHref} download={exportFileName ?? safeDownloadName(title)}>
              Export shown CSV
            </a>
          ) : null}
          <label className="table-filter">
            <span className="sr-only">Filter {title} rows</span>
            <input
              type="search"
              value={filterText}
              onInput={(event) => updateFilterText(event.currentTarget.value)}
              onChange={(event) => updateFilterText(event.currentTarget.value)}
              placeholder="Filter rows..."
              aria-label={`Filter ${title} rows`}
            />
          </label>
          <button type="button" onClick={() => setPage(Math.max(0, safePage - 1))} disabled={safePage === 0}>
            Previous
          </button>
          <span>
            {safePage + 1} / {pageCount}
          </span>
          <button
            type="button"
            aria-label="Next page"
            onClick={() => setPage(Math.min(pageCount - 1, safePage + 1))}
            disabled={safePage >= pageCount - 1}
          >
            Next
          </button>
        </div>
      </div>
      {(enableColumnSelection || enableFieldFilters) && allColumns.length > 0 ? (
        <div className="table-tools">
          {enableColumnSelection ? (
            <details className="table-tool-panel">
              <summary>Columns</summary>
              <label>
                <span className="sr-only">Select columns for {title}</span>
                <select
                  multiple
                  value={visibleColumns}
                  aria-label={`Select columns for ${title}`}
                  onChange={(event) => {
                    const nextColumns = Array.from(event.currentTarget.selectedOptions).map((option) => option.value);
                    setSelectedColumns(nextColumns);
                  }}
                >
                  {allColumns.map((column) => (
                    <option key={column} value={column}>
                      {labelForColumn(column)}
                    </option>
                  ))}
                </select>
              </label>
              <div className="tool-actions">
                <button type="button" className="clear-button" onClick={() => setSelectedColumns(defaultColumns)}>
                  Reset columns
                </button>
                <button type="button" className="clear-button" onClick={() => setSelectedColumns(allColumns)}>
                  Select every column
                </button>
              </div>
            </details>
          ) : null}
          {enableFieldFilters ? (
            <details className="table-tool-panel field-filter-panel" open>
              <summary>Field filters</summary>
              <div className="field-filter-grid">
                {allColumns.map((column) => (
                  <label key={column}>
                    <span>{labelForColumn(column)}</span>
                    <input
                      type="search"
                      value={columnFilters[column] ?? ""}
                      onInput={(event) => updateColumnFilter(column, event.currentTarget.value)}
                      onChange={(event) => updateColumnFilter(column, event.currentTarget.value)}
                      placeholder={`Filter ${labelForColumn(column)}`}
                      aria-label={`Filter ${title} by ${labelForColumn(column)}`}
                    />
                  </label>
                ))}
              </div>
              <div className="tool-actions">
                <button type="button" className="clear-button" onClick={() => setColumnFilters({})}>
                  Clear field filters
                </button>
              </div>
              {activeColumnFilters.length > 0 ? (
                <div className="active-field-filters" aria-label={`${title} active field filters`}>
                  {activeColumnFilters.map(([column, value]) => (
                    <span key={`${column}-${value}`}>{labelForColumn(column)}: {value}</span>
                  ))}
                </div>
              ) : null}
            </details>
          ) : null}
        </div>
      ) : null}
      <div className="table-scroll">
        <table aria-label={title}>
          <thead>
            <tr>
              {visibleColumns.map((column) => {
                const label = labelForColumn(column);
                const activeSort = sort?.column === column ? sort.direction : null;
                return (
                  <th key={column} title={columnLabels?.[column] ?? column} aria-sort={activeSort === "asc" ? "ascending" : activeSort === "desc" ? "descending" : "none"}>
                    <button type="button" className="sort-header" onClick={() => toggleSort(column)} aria-label={`Sort by ${label}`}>
                      <span>{label}</span>
                      <span aria-hidden="true">{sortIndicator(activeSort)}</span>
                    </button>
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {visibleRows.map(({ row, index }) => {
              const key = rowKey ? rowKey(row, index) : `${index}-${visibleColumns.map((column) => row[column]).join("|")}`;
              const selected = selectedKey !== undefined && key === selectedKey;
              return (
                <tr
                  key={key}
                  className={`${onRowSelect ? "clickable-row" : ""} ${selected ? "selected-row" : ""}`}
                  onClick={() => onRowSelect?.(row, index)}
                >
                  {visibleColumns.map((column) => (
                    <td key={column} title={row[column] ?? ""}>
                      {row[column] ?? ""}
                    </td>
                  ))}
                </tr>
              );
            })}
            {visibleRows.length === 0 ? (
              <tr>
                <td colSpan={Math.max(1, visibleColumns.length)} className="empty-cell">
                  No rows match the current view.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
