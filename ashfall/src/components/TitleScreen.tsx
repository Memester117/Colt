import { useState } from 'react';
import { clearFootTitleZoom, getCapellaLoops, hasFootTitleZoom } from '../engine/save';

interface Props {
  hasSave: boolean;
  onNew: () => void;
  onContinue: () => void;
  onOpenAi: () => void;
  onHardReset: () => void;
}

export function TitleScreen({ hasSave, onNew, onContinue, onOpenAi, onHardReset }: Props) {
  const [footZoom, setFootZoom] = useState(() => hasFootTitleZoom());
  const [confirmReset, setConfirmReset] = useState(false);
  const loops = getCapellaLoops();

  function begin() {
    if (footZoom) clearFootTitleZoom();
    setFootZoom(false);
    onNew();
  }

  function hardReset() {
    if (!confirmReset) {
      setConfirmReset(true);
      return;
    }
    onHardReset();
    setConfirmReset(false);
    setFootZoom(false);
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
            : 'A long road through the Marches — until Mama notices. Story expands. Capella interrupts. Love means shrinking.'}
        </p>
        {loops > 0 && (
          <p className="title-meta">
            Capella grip: loop {loops} · hard-reset clears this
          </p>
        )}
        <div className="title-actions">
          <button type="button" className="btn btn--primary" onClick={begin}>
            Begin a journey
          </button>
          {hasSave && (
            <button type="button" className="btn" onClick={onContinue}>
              Continue
            </button>
          )}
          <button type="button" className="btn btn--ghost" onClick={onOpenAi}>
            Capella AI…
          </button>
          <button
            type="button"
            className={`btn${confirmReset ? ' btn--danger' : ' btn--ghost'}`}
            onClick={hardReset}
            onBlur={() => setConfirmReset(false)}
          >
            {confirmReset ? 'Confirm hard restart' : 'Hard restart'}
          </button>
        </div>
      </div>
    </section>
  );
}
