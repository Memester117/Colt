interface Props {
  hasSave: boolean;
  onNew: () => void;
  onContinue: () => void;
}

export function TitleScreen({ hasSave, onNew, onContinue }: Props) {
  return (
    <section className="title-screen">
      <div className="title-screen__sky" aria-hidden="true" />
      <div className="title-screen__ember" aria-hidden="true" />
      <div className="title-screen__content">
        <h1 className="brand">
          Ash<em>fall</em>
        </h1>
        <p className="title-screen__lede">
          A short road through the Marches. Every path ends the same: Capella Emerada Lugunica
          notices you, shrinks you, and finishes the story underfoot.
        </p>
        <div className="title-actions">
          <button type="button" className="btn btn--primary" onClick={onNew}>
            Begin a journey
          </button>
          {hasSave && (
            <button type="button" className="btn" onClick={onContinue}>
              Continue
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
