export function AboutView() {
  return (
    <div className="view-shell about-view">
      <section className="hero-panel hero-panel--about">
        <div className="hero-panel__copy">
          <div className="hero-panel__eyebrow">Methodology and design</div>
          <h1>About the 2026 Website</h1>
          <p>
            This project rebuilds the Clean Growth Tool as a static React site that keeps the older two-pane browsing experience while swapping in
            the latest public 2026 data architecture published by RMI.
          </p>
        </div>
      </section>

      <div className="support-grid support-grid--wide">
        <section className="panel-card prose-card">
          <div className="panel-card__header">
            <h3>What changed</h3>
          </div>
          <p>
            The older public Shiny app was centered on a classic left-rail browsing flow, with dedicated Region and Industry views and a strong
            emphasis on ranked lists, cards, and simple comparisons. The newer public RMI data release moved to a static CSV-based model with
            refreshed feasibility and strategic gain metrics, plus broader geography support.
          </p>
          <p>
            This site deliberately combines those two strengths: the older reading flow and the newer public data model. It is designed to be
            stable, source-controlled, and easy to deploy from GitHub Pages.
          </p>
        </section>

        <section className="panel-card prose-card">
          <div className="panel-card__header">
            <h3>What data powers this site</h3>
          </div>
          <p>
            All runtime data is loaded from a vendored snapshot of the public <code>bsf-rmi/RMI_Clean_Growth_Tool</code> repository. The app reads
            gzipped CSV exports from <code>by_geography</code> and <code>by_industry</code>, plus supporting metadata and map topology files.
          </p>
          <p>
            That means the site does not depend on Datawrapper, private APIs, or a server-side R runtime. The tradeoff is that legacy workforce and
            occupation panels from the older Shiny app are intentionally replaced with data views that are fully supported by the public 2026
            snapshot.
          </p>
        </section>

        <section className="panel-card prose-card">
          <div className="panel-card__header">
            <h3>How to read the metrics</h3>
          </div>
          <p>
            <strong>Economic Complexity Index</strong> describes the sophistication of a geography’s productive capabilities. <strong>Industrial
            Diversity</strong> counts how many distinct industries are active locally. <strong>Strategic Index</strong> summarizes the potential
            improvement available from feasible industry development.
          </p>
          <p>
            At the industry row level, <strong>Feasibility</strong> captures how compatible an industry appears to be with the current capability
            mix of a geography. <strong>Strategic Gain</strong> reflects the upside from developing that industry further. <strong>Location
            Quotient</strong> shows current specialization relative to the national baseline.
          </p>
        </section>
      </div>
    </div>
  );
}
