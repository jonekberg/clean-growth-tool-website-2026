import type { ContentView } from '../types';

interface SectionToolbarProps {
  currentView: ContentView;
  onViewChange: (view: ContentView) => void;
  title: string;
  subtitle: string;
}

export function SectionToolbar({ currentView, onViewChange, title, subtitle }: SectionToolbarProps) {
  return (
    <div className="section-toolbar">
      <div>
        <div className="section-toolbar__title">{title}</div>
        <div className="section-toolbar__subtitle">{subtitle}</div>
      </div>
      <div className="segmented-control" role="tablist" aria-label={`${title} view toggle`}>
        <button className={currentView === 'table' ? 'is-active' : ''} onClick={() => onViewChange('table')} type="button">
          Table
        </button>
        <button className={currentView === 'map' ? 'is-active' : ''} onClick={() => onViewChange('map')} type="button">
          Map
        </button>
      </div>
    </div>
  );
}
