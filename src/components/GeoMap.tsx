import { useEffect, useRef } from 'react';
import * as d3 from 'd3';
import type { Feature as GeoFeature, FeatureCollection as GeoFeatureCollection, MultiLineString } from 'geojson';
import { feature, mesh } from 'topojson-client';
import type { GeometryCollection, Topology } from 'topojson-specification';
import { MAP_ACCENT_FILL, MAP_NEUTRAL_FILL } from '../lib/constants';
import { loadCountyTopology, loadCrosswalkIndex, loadStatesTopology } from '../lib/data';
import { formatMetricValue } from '../lib/format';
import type { CrosswalkIndex, GeoLevel } from '../types';
import { normalizeGeoid } from '../types';

interface GeoMapProps {
  level: GeoLevel;
  mode: 'highlight' | 'choropleth';
  selectedGeoid?: string;
  subtitle?: string;
  title: string;
  valueByGeoid?: Record<string, number>;
  metricLabel?: string;
  nameByGeoid?: Record<string, string>;
  onSelectGeoid?: (geoid: string) => void;
}

function getCountyRegion(level: GeoLevel, countyFips: string, crosswalk: CrosswalkIndex) {
  const match = crosswalk.countyToParent.get(countyFips);
  if (!match) {
    return null;
  }

  if (level === 'county') {
    return {
      geoid: countyFips,
      name: `${match.county_name}, ${match.state_abbreviation}`,
    };
  }

  if (level === 'state') {
    return {
      geoid: match.state_fips,
      name: match.state_name,
    };
  }

  if (level === 'cbsa' && match.county_in_cbsa && match.cbsa_geoid) {
    return {
      geoid: normalizeGeoid('cbsa', match.cbsa_geoid),
      name: match.cbsa_name,
    };
  }

  if (level === 'csa' && match.county_in_csa && match.csa_geoid) {
    return {
      geoid: normalizeGeoid('csa', match.csa_geoid),
      name: match.csa_name,
    };
  }

  if (level === 'cz' && match.commuting_zone_geoid) {
    return {
      geoid: normalizeGeoid('cz', match.commuting_zone_geoid),
      name: match.commuting_zone_name,
    };
  }

  return null;
}

