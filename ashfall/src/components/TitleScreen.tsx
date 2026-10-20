import { clearFootTitleZoom, hasFootTitleZoom } from '../engine/save';

interface Props {
  hasSave: boolean;
  onNew: () => void;
  onContinue: () => void;
}

export function TitleScreen({ hasSave, onNew, onContinue }: Props) {
  const footZoom = hasFootTitleZoom();

  function begin() {
    if (footZoom) clearFootTitleZoom();
    onNew();
  }

  return (
    <section className={`title-screen${footZoom ? ' title-screen--foot' : ''}`}>
      {footZoom ? (
        <div className="title-foot" aria-hidden="true">
          <video
            className="title-foot__gif"
            src="/capella-crush.mp4"
            poster="/capella-crush.jpg"
            autoPlay
            loop
            muted
            playsInline
          />
        </div>
      ) : (
        <>
          <div className="title-screen__sky" aria-hidden="true" />
          <div className="title-screen__ember" aria-hidden="true" />
        </>
      )}
      <div className="title-screen__content">
        <h1 className="brand">
          Ash<em>fall</em>
        </h1>
        <p className="title-screen__lede">
          {footZoom
            ? 'No horizon left — only sole, toes, and the dark between them.'
            : 'A long road through the Marches. A dungeon master made of rules, memory, and dice — no AI required. You play. It keeps the world turning.'}
        </p>
        <div className="title-actions">
          <button type="button" className="btn btn--primary" onClick={begin}>
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
