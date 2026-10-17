import { useState } from 'react';
import { CLASSES } from '../content/classes';

interface Props {
  onBack: () => void;
  onStart: (name: string, classId: string) => void;
}

export function CharacterCreate({ onBack, onStart }: Props) {
  const [name, setName] = useState('');
  const [classId, setClassId] = useState(CLASSES[0]!.id);

  return (
    <section className="create-screen">
      <h1>Who walks the Marches?</h1>
      <p>Pick a name and a way of surviving. The road will do the rest.</p>

      <div className="field">
        <label htmlFor="hero-name">Name</label>
        <input
          id="hero-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Rowan Vale"
          maxLength={24}
          autoFocus
        />
      </div>

      <div className="field">
        <label>Calling</label>
        <div className="class-grid" role="listbox" aria-label="Character calling">
          {CLASSES.map((c) => (
            <button
              key={c.id}
              type="button"
              role="option"
              aria-selected={classId === c.id}
              className={`class-option${classId === c.id ? ' is-selected' : ''}`}
              onClick={() => setClassId(c.id)}
            >
              <strong>{c.name}</strong>
              <span>{c.blurb}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="title-actions">
        <button
          type="button"
          className="btn btn--primary"
          onClick={() => onStart(name.trim() || 'Wanderer', classId)}
        >
          Enter Hollowmere
        </button>
        <button type="button" className="btn btn--ghost" onClick={onBack}>
          Back
        </button>
      </div>
    </section>
  );
}
