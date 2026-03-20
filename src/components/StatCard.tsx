import type { ReactNode } from 'react';

interface StatCardProps {
  eyebrow: string;
  title: string;
  value: string;
  detail: ReactNode;
}

export function StatCard({ eyebrow, title, value, detail }: StatCardProps) {
  return (
    <article className="stat-card">
      <div className="stat-card__eyebrow">{eyebrow}</div>
      <div className="stat-card__title">{title}</div>
      <div className="stat-card__value">{value}</div>
      <div className="stat-card__detail">{detail}</div>
    </article>
  );
}
