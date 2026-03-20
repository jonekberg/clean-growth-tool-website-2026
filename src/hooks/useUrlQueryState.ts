import { startTransition, useEffect, useEffectEvent, useState } from 'react';
import { DEFAULT_QUERY_STATE } from '../lib/constants';
import type { QueryState } from '../types';

function readQueryState(): QueryState {
  const params = new URLSearchParams(window.location.search);

  return {
    tab: (params.get('tab') as QueryState['tab']) || DEFAULT_QUERY_STATE.tab,
    level: (params.get('level') as QueryState['level']) || DEFAULT_QUERY_STATE.level,
    geoid: params.get('geoid') || DEFAULT_QUERY_STATE.geoid,
    industry: params.get('industry') || DEFAULT_QUERY_STATE.industry,
    view: (params.get('view') as QueryState['view']) || DEFAULT_QUERY_STATE.view,
    metric: params.get('metric') || DEFAULT_QUERY_STATE.metric,
  };
}

function serializeQueryState(state: QueryState) {
  const params = new URLSearchParams();

  if (state.tab !== DEFAULT_QUERY_STATE.tab) {
    params.set('tab', state.tab);
  } else {
    params.set('tab', state.tab);
  }

  if (state.level !== DEFAULT_QUERY_STATE.level) {
    params.set('level', state.level);
  } else {
    params.set('level', state.level);
  }

  if (state.geoid) {
    params.set('geoid', state.geoid);
  }

  if (state.industry) {
    params.set('industry', state.industry);
  }

  if (state.view) {
    params.set('view', state.view);
  }

  if (state.metric) {
    params.set('metric', state.metric);
  }

  return params;
}

export function useUrlQueryState() {
  const [queryState, setQueryState] = useState<QueryState>(() => readQueryState());

  const syncFromLocation = useEffectEvent(() => {
    setQueryState(readQueryState());
  });

  useEffect(() => {
    const handlePopState = () => {
      syncFromLocation();
    };

    window.addEventListener('popstate', handlePopState);

    return () => {
      window.removeEventListener('popstate', handlePopState);
    };
  }, [syncFromLocation]);

  const updateQueryState = useEffectEvent((patch: Partial<QueryState>, replace = false) => {
    const nextState: QueryState = {
      ...queryState,
      ...patch,
    };

    const params = serializeQueryState(nextState);
    const nextUrl = `${window.location.pathname}?${params.toString()}`;

    startTransition(() => {
      if (replace) {
        window.history.replaceState({}, '', nextUrl);
      } else {
        window.history.pushState({}, '', nextUrl);
      }

      setQueryState(readQueryState());
    });
  });

  return [queryState, (patch: Partial<QueryState>, replace = false) => updateQueryState(patch, replace)] as const;
}
