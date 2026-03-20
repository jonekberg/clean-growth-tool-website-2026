const compactFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 1,
  notation: 'compact',
});

const integerFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 0,
});

const decimalFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 2,
  minimumFractionDigits: 0,
});

export function formatCompactNumber(value: number | null | undefined) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return compactFormatter.format(value);
}

export function formatInteger(value: number | null | undefined) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return integerFormatter.format(value);
}

export function formatDecimal(value: number | null | undefined, digits = 2) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits > 0 ? 0 : 0,
  }).format(value);
}

export function formatPercent(value: number | null | undefined, digits = 1) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return `${new Intl.NumberFormat('en-US', {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0,
  }).format(value)}%`;
}

export function formatShare(value: number | null | undefined, digits = 2) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return `${new Intl.NumberFormat('en-US', {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0,
  }).format(value * 100)}%`;
}

export function formatSigned(value: number | null | undefined, digits = 2) {
  if (value == null || Number.isNaN(value)) {
    return '—';
  }

  return `${value > 0 ? '+' : ''}${decimalFormatter.format(Number(value.toFixed(digits)))}`;
}

export function formatMetricValue(metric: string, value: number | null | undefined) {
  switch (metric) {
    case 'industry_employment_share':
      return formatShare(value, 2);
    case 'industry_feasibility_percentile_score':
    case 'strategic_gain_percentile_score':
    case 'industry_complexity_percentile':
    case 'economic_complexity_percentile_score':
    case 'strategic_index_percentile':
      return formatPercent(value, 1);
    case 'location_quotient':
      return `${formatDecimal(value, 2)}x`;
    default:
      return formatDecimal(value, 3);
  }
}
