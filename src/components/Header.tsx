import type { AppTab } from '../types';

interface HeaderProps {
  activeTab: AppTab;
  onTabChange: (tab: AppTab) => void;
}

const tabs: Array<{ key: AppTab; label: string }> = [
  { key: 'region', label: 'Region View' },
  { key: 'industry', label: 'Industry View' },
  { key: 'about', label: 'About' },
];

export function Header({ activeTab, onTabChange }: HeaderProps) {
  return (
    <header className="topbar">
      <a className="brand-lockup" href={import.meta.env.BASE_URL}>
        <img alt="RMI" className="brand-logo" src={`${import.meta.env.BASE_URL}data/branding/rmi_logo_white.svg`} />
        <div className="brand-copy">
          <span className="brand-title">Clean Growth Tool Website 2026</span>
          <span className="brand-subtitle">Classic interface, public 2026 data snapshot</span>
        </div>
      </a>
      <nav className="tab-nav" aria-label="Primary views">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            className={`tab-nav__button ${activeTab === tab.key ? 'is-active' : ''}`}
            onClick={() => onTabChange(tab.key)}
            type="button"
          >
            {tab.label}
          </button>
        ))}
      </nav>
    </header>
  );
}
