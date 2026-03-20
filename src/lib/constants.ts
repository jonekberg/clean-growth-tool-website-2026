import type { GeoLevel, MetricOption, QueryState } from '../types';

export const GEO_LEVEL_OPTIONS: Array<{ value: GeoLevel; label: string; shortLabel: string }> = [
  { value: 'county', label: 'County', shortLabel: 'County' },
  { value: 'state', label: 'State', shortLabel: 'State' },
  { value: 'cbsa', label: 'Metropolitan Statistical Area', shortLabel: 'MSA' },
  { value: 'csa', label: 'Combined Statistical Area', shortLabel: 'CSA' },
  { value: 'cz', label: 'Commuting Zone', shortLabel: 'CZ' },
];

export const REGION_METRIC_OPTIONS: MetricOption[] = [
  {
    key: 'industry_feasibility_percentile_score',
    label: 'Feasibility Percentile',
    description: 'Sort industries by how feasible they are for the selected geography relative to peers.',
  },
  {
    key: 'strategic_gain_percentile_score',
    label: 'Strategic Gain Percentile',
    description: 'Sort industries by their strategic upside for improving the region’s economic position.',
  },
  {
    key: 'industry_feasibility',
    label: 'Feasibility Score',
    description: 'Show the raw industry feasibility score from the 2026 public snapshot.',
  },
  {
    key: 'strategic_gain',
    label: 'Strategic Gain',
    description: 'Show the raw strategic gain measure for each industry in the selected geography.',
  },
  {
    key: 'location_quotient',
    label: 'Location Quotient',
    description: 'Rank by current concentration of the industry in the selected geography.',
  },
  {
    key: 'industry_employment_share',
    label: 'Employment Share',
    description: 'Rank industries by share of total employment in the selected geography.',
  },
];

export const INDUSTRY_METRIC_OPTIONS: MetricOption[] = [
  {
    key: 'industry_feasibility_percentile_score',
    label: 'Feasibility Percentile',
    description: 'Color and rank geographies by how feasible the selected industry is in each place.',
  },
  {
    key: 'strategic_gain_percentile_score',
    label: 'Strategic Gain Percentile',
    description: 'Show the strongest upside geographies for the selected industry.',
  },
  {
    key: 'industry_feasibility',
    label: 'Feasibility Score',
    description: 'Use the raw feasibility score as the comparison metric across geographies.',
  },
  {
    key: 'strategic_gain',
    label: 'Strategic Gain',
    description: 'Compare raw strategic gain for the selected industry across geographies.',
  },
  {
    key: 'location_quotient',
    label: 'Location Quotient',
    description: 'Rank places by current specialization in the selected industry.',
  },
  {
    key: 'industry_employment_share',
    label: 'Employment Share',
    description: 'Rank places by the industry’s local share of total employment.',
  },
];

export const DEFAULT_QUERY_STATE: QueryState = {
  tab: 'region',
  level: 'cbsa',
  geoid: '',
  industry: '',
  view: 'table',
  metric: 'industry_feasibility_percentile_score',
};

export const GEO_META_FILE_BY_LEVEL: Record<GeoLevel, string> = {
  county: 'meta/county_geography_specific.csv',
  state: 'meta/state_geography_specific.csv',
  cbsa: 'meta/cbsa_geography_specific.csv',
  csa: 'meta/csa_geography_specific.csv',
  cz: 'meta/cz_geography_specific.csv',
};

export const INDUSTRY_META_FILE_BY_LEVEL: Record<GeoLevel, string> = {
  county: 'meta/county_industry_specific.csv',
  state: 'meta/state_industry_specific.csv',
  cbsa: 'meta/cbsa_industry_specific.csv',
  csa: 'meta/csa_industry_specific.csv',
  cz: 'meta/cz_industry_specific.csv',
};

export const GEO_LEVEL_COPY: Record<GeoLevel, { title: string; sourceFolder: string }> = {
  county: { title: 'County', sourceFolder: 'county' },
  state: { title: 'State', sourceFolder: 'state' },
  cbsa: { title: 'Metropolitan Statistical Area', sourceFolder: 'cbsa' },
  csa: { title: 'Combined Statistical Area', sourceFolder: 'csa' },
  cz: { title: 'Commuting Zone', sourceFolder: 'cz' },
};

export const MAP_NEUTRAL_FILL = '#dfe7ec';
export const MAP_ACCENT_FILL = '#46cfd1';
