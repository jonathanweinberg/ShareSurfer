import { useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
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

interface ColumnResizeState {
  column: string;
  startX: number;
  startWidth: number;
}

interface TextFilter {
  include: string[];
  exclude: string[];
  label: string;
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

function splitFilterTerms(value: string): string[] {
  return value.match(/[!-]?"[^"]+"|\S+/g) ?? [];
}

function normalizeFilterTerm(term: string): { value: string; exclude: boolean } | null {
  const trimmed = term.trim();
  if (!trimmed) {
    return null;
  }

  const exclude = trimmed.startsWith("-") || trimmed.startsWith("!");
  const withoutModifier = exclude ? trimmed.slice(1) : trimmed;
  const value = withoutModifier.replace(/^"|"$/g, "").trim().toLowerCase();
  if (!value) {
    return null;
  }

  return { value, exclude };
}

function parseTextFilter(value: string): TextFilter {
  const include: string[] = [];
  const exclude: string[] = [];
  for (const term of splitFilterTerms(value)) {
    const parsed = normalizeFilterTerm(term);
    if (!parsed) {
      continue;
    }
    if (parsed.exclude) {
      exclude.push(parsed.value);
    } else {
      include.push(parsed.value);
    }
  }

  return { include, exclude, label: value.trim() };
}

function textFilterIsActive(filter: TextFilter): boolean {
  return filter.include.length > 0 || filter.exclude.length > 0;
}

function textMatchesFilter(value: string, filter: TextFilter): boolean {
  const normalized = value.toLowerCase();
  return filter.include.every((term) => normalized.includes(term)) && filter.exclude.every((term) => !normalized.includes(term));
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
  const [columnWidths, setColumnWidths] = useState<Record<string, number>>({});
  const activeResize = useRef<ColumnResizeState | null>(null);
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
        .map(([column, value]) => [column, parseTextFilter(value)] as const)
        .filter(([, value]) => textFilterIsActive(value)),
    [columnFilters]
  );
  const filteredRows = useMemo(() => {
    const globalFilter = parseTextFilter(filterText);
    const indexedRows = rows.map((row, index) => ({ row, index }));
    if (!textFilterIsActive(globalFilter) && activeColumnFilters.length === 0) {
      return indexedRows;
    }

    return indexedRows.filter(({ row }) => {
      const matchesGlobal = !textFilterIsActive(globalFilter) || textMatchesFilter(Object.values(row).join(" "), globalFilter);
      const matchesColumns = activeColumnFilters.every(([column, value]) =>
        textMatchesFilter(String(row[column] ?? ""), value)
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
  const tableMinWidth = useMemo(
    () => Math.max(920, visibleColumns.reduce((sum, column) => sum + (columnWidths[column] ?? 160), 0)),
    [columnWidths, visibleColumns]
  );

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
    setColumnWidths((current) =>
      Object.fromEntries(Object.entries(current).filter(([column]) => allColumns.includes(column)))
    );
  }, [allColumns]);

  useEffect(() => {
    return () => {
      window.removeEventListener("pointermove", handleColumnResize);
      window.removeEventListener("pointerup", stopColumnResize);
    };
  }, []);

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
  function handleColumnResize(event: PointerEvent) {
    const resize = activeResize.current;
    if (!resize) {
      return;
    }

    if (!Number.isFinite(event.clientX)) {
      return;
    }

    const nextWidth = Math.max(96, Math.round(resize.startWidth + event.clientX - resize.startX));
    setColumnWidths((current) => ({ ...current, [resize.column]: nextWidth }));
  }
  function stopColumnResize() {
    activeResize.current = null;
    document.body.classList.remove("resizing-column");
    window.removeEventListener("pointermove", handleColumnResize);
    window.removeEventListener("pointerup", stopColumnResize);
  }
  const startColumnResize = (column: string, event: ReactPointerEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopPropagation();
    const header = event.currentTarget.closest("th");
    const measuredWidth = header?.getBoundingClientRect().width ?? 0;
    activeResize.current = {
      column,
      startX: Number.isFinite(event.clientX) ? event.clientX : 0,
      startWidth: columnWidths[column] ?? Math.max(160, Math.round(Number.isFinite(measuredWidth) ? measuredWidth : 0))
    };
    document.body.classList.add("resizing-column");
    window.addEventListener("pointermove", handleColumnResize);
    window.addEventListener("pointerup", stopColumnResize);
  };
  const resetColumnWidth = (column: string) => {
    setColumnWidths((current) => {
      const next = { ...current };
      delete next[column];
      return next;
    });
  };
  const toggleColumn = (column: string, checked: boolean) => {
    setSelectedColumns((current) => {
      if (checked) {
        const next = new Set([...current, column]);
        return allColumns.filter((candidate) => next.has(candidate));
      }

      if (current.filter((candidate) => allColumns.includes(candidate)).length <= 1) {
        return current;
      }

      return current.filter((candidate) => candidate !== column);
    });
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
              <fieldset className="column-checkbox-list" aria-label={`Select columns for ${title}`}>
                <legend className="sr-only">Select columns for {title}</legend>
                {allColumns.map((column) => {
                  const checked = visibleColumns.includes(column);
                  return (
                    <label key={column} className="column-checkbox-row">
                      <input
                        type="checkbox"
                        value={column}
                        checked={checked}
                        disabled={checked && visibleColumns.length <= 1}
                        onChange={(event) => toggleColumn(column, event.currentTarget.checked)}
                      />
                      <span>{labelForColumn(column)}</span>
                    </label>
                  );
                })}
              </fieldset>
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
                    <span key={`${column}-${value.label}`}>{labelForColumn(column)}: {value.label}</span>
                  ))}
                </div>
              ) : null}
            </details>
          ) : null}
        </div>
      ) : null}
      <div className="table-scroll">
        <table aria-label={title} style={{ minWidth: tableMinWidth }}>
          <colgroup>
            {visibleColumns.map((column) => (
              <col key={column} style={{ width: `${columnWidths[column] ?? 160}px` }} />
            ))}
          </colgroup>
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
                    <button
                      type="button"
                      className="column-resizer"
                      aria-label={`Resize ${label} column`}
                      title={`Resize ${label} column`}
                      onPointerDown={(event) => startColumnResize(column, event)}
                      onDoubleClick={() => resetColumnWidth(column)}
                    />
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
