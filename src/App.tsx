import { useEffect, useState } from 'react';
import { Header } from './components/Header';
import { IndustrySidebar } from './components/IndustrySidebar';
import { RegionSidebar } from './components/RegionSidebar';
import { AboutView } from './views/AboutView';
import { IndustryView } from './views/IndustryView';
import { RegionView } from './views/RegionView';
import { DEFAULT_QUERY_STATE, GEO_LEVEL_OPTIONS, INDUSTRY_METRIC_OPTIONS, REGION_METRIC_OPTIONS } from './lib/constants';
import { normalizeGeoid, type QueryState, type GeoMetaRecord, type IndustryMetaRecord } from './types';
import { useAsyncResource } from './hooks/useAsyncResource';
import { useUrlQueryState } from './hooks/useUrlQueryState';
import { loadGeoMeta, loadIndustryMeta } from './lib/data';

function isGeoLevel(value: string) {
  return GEO_LEVEL_OPTIONS.some((option) => option.value === value);
}

function isTab(value: string) {
  return value === 'region' || value === 'industry' || value === 'about';
}

function isView(value: string) {
  return value === 'map' || value === 'table';
}

function sortGeoMeta(records: GeoMetaRecord[]) {
  return [...records].sort((left, right) => left.name.localeCompare(right.name));
}

function sortIndustryMeta(records: IndustryMetaRecord[]) {
  return [...records].sort((left, right) => left.industry_description.localeCompare(right.industry_description));
}

