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
          A long road through the Marches. A dungeon master made of rules, memory, and dice —
          no AI required. You play. It keeps the world turning.
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
