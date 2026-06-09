import { useEffect, useMemo, useState } from "react";
import type { DataRow } from "../data/schema";

interface VirtualTableProps {
  rows: DataRow[];
  columns?: string[];
  columnLabels?: Record<string, string>;
  pageSize?: number;
  title?: string;
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

export function VirtualTable({
  rows,
  columns,
  columnLabels,
  pageSize = 50,
  title = "Evidence table",
  onRowSelect,
  selectedKey,
  rowKey
}: VirtualTableProps) {
  const [page, setPage] = useState(0);
  const [sort, setSort] = useState<SortState | null>(null);
  const [filterText, setFilterText] = useState("");
  const updateFilterText = (value: string) => setFilterText(value);
  const visibleColumns = useMemo(() => getColumns(rows, columns), [columns, rows]);
  const filteredRows = useMemo(() => {
    const normalizedFilter = filterText.trim().toLowerCase();
    const indexedRows = rows.map((row, index) => ({ row, index }));
    if (!normalizedFilter) {
      return indexedRows;
    }

    return indexedRows.filter(({ row }) =>
      Object.values(row).join(" ").toLowerCase().includes(normalizedFilter)
    );
  }, [filterText, rows]);
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

  useEffect(() => {
    setPage(0);
  }, [filterText, rows]);

  const toggleSort = (column: string) => {
    setPage(0);
    setSort((current) => {
      if (!current || current.column !== column) {
        return { column, direction: "asc" };
      }

      return { column, direction: current.direction === "asc" ? "desc" : "asc" };
    });
  };

  return (
    <div className="table-shell" aria-label={title}>
      <div className="table-meta">
        <span>{sortedRows.length === 0 ? `Showing 0 of ${filteredRows.length}` : `Showing ${start + 1}-${end} of ${filteredRows.length}`}</span>
        <div className="pager" aria-label={`${title} pages`}>
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
      <div className="table-scroll">
        <table aria-label={title}>
          <thead>
            <tr>
              {visibleColumns.map((column) => {
                const label = columnLabels?.[column] ?? humanizeColumnName(column);
                const activeSort = sort?.column === column ? sort.direction : null;
                return (
                  <th key={column} title={columnLabels?.[column] ?? column} aria-sort={activeSort === "asc" ? "ascending" : activeSort === "desc" ? "descending" : "none"}>
                    <button type="button" className="sort-header" onClick={() => toggleSort(column)} aria-label={`Sort by ${label}`}>
                      <span>{label}</span>
                      <span aria-hidden="true">{activeSort === "asc" ? "ASC" : activeSort === "desc" ? "DESC" : "SORT"}</span>
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
