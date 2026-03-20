import { useEffect, useRef } from 'react';
import type { Config, Data, Layout } from 'plotly.js';
import { formatShare } from '../lib/format';

interface ScatterPoint {
  label: string;
  x: number;
  y: number;
  size?: number;
  color?: number;
}

interface ScatterPanelProps {
  title: string;
  subtitle: string;
  points: ScatterPoint[];
  xLabel: string;
  yLabel: string;
}

export function ScatterPanel({ title, subtitle, points, xLabel, yLabel }: ScatterPanelProps) {
  const chartRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!chartRef.current || points.length === 0) {
      return;
    }

    let active = true;

    const data: Data[] = [
      {
        hovertemplate:
          '<b>%{text}</b><br>' + `${xLabel}: %{x:.3f}<br>` + `${yLabel}: %{y:.3f}<br>` + 'Employment share: %{customdata}<extra></extra>',
        marker: {
          color: points.map((point) => point.color ?? point.y),
          colorscale: [
            [0, '#dceff0'],
            [0.5, '#65d9d6'],
            [1, '#0d5d7d'],
          ],
          line: {
            color: 'rgba(6, 38, 64, 0.28)',
            width: 1,
          },
          opacity: 0.85,
          size: points.map((point) => Math.max(10, (point.size ?? 0.05) * 180)),
        },
        mode: 'markers',
        text: points.map((point) => point.label),
        customdata: points.map((point) => formatShare(point.size ?? 0)),
        type: 'scattergl',
        x: points.map((point) => point.x),
        y: points.map((point) => point.y),
      },
    ];

    const layout: Partial<Layout> = {
      autosize: true,
      dragmode: false,
      font: {
        color: '#4f5f6f',
        family: '"Source Sans 3", sans-serif',
        size: 12,
      },
      height: 340,
      margin: { b: 56, l: 56, r: 16, t: 12 },
      paper_bgcolor: 'transparent',
      plot_bgcolor: '#f7fafc',
      xaxis: {
        gridcolor: 'rgba(9, 59, 99, 0.08)',
        linecolor: 'rgba(9, 59, 99, 0.18)',
        title: { text: xLabel },
        zeroline: false,
      },
      yaxis: {
        gridcolor: 'rgba(9, 59, 99, 0.08)',
        linecolor: 'rgba(9, 59, 99, 0.18)',
        title: { text: yLabel },
        zeroline: false,
      },
    };

    const config: Partial<Config> = {
      displayModeBar: false,
      responsive: true,
    };

    void import('plotly.js-dist-min').then(({ default: Plotly }) => {
      if (!active || !chartRef.current) {
        return;
      }

      void Plotly.react(chartRef.current, data, layout, config);
    });

    return () => {
      active = false;

      if (chartRef.current) {
        void import('plotly.js-dist-min').then(({ default: Plotly }) => {
          Plotly.purge(chartRef.current!);
        });
      }
    };
  }, [points, xLabel, yLabel]);

  if (points.length === 0) {
    return (
      <section className="panel-card">
        <div className="panel-card__header">
          <h3>{title}</h3>
          <p>{subtitle}</p>
        </div>
        <div className="empty-panel">No data available for this view.</div>
      </section>
    );
  }

  return (
    <section className="panel-card chart-panel">
      <div className="panel-card__header">
        <h3>{title}</h3>
        <p>{subtitle}</p>
      </div>
      <div className="chart-canvas" ref={chartRef} />
      <div className="chart-caption">Bubble size reflects local employment share. Hover for details.</div>
    </section>
  );
}
