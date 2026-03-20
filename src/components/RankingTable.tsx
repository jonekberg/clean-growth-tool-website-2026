import { useState } from 'react';
import type { ReactNode } from 'react';

type SortDirection = 'asc' | 'desc';

export interface TableColumn<T> {
  key: string;
  label: string;
  align?: 'left' | 'right';
  render: (row: T) => ReactNode;
  sortValue: (row: T) => number | string;
}

interface RankingTableProps<T extends object> {
  columns: TableColumn<T>[];
  rows: T[];
  initialSortKey: string;
  initialSortDirection?: SortDirection;
  onRowClick?: (row: T) => void;
  rowKey?: (row: T, index: number) => string;
}

export function RankingTable<T extends object>({
  columns,
  rows,
  initialSortKey,
  initialSortDirection = 'desc',
  onRowClick,
  rowKey,
}: RankingTableProps<T>) {
  const [sortKey, setSortKey] = useState(initialSortKey);
  const [sortDirection, setSortDirection] = useState<SortDirection>(initialSortDirection);

  const activeColumn = columns.find((column) => column.key === sortKey) ?? columns[0];

  const sortedRows = [...rows].sort((left, right) => {
    const leftValue = activeColumn.sortValue(left);
    const rightValue = activeColumn.sortValue(right);

    if (typeof leftValue === 'string' || typeof rightValue === 'string') {
      const result = String(leftValue).localeCompare(String(rightValue), undefined, { numeric: true, sensitivity: 'base' });
      return sortDirection === 'asc' ? result : -result;
    }

    const result = Number(leftValue) - Number(rightValue);
    return sortDirection === 'asc' ? result : -result;
  });

  const handleSort = (column: TableColumn<T>) => {
    if (sortKey === column.key) {
      setSortDirection((previous) => (previous === 'desc' ? 'asc' : 'desc'));
      return;
    }

    setSortKey(column.key);
    setSortDirection(column.align === 'left' ? 'asc' : 'desc');
  };

  return (
    <div className="table-shell">
      <table className="ranking-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key} className={column.align === 'right' ? 'is-right' : ''}>
                <button className="table-sort" onClick={() => handleSort(column)} type="button">
                  {column.label}
                  <span className="table-sort__icon">
                    {sortKey === column.key ? (sortDirection === 'desc' ? '↓' : '↑') : '↕'}
                  </span>
                </button>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sortedRows.map((row, index) => (
            <tr key={rowKey ? rowKey(row, index) : String(index)} className={onRowClick ? 'is-clickable' : ''} onClick={() => onRowClick?.(row)}>
              {columns.map((column) => (
                <td key={column.key} className={column.align === 'right' ? 'is-right' : ''}>
                  {column.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
