import { useEffect, useEffectEvent, useState } from 'react';

export interface AsyncResourceState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

export function useAsyncResource<T>(loader: () => Promise<T>, dependencies: unknown[]): AsyncResourceState<T> {
  const [state, setState] = useState<AsyncResourceState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  const runLoader = useEffectEvent(loader);

  useEffect(() => {
    let active = true;

    setState((previous) => ({
      data: previous.data,
      loading: true,
      error: null,
    }));

    runLoader()
      .then((data) => {
        if (!active) {
          return;
        }

        setState({
          data,
          loading: false,
          error: null,
        });
      })
      .catch((error: unknown) => {
        if (!active) {
          return;
        }

        setState({
          data: null,
          loading: false,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      });

    return () => {
      active = false;
    };
  }, dependencies);

  return state;
}
