import { useDeferredValue } from 'react';
import { GEO_LEVEL_OPTIONS, INDUSTRY_METRIC_OPTIONS } from '../lib/constants';
import type { GeoLevel, IndustryMetaRecord } from '../types';

interface IndustrySidebarProps {
  industries: IndustryMetaRecord[];
  industrySearch: string;
  geographyFilter: string;
  level: GeoLevel;
  loading: boolean;
  metric: string;
  onGeographyFilterChange: (value: string) => void;
  onIndustryChange: (industry: string) => void;
  onIndustrySearchChange: (value: string) => void;
  onLevelChange: (level: GeoLevel) => void;
  onMetricChange: (metric: string) => void;
  selectedIndustry: string;
}

export function IndustrySidebar({
  industries,
  industrySearch,
  geographyFilter,
  level,
  loading,
  metric,
  onGeographyFilterChange,
  onIndustryChange,
  onIndustrySearchChange,
  onLevelChange,
  onMetricChange,
  selectedIndustry,
}: IndustrySidebarProps) {
  const deferredSearch = useDeferredValue(industrySearch.trim().toLowerCase());

  const visibleIndustries = deferredSearch
    ? industries.filter(
        (record) =>
          record.industry_description.toLowerCase().includes(deferredSearch) || record.industry_code.toLowerCase().includes(deferredSearch),
      )
    : industries;

  return (
    <div className="sidebar-panel">
      <div className="sidebar-kicker">Industry View</div>
      <h2>Evaluate an industry</h2>
      <p className="sidebar-copy">
        Compare the geography landscape for one industry at a time using the latest public feasibility, strategic gain, and specialization metrics.
      </p>

      <label className="field-label" htmlFor="industry-level">
        Geography level
      </label>
      <select id="industry-level" onChange={(event) => onLevelChange(event.target.value as GeoLevel)} value={level}>
        {GEO_LEVEL_OPTIONS.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>

      <label className="field-label" htmlFor="industry-search">
        Find an industry
      </label>
      <input
        id="industry-search"
        onChange={(event) => onIndustrySearchChange(event.target.value)}
        placeholder="Search industry name or code"
        type="text"
        value={industrySearch}
      />

      <label className="field-label" htmlFor="industry-code">
        Industry
      </label>
      <select id="industry-code" onChange={(event) => onIndustryChange(event.target.value)} value={selectedIndustry}>
        {visibleIndustries.map((record) => (
          <option key={record.industry_code} value={record.industry_code}>
            {record.industry_description}
          </option>
        ))}
      </select>

      <label className="field-label" htmlFor="industry-metric">
        Ranking metric
      </label>
      <select id="industry-metric" onChange={(event) => onMetricChange(event.target.value)} value={metric}>
        {INDUSTRY_METRIC_OPTIONS.map((option) => (
          <option key={option.key} value={option.key}>
            {option.label}
          </option>
        ))}
      </select>

      <p className="sidebar-caption">{INDUSTRY_METRIC_OPTIONS.find((option) => option.key === metric)?.description}</p>

      <label className="field-label" htmlFor="geography-filter">
        Geography filter
      </label>
      <input
        id="geography-filter"
        onChange={(event) => onGeographyFilterChange(event.target.value)}
        placeholder="Filter geography table"
        type="text"
        value={geographyFilter}
      />

      <div className="sidebar-status">
        <span>{loading ? 'Loading public snapshot...' : `${industries.length.toLocaleString()} industries ready`}</span>
      </div>
    </div>
  );
}
