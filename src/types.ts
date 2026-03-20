export type GeoLevel = 'county' | 'state' | 'cbsa' | 'csa' | 'cz';
export type AppTab = 'region' | 'industry' | 'about';
export type ContentView = 'map' | 'table';

export interface QueryState {
  tab: AppTab;
  level: GeoLevel;
  geoid: string;
  industry: string;
  view: ContentView;
  metric: string;
}

export interface GeoMetaRecord {
  geo_aggregation_level: number;
  geoid: string;
  name: string;
  industrial_diversity: number;
  economic_complexity_index: number;
  economic_complexity_percentile_score: number;
  strategic_index: number;
  strategic_index_percentile: number;
}

export interface IndustryMetaRecord {
  geo_aggregation_level: number;
  industry_code: string;
  industry_description: string;
  industry_ubiquity: number;
  industry_employment_share_nation: number;
  industry_complexity: number;
  industry_complexity_percentile: number;
}

export interface RegionIndustryRecord {
  geoid: string;
  industry_code: string;
  industry_employment_share: number;
  location_quotient: number;
  industry_present: boolean | number;
  industry_comparative_advantage: boolean | number;
  industry_feasibility: number;
  industry_feasibility_percentile_score: number;
  strategic_gain_possible: boolean | number;
  strategic_gain: number;
  strategic_gain_percentile_score: number;
}

export interface IndustryRegionRecord {
  geoid: string;
  industry_code: string;
  industry_employment_share: number;
  location_quotient: number;
  industry_present: boolean | number;
  industry_comparative_advantage: boolean | number;
  industry_feasibility: number;
  industry_feasibility_percentile_score: number;
  strategic_gain_possible: boolean | number;
  strategic_gain: number;
  strategic_gain_percentile_score: number;
}

export interface CountyCrosswalk {
  county_geoid: string;
  county_name: string;
  state_fips: string;
  state_name: string;
  state_abbreviation: string;
  cbsa_geoid: string;
  cbsa_name: string;
  county_in_cbsa: boolean;
  csa_geoid: string;
  csa_name: string;
  county_in_csa: boolean;
  commuting_zone_geoid: string;
  commuting_zone_name: string;
}

export interface CrosswalkIndex {
  countyToParent: Map<string, CountyCrosswalk>;
}

export interface MetricOption {
  key: string;
  label: string;
  description: string;
}

export interface EnrichedRegionIndustryRecord extends RegionIndustryRecord {
  industry_description: string;
  industry_complexity: number | null;
  industry_complexity_percentile: number | null;
}

export interface EnrichedIndustryRegionRecord extends IndustryRegionRecord {
  geo_name: string;
  industrial_diversity: number | null;
  economic_complexity_index: number | null;
  strategic_index: number | null;
}

export function normalizeGeoid(level: GeoLevel, geoid: string) {
  const raw = String(geoid ?? '').trim();
  if (!raw) {
    return '';
  }

  if (level === 'county') {
    return raw.padStart(5, '0');
  }

  if (level === 'state') {
    return raw.padStart(2, '0');
  }

  if (level === 'cbsa') {
    return raw.padStart(5, '0');
  }

  return raw;
}
