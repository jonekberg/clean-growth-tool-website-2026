import { useDeferredValue } from 'react';
import { GeoMap } from '../components/GeoMap';
import { RankingTable, type TableColumn } from '../components/RankingTable';
import { ScatterPanel } from '../components/ScatterPanel';
import { SectionToolbar } from '../components/SectionToolbar';
import { StatCard } from '../components/StatCard';
import { useAsyncResource } from '../hooks/useAsyncResource';
import { loadRegionIndustries } from '../lib/data';
import { formatDecimal, formatInteger, formatPercent, formatShare, formatSigned } from '../lib/format';
import type {
  ContentView,
  EnrichedRegionIndustryRecord,
  GeoLevel,
  GeoMetaRecord,
  IndustryMetaRecord,
  QueryState,
} from '../types';

interface RegionViewProps {
  geoMeta: GeoMetaRecord[];
  industryFilter: string;
  industryMeta: IndustryMetaRecord[];
  level: GeoLevel;
  metric: string;
  onInspectIndustry: (industryCode: string) => void;
  selectedGeo: GeoMetaRecord | null;
  setQuery: (patch: Partial<QueryState>, replace?: boolean) => void;
  view: ContentView;
}

export function RegionView({
  geoMeta,
  industryFilter,
  industryMeta,
  level,
  metric,
  onInspectIndustry,
  selectedGeo,
  setQuery,
  view,
}: RegionViewProps) {
  const regionData = useAsyncResource(
    () => (selectedGeo ? loadRegionIndustries(level, selectedGeo.geoid) : Promise.resolve([])),
    [level, selectedGeo?.geoid],
  );

  const deferredIndustryFilter = useDeferredValue(industryFilter.trim().toLowerCase());

  const industryMetaByCode = new Map(industryMeta.map((record) => [record.industry_code, record]));
  const rows: EnrichedRegionIndustryRecord[] =
    regionData.data?.map((row) => {
      const meta = industryMetaByCode.get(row.industry_code);
      return {
        ...row,
        industry_description: meta?.industry_description ?? row.industry_code,
        industry_complexity: meta?.industry_complexity ?? null,
        industry_complexity_percentile: meta?.industry_complexity_percentile ?? null,
      };
    }) ?? [];

  const visibleRows = deferredIndustryFilter
    ? rows.filter(
        (row) =>
          row.industry_description.toLowerCase().includes(deferredIndustryFilter) || row.industry_code.toLowerCase().includes(deferredIndustryFilter),
      )
    : rows;

  const sortedByMetric = [...visibleRows].sort((left, right) => Number(right[metric as keyof EnrichedRegionIndustryRecord]) - Number(left[metric as keyof EnrichedRegionIndustryRecord]));
  const topFeasible = [...visibleRows].sort((left, right) => right.industry_feasibility_percentile_score - left.industry_feasibility_percentile_score).slice(0, 8);
  const topStrategic = [...visibleRows].sort((left, right) => right.strategic_gain_percentile_score - left.strategic_gain_percentile_score).slice(0, 8);

  const tableColumns: TableColumn<EnrichedRegionIndustryRecord>[] = [
    {
      key: 'industry_description',
      label: 'Industry',
      render: (row) => (
        <div className="table-primary">
          <span>{row.industry_description}</span>
          <small>{row.industry_code}</small>
        </div>
      ),
      sortValue: (row) => row.industry_description,
    },
    {
      key: 'industry_feasibility_percentile_score',
      label: 'Feasibility %ile',
      align: 'right',
      render: (row) => formatPercent(row.industry_feasibility_percentile_score, 1),
      sortValue: (row) => row.industry_feasibility_percentile_score,
    },
    {
      key: 'strategic_gain_percentile_score',
      label: 'Strategic Gain %ile',
      align: 'right',
      render: (row) => formatPercent(row.strategic_gain_percentile_score, 1),
      sortValue: (row) => row.strategic_gain_percentile_score,
    },
    {
      key: 'location_quotient',
      label: 'LQ',
      align: 'right',
      render: (row) => `${formatDecimal(row.location_quotient, 2)}x`,
      sortValue: (row) => row.location_quotient,
    },
    {
      key: 'industry_employment_share',
      label: 'Employment Share',
      align: 'right',
      render: (row) => formatShare(row.industry_employment_share),
      sortValue: (row) => row.industry_employment_share,
    },
    {
      key: 'industry_complexity',
      label: 'Industry Complexity',
      align: 'right',
      render: (row) => formatDecimal(row.industry_complexity, 2),
      sortValue: (row) => row.industry_complexity ?? Number.NEGATIVE_INFINITY,
    },
  ];

  const nameByGeoid = Object.fromEntries(geoMeta.map((record) => [record.geoid, record.name]));

  return (
    <div className="view-shell">
      <section className="hero-panel">
        <div className="hero-panel__copy">
          <div className="hero-panel__eyebrow">Updated public 2026 snapshot</div>
          <h1>{selectedGeo?.name ?? 'Loading geography...'}</h1>
          <p>
            Rank industries for one place using the 2026 public feasibility and strategic gain model, while preserving the older Clean Growth Tool
            reading flow.
          </p>
        </div>
        <div className="hero-panel__cards">
          <StatCard
            detail={`%ile ${formatPercent(selectedGeo?.economic_complexity_percentile_score, 1)}`}
            eyebrow="Regional capability"
            title="Economic Complexity Index"
            value={formatSigned(selectedGeo?.economic_complexity_index, 2)}
          />
          <StatCard
            detail="Distinct six-digit industries"
            eyebrow="Regional capability"
            title="Industrial Diversity"
            value={formatInteger(selectedGeo?.industrial_diversity)}
          />
          <StatCard
            detail={`%ile ${formatPercent(selectedGeo?.strategic_index_percentile, 1)}`}
            eyebrow="Strategic position"
            title="Strategic Index"
            value={formatSigned(selectedGeo?.strategic_index, 2)}
          />
        </div>
      </section>

      <SectionToolbar
        currentView={view}
        onViewChange={(nextView) => setQuery({ view: nextView })}
        subtitle="Use the main panel as either a searchable ranking table or a regional highlight map."
        title="Industry landscape"
      />

      {regionData.loading ? <div className="empty-panel">Loading region data...</div> : null}
      {regionData.error ? <div className="empty-panel">Failed to load region data: {regionData.error}</div> : null}

      {!regionData.loading && !regionData.error ? (
        <>
          {view === 'table' ? (
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Industry ranking table</h3>
                <p>Sorted by the selected metric. Click an industry row to jump into Industry View.</p>
              </div>
              <RankingTable
                columns={tableColumns}
                initialSortKey={metric}
                onRowClick={(row) => onInspectIndustry(row.industry_code)}
                rowKey={(row) => row.industry_code}
                rows={visibleRows}
              />
            </section>
          ) : (
            <GeoMap
              level={level}
              mode="highlight"
              nameByGeoid={nameByGeoid}
              selectedGeoid={selectedGeo?.geoid}
              subtitle="Selected geography highlighted within the national footprint for the active geography level."
              title="Geography highlight"
            />
          )}

          <div className="content-grid">
            <ScatterPanel
              points={sortedByMetric.slice(0, 250).map((row) => ({
                color: row.strategic_gain_percentile_score,
                label: row.industry_description,
                size: row.industry_employment_share,
                x: row.industry_feasibility,
                y: row.industry_complexity ?? 0,
              }))}
              subtitle="Bubble color tracks strategic gain percentile. Bubble size tracks local employment share."
              title="Feasibility vs. Industry Complexity"
              xLabel="Feasibility"
              yLabel="Industry Complexity"
            />
            <ScatterPanel
              points={sortedByMetric.slice(0, 250).map((row) => ({
                color: row.location_quotient,
                label: row.industry_description,
                size: row.industry_employment_share,
                x: row.industry_feasibility_percentile_score,
                y: row.strategic_gain,
              }))}
              subtitle="This surfaces industries with both credible fit and strong strategic upside."
              title="Strategic Gain vs. Feasibility Percentile"
              xLabel="Feasibility Percentile"
              yLabel="Strategic Gain"
            />
          </div>

          <div className="support-grid">
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Top Feasible Industries</h3>
                <p>Modern replacement for legacy workforce panels, anchored in the current public data model.</p>
              </div>
              <ol className="rank-list">
                {topFeasible.map((row) => (
                  <li key={row.industry_code}>
                    <button className="rank-list__button" onClick={() => onInspectIndustry(row.industry_code)} type="button">
                      <span>{row.industry_description}</span>
                      <strong>{formatPercent(row.industry_feasibility_percentile_score, 1)}</strong>
                    </button>
                  </li>
                ))}
              </ol>
            </section>
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Top Strategic Gain Industries</h3>
                <p>These industries offer the biggest public-model strategic upside for the selected geography.</p>
              </div>
              <ol className="rank-list">
                {topStrategic.map((row) => (
                  <li key={row.industry_code}>
                    <button className="rank-list__button" onClick={() => onInspectIndustry(row.industry_code)} type="button">
                      <span>{row.industry_description}</span>
                      <strong>{formatPercent(row.strategic_gain_percentile_score, 1)}</strong>
                    </button>
                  </li>
                ))}
              </ol>
            </section>
          </div>
        </>
      ) : null}
    </div>
  );
}