export default function App() {
  const [query, setQuery] = useUrlQueryState();
  const [regionSearch, setRegionSearch] = useState('');
  const [regionIndustryFilter, setRegionIndustryFilter] = useState('');
  const [industrySearch, setIndustrySearch] = useState('');
  const [industryGeoFilter, setIndustryGeoFilter] = useState('');

  const level = isGeoLevel(query.level) ? query.level : DEFAULT_QUERY_STATE.level;
  const tab = isTab(query.tab) ? query.tab : DEFAULT_QUERY_STATE.tab;

  const geoMeta = useAsyncResource(() => loadGeoMeta(level), [level]);
  const industryMeta = useAsyncResource(() => loadIndustryMeta(level), [level]);

  const sortedGeographies = geoMeta.data ? sortGeoMeta(geoMeta.data) : [];
  const sortedIndustries = industryMeta.data ? sortIndustryMeta(industryMeta.data) : [];

  useEffect(() => {
    const patch: Partial<QueryState> = {};

    if (!isTab(query.tab)) {
      patch.tab = DEFAULT_QUERY_STATE.tab;
    }

    if (!isGeoLevel(query.level)) {
      patch.level = DEFAULT_QUERY_STATE.level;
    }

    if (!isView(query.view)) {
      patch.view = DEFAULT_QUERY_STATE.view;
    }

    const metricOptions = tab === 'industry' ? INDUSTRY_METRIC_OPTIONS : REGION_METRIC_OPTIONS;
    if (!metricOptions.some((option) => option.key === query.metric)) {
      patch.metric = DEFAULT_QUERY_STATE.metric;
    }

    if (tab === 'region' && sortedGeographies.length > 0) {
      const fallbackGeoid = sortedGeographies[0].geoid;
      const normalized = query.geoid ? normalizeGeoid(level, query.geoid) : '';
      if (!normalized || !sortedGeographies.some((record) => record.geoid === normalized)) {
        patch.geoid = fallbackGeoid;
      }
    }

    if (sortedIndustries.length > 0) {
      const fallbackIndustry = sortedIndustries[0].industry_code;
      if (!query.industry || !sortedIndustries.some((record) => record.industry_code === query.industry)) {
        patch.industry = fallbackIndustry;
      }
    }

    if (Object.keys(patch).length > 0) {
      setQuery(patch, true);
    }
  }, [level, query.geoid, query.industry, query.level, query.metric, query.tab, query.view, setQuery, sortedGeographies, sortedIndustries, tab]);

  const selectedGeo =
    sortedGeographies.find((record) => record.geoid === normalizeGeoid(level, query.geoid || '')) ?? sortedGeographies[0] ?? null;
  const selectedIndustry = sortedIndustries.find((record) => record.industry_code === query.industry) ?? sortedIndustries[0] ?? null;

  const handleTabChange = (nextTab: QueryState['tab']) => {
    const nextMetric =
      nextTab === 'industry'
        ? INDUSTRY_METRIC_OPTIONS.some((option) => option.key === query.metric)
          ? query.metric
          : DEFAULT_QUERY_STATE.metric
        : REGION_METRIC_OPTIONS.some((option) => option.key === query.metric)
          ? query.metric
          : DEFAULT_QUERY_STATE.metric;

    setQuery({ tab: nextTab, metric: nextMetric });
  };

  return (
    <div className="app-root">
      <Header activeTab={tab} onTabChange={handleTabChange} />
      <div className="app-shell">
        <aside className="sidebar-shell">
          {tab === 'region' ? (
            <RegionSidebar
              geographies={sortedGeographies}
              geographySearch={regionSearch}
              industryFilter={regionIndustryFilter}
              level={level}
              loading={geoMeta.loading || industryMeta.loading}
              metric={query.metric}
              onGeographyChange={(geoid) => setQuery({ geoid })}
              onGeographySearchChange={setRegionSearch}
              onIndustryFilterChange={setRegionIndustryFilter}
              onLevelChange={(nextLevel) => setQuery({ level: nextLevel, geoid: '', industry: '' })}
              onMetricChange={(metric) => setQuery({ metric })}
              selectedGeoid={selectedGeo?.geoid ?? ''}
            />
          ) : tab === 'industry' ? (
            <IndustrySidebar
              industries={sortedIndustries}
              industrySearch={industrySearch}
              geographyFilter={industryGeoFilter}
              level={level}
              loading={geoMeta.loading || industryMeta.loading}
              metric={query.metric}
              onGeographyFilterChange={setIndustryGeoFilter}
              onIndustryChange={(industry) => setQuery({ industry })}
              onIndustrySearchChange={setIndustrySearch}
              onLevelChange={(nextLevel) => setQuery({ level: nextLevel, geoid: '', industry: '' })}
              onMetricChange={(metric) => setQuery({ metric })}
              selectedIndustry={selectedIndustry?.industry_code ?? ''}
            />
          ) : (
            <div className="sidebar-panel about-sidebar">
              <div className="sidebar-kicker">Clean Growth Tool Website 2026</div>
              <h2>About This Build</h2>
              <p>
                This site blends the older Clean Growth Tool interaction model with the latest public 2026 data snapshot that RMI has published
                to GitHub.
              </p>
              <p>
                It is static, shareable, and designed for GitHub Pages. No Datawrapper embeds, no backend, and no Shiny runtime are required.
              </p>
            </div>
          )}
        </aside>
        <main className="content-shell">
          {tab === 'region' ? (
            <RegionView
              geoMeta={sortedGeographies}
              industryFilter={regionIndustryFilter}
              industryMeta={sortedIndustries}
              level={level}
              metric={query.metric}
              onInspectIndustry={(industryCode) => setQuery({ tab: 'industry', industry: industryCode })}
              selectedGeo={selectedGeo}
              setQuery={setQuery}
              view={query.view}
            />
          ) : tab === 'industry' ? (
            <IndustryView
              geoFilter={industryGeoFilter}
              geoMeta={sortedGeographies}
              level={level}
              metric={query.metric}
              onInspectGeography={(geoid) => setQuery({ tab: 'region', geoid })}
              selectedIndustry={selectedIndustry}
              setQuery={setQuery}
              view={query.view}
            />
          ) : (
            <AboutView />
          )}
        </main>
      </div>
    </div>
  );
}
