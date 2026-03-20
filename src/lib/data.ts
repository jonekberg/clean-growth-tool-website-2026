import Papa from 'papaparse';
import pako from 'pako';
import type { Topology } from 'topojson-specification';
import { GEO_LEVEL_COPY, GEO_META_FILE_BY_LEVEL, INDUSTRY_META_FILE_BY_LEVEL } from './constants';
import type {
  CountyCrosswalk,
  CrosswalkIndex,
  GeoLevel,
  GeoMetaRecord,
  IndustryMetaRecord,
  IndustryRegionRecord,
  RegionIndustryRecord,
} from '../types';
import { normalizeGeoid } from '../types';

const csvCache = new Map<string, Promise<Record<string, unknown>[]>>();
const jsonCache = new Map<string, Promise<unknown>>();
const crosswalkCache = new Map<string, Promise<CrosswalkIndex>>();

function dataPath(path: string) {
  return `${import.meta.env.BASE_URL}data/${path}`;
}

function parseCsvText(text: string) {
  const parsed = Papa.parse<Record<string, unknown>>(text.trim(), {
    dynamicTyping: true,
    header: true,
    skipEmptyLines: true,
  });

  if (parsed.errors.length > 0) {
    throw new Error(parsed.errors[0]?.message || 'Failed to parse CSV');
  }

  return parsed.data;
}

async function fetchCsv(path: string) {
  if (!csvCache.has(path)) {
    csvCache.set(
      path,
      fetch(dataPath(path))
        .then((response) => {
          if (!response.ok) {
            throw new Error(`Failed to fetch ${path}`);
          }

          return response.text();
        })
        .then((text) => parseCsvText(text)),
    );
  }

  return csvCache.get(path)!;
}

async function fetchCsvGz(path: string) {
  if (!csvCache.has(path)) {
    csvCache.set(
      path,
      fetch(dataPath(path))
        .then((response) => {
          if (!response.ok) {
            throw new Error(`Failed to fetch ${path}`);
          }

          return response.arrayBuffer();
        })
        .then((buffer) => {
          const bytes = new Uint8Array(buffer);
          const text =
            bytes[0] === 0x1f && bytes[1] === 0x8b
              ? (pako.ungzip(bytes, { to: 'string' }) as string)
              : new TextDecoder('utf-8').decode(bytes);

          return parseCsvText(text);
        }),
    );
  }

  return csvCache.get(path)!;
}

async function fetchJson<T>(path: string) {
  if (!jsonCache.has(path)) {
    jsonCache.set(
      path,
      fetch(dataPath(path)).then((response) => {
        if (!response.ok) {
          throw new Error(`Failed to fetch ${path}`);
        }

        return response.json();
      }),
    );
  }

  return (await jsonCache.get(path)!) as T;
}

function toBoolean(value: unknown) {
  if (value === true || value === 1) {
    return true;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes';
  }

  return false;
}

export async function loadGeoMeta(level: GeoLevel): Promise<GeoMetaRecord[]> {
  const rows = await fetchCsv(GEO_META_FILE_BY_LEVEL[level]);

  return rows.map((row) => ({
    geo_aggregation_level: Number(row.geo_aggregation_level),
    geoid: normalizeGeoid(level, String(row.geoid)),
    name: String(row.name),
    industrial_diversity: Number(row.industrial_diversity),
    economic_complexity_index: Number(row.economic_complexity_index),
    economic_complexity_percentile_score: Number(row.economic_complexity_percentile_score),
    strategic_index: Number(row.strategic_index),
    strategic_index_percentile: Number(row.strategic_index_percentile),
  }));
}

export async function loadIndustryMeta(level: GeoLevel): Promise<IndustryMetaRecord[]> {
  const rows = await fetchCsv(INDUSTRY_META_FILE_BY_LEVEL[level]);

  return rows.map((row) => ({
    geo_aggregation_level: Number(row.geo_aggregation_level),
    industry_code: String(row.industry_code),
    industry_description: String(row.industry_description),
    industry_ubiquity: Number(row.industry_ubiquity),
    industry_employment_share_nation: Number(row.industry_employment_share_nation),
    industry_complexity: Number(row.industry_complexity),
    industry_complexity_percentile: Number(row.industry_complexity_percentile),
  }));
}

