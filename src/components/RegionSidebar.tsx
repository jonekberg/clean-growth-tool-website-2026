import { useDeferredValue } from 'react';
import { GEO_LEVEL_OPTIONS, REGION_METRIC_OPTIONS } from '../lib/constants';
import type { GeoLevel, GeoMetaRecord } from '../types';

interface RegionSidebarProps {
  geographies: GeoMetaRecord[];
  geographySearch: string;
  industryFilter: string;
  level: GeoLevel;
  loading: boolean;
  metric: string;
  onGeographyChange: (geoid: string) => void;
  onGeographySearchChange: (value: string) => void;
  onIndustryFilterChange: (value: string) => void;
  onLevelChange: (level: GeoLevel) => void;
  onMetricChange: (metric: string) => void;
  selectedGeoid: string;
}

export function RegionSidebar({
  geographies,
  geographySearch,
  industryFilter,
  level,
  loading,
  metric,
  onGeographyChange,
  onGeographySearchChange,
  onIndustryFilterChange,
  onLevelChange,
  onMetricChange,
  selectedGeoid,
}: RegionSidebarProps) {
  const deferredSearch = useDeferredValue(geographySearch.trim().toLowerCase());

  const visibleGeographies = deferredSearch
    ? geographies.filter((record) => record.name.toLowerCase().includes(deferredSearch) || record.geoid.includes(deferredSearch))
    : geographies;

  return (
    <div className="sidebar-panel">
      <div className="sidebar-kicker">Region View</div>
      <h2>Evaluate a place</h2>
      <p className="sidebar-copy">
        Use the updated public 2026 dataset to rank industries for a geography with the older two-pane Clean Growth Tool interaction model.
      </p>

      <label className="field-label" htmlFor="region-level">
        Geography level
      </label>
      <select id="region-level" value={level} onChange={(event) => onLevelChange(event.target.value as GeoLevel)}>
        {GEO_LEVEL_OPTIONS.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>

      <label className="field-label" htmlFor="region-search">
        Find a geography
      </label>
      <input
        id="region-search"
        onChange={(event) => onGeographySearchChange(event.target.value)}
        placeholder="Search name or geoid"
        type="text"
        value={geographySearch}
      />

      <label className="field-label" htmlFor="region-geoid">
        Geography
      </label>
      <select id="region-geoid" onChange={(event) => onGeographyChange(event.target.value)} value={selectedGeoid}>
        {visibleGeographies.map((record) => (
          <option key={record.geoid} value={record.geoid}>
            {record.name}
          </option>
        ))}
      </select>

      <label className="field-label" htmlFor="region-metric">
        Ranking metric
      </label>
      <select id="region-metric" onChange={(event) => onMetricChange(event.target.value)} value={metric}>
        {REGION_METRIC_OPTIONS.map((option) => (
          <option key={option.key} value={option.key}>
            {option.label}
          </option>
        ))}
      </select>

      <p className="sidebar-caption">{REGION_METRIC_OPTIONS.find((option) => option.key === metric)?.description}</p>

      <label className="field-label" htmlFor="industry-filter">
        Industry filter
      </label>
      <input
        id="industry-filter"
        onChange={(event) => onIndustryFilterChange(event.target.value)}
        placeholder="Filter industry table"
        type="text"
        value={industryFilter}
      />

      <div className="sidebar-status">
        <span>{loading ? 'Loading public snapshot...' : `${geographies.length.toLocaleString()} geographies ready`}</span>
      </div>
    </div>
  );
}
