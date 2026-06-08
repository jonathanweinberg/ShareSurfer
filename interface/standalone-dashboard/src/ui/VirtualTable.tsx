import { useMemo, useState } from "react";
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
  const visibleColumns = useMemo(() => getColumns(rows, columns), [columns, rows]);
  const pageCount = Math.max(1, Math.ceil(rows.length / pageSize));
  const safePage = Math.min(page, pageCount - 1);
  const start = safePage * pageSize;
  const visibleRows = rows.slice(start, start + pageSize);
  const end = rows.length === 0 ? 0 : Math.min(start + visibleRows.length, rows.length);

  return (
    <div className="table-shell" aria-label={title}>
      <div className="table-meta">
        <span>{rows.length === 0 ? "Showing 0 of 0" : `Showing ${start + 1}-${end} of ${rows.length}`}</span>
        <div className="pager" aria-label={`${title} pages`}>
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
              {visibleColumns.map((column) => (
                <th key={column} title={columnLabels?.[column] ?? column}>{columnLabels?.[column] ?? humanizeColumnName(column)}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {visibleRows.map((row, index) => {
              const key = rowKey ? rowKey(row, start + index) : `${start + index}-${visibleColumns.map((column) => row[column]).join("|")}`;
              const selected = selectedKey !== undefined && key === selectedKey;
              return (
                <tr
                  key={key}
                  className={`${onRowSelect ? "clickable-row" : ""} ${selected ? "selected-row" : ""}`}
                  onClick={() => onRowSelect?.(row, start + index)}
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