export async function loadRegionIndustries(level: GeoLevel, geoid: string): Promise<RegionIndustryRecord[]> {
  const file = `by_geography/${GEO_LEVEL_COPY[level].sourceFolder}/${normalizeGeoid(level, geoid)}.csv.gz`;
  const rows = await fetchCsvGz(file);

  return rows.map((row) => ({
    geoid: normalizeGeoid(level, String(row.geoid)),
    industry_code: String(row.industry_code),
    industry_employment_share: Number(row.industry_employment_share),
    location_quotient: Number(row.location_quotient),
    industry_present: row.industry_present as boolean | number,
    industry_comparative_advantage: row.industry_comparative_advantage as boolean | number,
    industry_feasibility: Number(row.industry_feasibility),
    industry_feasibility_percentile_score: Number(row.industry_feasibility_percentile_score),
    strategic_gain_possible: row.strategic_gain_possible as boolean | number,
    strategic_gain: Number(row.strategic_gain),
    strategic_gain_percentile_score: Number(row.strategic_gain_percentile_score),
  }));
}

export async function loadIndustryRegions(level: GeoLevel, industryCode: string): Promise<IndustryRegionRecord[]> {
  const file = `by_industry/${GEO_LEVEL_COPY[level].sourceFolder}/${industryCode}.csv.gz`;
  const rows = await fetchCsvGz(file);

  return rows.map((row) => ({
    geoid: normalizeGeoid(level, String(row.geoid)),
    industry_code: String(row.industry_code),
    industry_employment_share: Number(row.industry_employment_share),
    location_quotient: Number(row.location_quotient),
    industry_present: row.industry_present as boolean | number,
    industry_comparative_advantage: row.industry_comparative_advantage as boolean | number,
    industry_feasibility: Number(row.industry_feasibility),
    industry_feasibility_percentile_score: Number(row.industry_feasibility_percentile_score),
    strategic_gain_possible: row.strategic_gain_possible as boolean | number,
    strategic_gain: Number(row.strategic_gain),
    strategic_gain_percentile_score: Number(row.strategic_gain_percentile_score),
  }));
}

export async function loadCrosswalkIndex(): Promise<CrosswalkIndex> {
  if (!crosswalkCache.has('crosswalk')) {
    crosswalkCache.set(
      'crosswalk',
      fetchCsv('meta/crosswalk.csv').then((rows) => {
        const countyToParent = new Map<string, CountyCrosswalk>();

        rows.forEach((row) => {
          const countyGeoid = normalizeGeoid('county', String(row.county_geoid));
          countyToParent.set(countyGeoid, {
            county_geoid: countyGeoid,
            county_name: String(row.county_name || countyGeoid),
            state_fips: normalizeGeoid('state', String(row.state_fips)),
            state_name: String(row.state_name || ''),
            state_abbreviation: String(row.state_abbreviation || ''),
            cbsa_geoid: row.cbsa_geoid ? normalizeGeoid('cbsa', String(row.cbsa_geoid)) : '',
            cbsa_name: String(row.cbsa_name || ''),
            county_in_cbsa: toBoolean(row.county_in_cbsa),
            csa_geoid: row.csa_geoid ? normalizeGeoid('csa', String(row.csa_geoid)) : '',
            csa_name: String(row.csa_name || ''),
            county_in_csa: toBoolean(row.county_in_csa),
            commuting_zone_geoid: row.commuting_zone_geoid ? normalizeGeoid('cz', String(row.commuting_zone_geoid)) : '',
            commuting_zone_name: String(row.commuting_zone_name || ''),
          });
        });

        return { countyToParent };
      }),
    );
  }

  return crosswalkCache.get('crosswalk')!;
}

export async function loadStatesTopology(): Promise<Topology> {
  return fetchJson<Topology>('topology/states-10m.json');
}

export async function loadCountyTopology(): Promise<Topology> {
  return fetchJson<Topology>('topology/us-counties-2023-topo.json');
}