export function GeoMap({ level, metricLabel, mode, nameByGeoid = {}, onSelectGeoid, selectedGeoid, subtitle, title, valueByGeoid = {} }: GeoMapProps) {
  const mountRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    let canceled = false;

    Promise.all([loadStatesTopology(), loadCountyTopology(), loadCrosswalkIndex()])
      .then(([statesTopo, countyTopo, crosswalkIndex]) => {
        if (canceled || !mountRef.current) {
          return;
        }

        const host = mountRef.current;
        host.innerHTML = '';

        const width = Math.max(host.clientWidth, 680);
        const height = Math.max(420, Math.round(width * 0.58));
        const svg = d3
          .select(host)
          .append('svg')
          .attr('viewBox', `0 0 ${width} ${height}`)
          .attr('role', 'img')
          .attr('aria-label', title);

        const tooltip = d3
          .select(host)
          .append('div')
          .attr('class', 'map-tooltip')
          .style('opacity', 0);

        const projection = d3.geoAlbersUsa().fitSize([width - 24, height - 24], {
          type: 'FeatureCollection',
          features: (
            feature(
              countyTopo as unknown as Topology,
              (countyTopo as unknown as { objects: Record<string, GeometryCollection> }).objects.counties,
            ) as GeoFeatureCollection
          ).features,
        });
        const path = d3.geoPath(projection);

        const chart = svg.append('g').attr('transform', 'translate(12,12)');

        const allMetricValues = Object.values(valueByGeoid).filter((value) => Number.isFinite(value));
        const colorScale =
          mode === 'choropleth' && allMetricValues.length > 0
            ? d3.scaleSequential(d3.interpolateYlGnBu).domain(d3.extent(allMetricValues) as [number, number])
            : null;

        const stateFeatures = (
          feature(
            statesTopo as unknown as Topology,
            (statesTopo as unknown as { objects: Record<string, GeometryCollection> }).objects.states,
          ) as GeoFeatureCollection
        ).features as GeoFeature[];

        const countyFeatures = (
          feature(
            countyTopo as unknown as Topology,
            (countyTopo as unknown as { objects: Record<string, GeometryCollection> }).objects.counties,
          ) as GeoFeatureCollection
        ).features as GeoFeature[];

        if (level === 'state') {
          chart
            .selectAll('path')
            .data(stateFeatures)
            .join('path')
            .attr('class', 'map-shape')
            .attr('d', (datum: GeoFeature) => path(datum) || '')
            .attr('fill', (datum: GeoFeature) => {
              const geoid = normalizeGeoid('state', String(datum.id));
              if (mode === 'highlight') {
                return geoid === normalizeGeoid('state', selectedGeoid || '') ? MAP_ACCENT_FILL : MAP_NEUTRAL_FILL;
              }

              const value = valueByGeoid[geoid];
              return colorScale && Number.isFinite(value) ? colorScale(value) : MAP_NEUTRAL_FILL;
            })
            .on('mouseenter', (event: MouseEvent, datum: GeoFeature) => {
              const geoid = normalizeGeoid('state', String(datum.id));
              const label = nameByGeoid[geoid] || geoid;
              const value = valueByGeoid[geoid];
              tooltip
                .style('opacity', 1)
                .html(
                  mode === 'choropleth' && metricLabel
                    ? `<strong>${label}</strong><br>${metricLabel}: ${formatMetricValue(metricLabel, value)}`
                    : `<strong>${label}</strong>`,
                );
              d3.select(event.currentTarget as SVGPathElement).attr('stroke-width', 1.8);
            })
            .on('mousemove', (event: MouseEvent) => {
              tooltip.style('left', `${event.offsetX + 18}px`).style('top', `${event.offsetY + 18}px`);
            })
            .on('mouseleave', (event: MouseEvent) => {
              tooltip.style('opacity', 0);
              d3.select(event.currentTarget as SVGPathElement).attr('stroke-width', 0.8);
            })
            .on('click', (_event: MouseEvent, datum: GeoFeature) => {
              const geoid = normalizeGeoid('state', String(datum.id));
              onSelectGeoid?.(geoid);
            });
        } else {
          chart
            .selectAll('path')
            .data(countyFeatures)
            .join('path')
            .attr('class', 'map-shape')
            .attr('d', (datum: GeoFeature) => path(datum) || '')
            .attr('fill', (datum: GeoFeature) => {
              const countyFips = normalizeGeoid('county', String(datum.id));
              const region = getCountyRegion(level, countyFips, crosswalkIndex);
              if (!region) {
                return MAP_NEUTRAL_FILL;
              }

              if (mode === 'highlight') {
                return region.geoid === normalizeGeoid(level, selectedGeoid || '') ? MAP_ACCENT_FILL : MAP_NEUTRAL_FILL;
              }

              const value = valueByGeoid[region.geoid];
              return colorScale && Number.isFinite(value) ? colorScale(value) : MAP_NEUTRAL_FILL;
            })
            .on('mouseenter', (event: MouseEvent, datum: GeoFeature) => {
              const countyFips = normalizeGeoid('county', String(datum.id));
              const region = getCountyRegion(level, countyFips, crosswalkIndex);
              if (!region) {
                return;
              }

              const value = valueByGeoid[region.geoid];
              tooltip
                .style('opacity', 1)
                .html(
                  mode === 'choropleth' && metricLabel
                    ? `<strong>${region.name}</strong><br>${metricLabel}: ${formatMetricValue(metricLabel, value)}`
                    : `<strong>${region.name}</strong>`,
                );
              d3.select(event.currentTarget as SVGPathElement).attr('stroke-width', 1.2);
            })
            .on('mousemove', (event: MouseEvent) => {
              tooltip.style('left', `${event.offsetX + 18}px`).style('top', `${event.offsetY + 18}px`);
            })
            .on('mouseleave', (event: MouseEvent) => {
              tooltip.style('opacity', 0);
              d3.select(event.currentTarget as SVGPathElement).attr('stroke-width', 0.22);
            })
            .on('click', (_event: MouseEvent, datum: GeoFeature) => {
              const countyFips = normalizeGeoid('county', String(datum.id));
              const region = getCountyRegion(level, countyFips, crosswalkIndex);
              if (region) {
                onSelectGeoid?.(region.geoid);
              }
            });

          const boundary = mesh(
            countyTopo as unknown as Topology,
            (countyTopo as unknown as { objects: Record<string, GeometryCollection> }).objects.counties,
            (left, right) => String(left.id).slice(0, 2) !== String(right.id).slice(0, 2),
          );

          chart
            .append('path')
            .attr('class', 'map-boundary')
            .attr('d', path(boundary as unknown as MultiLineString) || '')
            .attr('fill', 'none')
            .attr('stroke', 'rgba(7, 33, 56, 0.22)')
            .attr('stroke-width', 0.7);
        }
      })
      .catch((error: unknown) => {
        if (canceled || !mountRef.current) {
          return;
        }

        mountRef.current.innerHTML = `<div class="empty-panel">Map failed to load: ${
          error instanceof Error ? error.message : 'Unknown error'
        }</div>`;
      });

    return () => {
      canceled = true;
    };
  }, [level, metricLabel, mode, nameByGeoid, onSelectGeoid, selectedGeoid, title, valueByGeoid]);

  return (
    <section className="panel-card map-panel">
      <div className="panel-card__header">
        <h3>{title}</h3>
        {subtitle ? <p>{subtitle}</p> : null}
      </div>
      <div className="map-panel__canvas" ref={mountRef} />
    </section>
  );
}
