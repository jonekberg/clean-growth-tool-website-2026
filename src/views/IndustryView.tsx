import { useDeferredValue } from 'react';
import { GeoMap } from '../components/GeoMap';
import { RankingTable, type TableColumn } from '../components/RankingTable';
import { ScatterPanel } from '../components/ScatterPanel';
import { SectionToolbar } from '../components/SectionToolbar';
import { StatCard } from '../components/StatCard';
import { useAsyncResource } from '../hooks/useAsyncResource';
import { loadIndustryRegions } from '../lib/data';
import { formatDecimal, formatInteger, formatPercent, formatShare, formatSigned } from '../lib/format';
import type {
  ContentView,
  EnrichedIndustryRegionRecord,
  GeoLevel,
  GeoMetaRecord,
  IndustryMetaRecord,
  QueryState,
} from '../types';

interface IndustryViewProps {
  geoFilter: string;
  geoMeta: GeoMetaRecord[];
  level: GeoLevel;
  metric: string;
  onInspectGeography: (geoid: string) => void;
  selectedIndustry: IndustryMetaRecord | null;
  setQuery: (patch: Partial<QueryState>, replace?: boolean) => void;
  view: ContentView;
}

export function IndustryView({ geoFilter, geoMeta, level, metric, onInspectGeography, selectedIndustry, setQuery, view }: IndustryViewProps) {
  const industryData = useAsyncResource(
    () => (selectedIndustry ? loadIndustryRegions(level, selectedIndustry.industry_code) : Promise.resolve([])),
    [level, selectedIndustry?.industry_code],
  );

  const deferredGeoFilter = useDeferredValue(geoFilter.trim().toLowerCase());
  const geoMetaById = new Map(geoMeta.map((record) => [record.geoid, record]));

  const rows: EnrichedIndustryRegionRecord[] =
    industryData.data?.map((row) => {
      const geography = geoMetaById.get(row.geoid);
      return {
        ...row,
        geo_name: geography?.name ?? row.geoid,
        industrial_diversity: geography?.industrial_diversity ?? null,
        economic_complexity_index: geography?.economic_complexity_index ?? null,
        strategic_index: geography?.strategic_index ?? null,
      };
    }) ?? [];

  const visibleRows = deferredGeoFilter
    ? rows.filter((row) => row.geo_name.toLowerCase().includes(deferredGeoFilter) || row.geoid.toLowerCase().includes(deferredGeoFilter))
    : rows;

  const sortedByMetric = [...visibleRows].sort((left, right) => Number(right[metric as keyof EnrichedIndustryRegionRecord]) - Number(left[metric as keyof EnrichedIndustryRegionRecord]));
  const topFeasible = [...visibleRows].sort((left, right) => right.industry_feasibility_percentile_score - left.industry_feasibility_percentile_score).slice(0, 8);
  const topSpecialized = [...visibleRows].sort((left, right) => right.location_quotient - left.location_quotient).slice(0, 8);

  const tableColumns: TableColumn<EnrichedIndustryRegionRecord>[] = [
    {
      key: 'geo_name',
      label: 'Geography',
      render: (row) => (
        <div className="table-primary">
          <span>{row.geo_name}</span>
          <small>{row.geoid}</small>
        </div>
      ),
      sortValue: (row) => row.geo_name,
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
      key: 'economic_complexity_index',
      label: 'ECI',
      align: 'right',
      render: (row) => formatSigned(row.economic_complexity_index, 2),
      sortValue: (row) => row.economic_complexity_index ?? Number.NEGATIVE_INFINITY,
    },
  ];

  const valueByGeoid = Object.fromEntries(visibleRows.map((row) => [row.geoid, Number(row[metric as keyof EnrichedIndustryRegionRecord])]));
  const nameByGeoid = Object.fromEntries(geoMeta.map((record) => [record.geoid, record.name]));

  return (
    <div className="view-shell">
      <section className="hero-panel">
        <div className="hero-panel__copy">
          <div className="hero-panel__eyebrow">Latest public industry landscape</div>
          <h1>{selectedIndustry?.industry_description ?? 'Loading industry...'}</h1>
          <p>See where one industry is currently specialized, where it looks feasible, and where the strategic upside is strongest.</p>
        </div>
        <div className="hero-panel__cards">
          <StatCard
            detail={`%ile ${formatPercent(selectedIndustry?.industry_complexity_percentile, 1)}`}
            eyebrow="Industry profile"
            title="Industry Complexity"
            value={formatSigned(selectedIndustry?.industry_complexity, 2)}
          />
          <StatCard
            detail="Public 2026 national share"
            eyebrow="Industry profile"
            title="National Employment Share"
            value={formatShare(selectedIndustry?.industry_employment_share_nation)}
          />
          <StatCard
            detail="Geographies where the industry appears"
            eyebrow="Industry profile"
            title="Ubiquity"
            value={formatInteger(selectedIndustry?.industry_ubiquity)}
          />
        </div>
      </section>

      <SectionToolbar
        currentView={view}
        onViewChange={(nextView) => setQuery({ view: nextView })}
        subtitle="Use the main panel as either a ranked geography table or a national choropleth."
        title="Geography landscape"
      />

      {industryData.loading ? <div className="empty-panel">Loading industry geography data...</div> : null}
      {industryData.error ? <div className="empty-panel">Failed to load industry geography data: {industryData.error}</div> : null}

      {!industryData.loading && !industryData.error ? (
        <>
          {view === 'table' ? (
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Geography ranking table</h3>
                <p>Click a geography row to jump back into Region View for that place.</p>
              </div>
              <RankingTable
                columns={tableColumns}
                initialSortKey={metric}
                onRowClick={(row) => onInspectGeography(row.geoid)}
                rowKey={(row) => row.geoid}
                rows={visibleRows}
              />
            </section>
          ) : (
            <GeoMap
              level={level}
              metricLabel={metric}
              mode="choropleth"
              nameByGeoid={nameByGeoid}
              onSelectGeoid={onInspectGeography}
              subtitle="Every geography is colored by the active ranking metric for the selected industry."
              title="National geography map"
              valueByGeoid={valueByGeoid}
            />
          )}

          <div className="content-grid">
            <ScatterPanel
              points={sortedByMetric.slice(0, 250).map((row) => ({
                color: row.location_quotient,
                label: row.geo_name,
                size: row.industry_employment_share,
                x: row.industry_feasibility,
                y: row.economic_complexity_index ?? 0,
              }))}
              subtitle="Geographies in the upper-right combine strong local capability with high industry fit."
              title="Feasibility vs. Economic Complexity"
              xLabel="Feasibility"
              yLabel="Economic Complexity Index"
            />
            <ScatterPanel
              points={sortedByMetric.slice(0, 250).map((row) => ({
                color: row.strategic_gain_percentile_score,
                label: row.geo_name,
                size: row.industry_employment_share,
                x: row.industry_feasibility_percentile_score,
                y: row.strategic_gain,
              }))}
              subtitle="This shows where the selected industry has both near-term fit and longer-term strategic upside."
              title="Strategic Gain vs. Feasibility Percentile"
              xLabel="Feasibility Percentile"
              yLabel="Strategic Gain"
            />
          </div>

          <div className="support-grid">
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Top Feasible Geographies</h3>
                <p>Places where the public 2026 model shows the strongest overall fit for this industry.</p>
              </div>
              <ol className="rank-list">
                {topFeasible.map((row) => (
                  <li key={row.geoid}>
                    <button className="rank-list__button" onClick={() => onInspectGeography(row.geoid)} type="button">
                      <span>{row.geo_name}</span>
                      <strong>{formatPercent(row.industry_feasibility_percentile_score, 1)}</strong>
                    </button>
                  </li>
                ))}
              </ol>
            </section>
            <section className="panel-card">
              <div className="panel-card__header">
                <h3>Most Specialized Geographies</h3>
                <p>Places where this industry is already unusually concentrated today.</p>
              </div>
              <ol className="rank-list">
                {topSpecialized.map((row) => (
                  <li key={row.geoid}>
                    <button className="rank-list__button" onClick={() => onInspectGeography(row.geoid)} type="button">
                      <span>{row.geo_name}</span>
                      <strong>{formatDecimal(row.location_quotient, 2)}x</strong>
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
