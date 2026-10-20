import { useEffect, useRef, useState } from 'react';
import { getSessionTokens, subscribeSessionTokens } from '../engine/capellaAi';

interface Props {
  /** Compact overlay chip on the crush stage. */
  compact?: boolean;
}

/** Small live counter that counts up as Capella burns API tokens. */
export function TokenBurnCounter({ compact = false }: Props) {
  const [target, setTarget] = useState(getSessionTokens);
  const [display, setDisplay] = useState(getSessionTokens);
  const displayRef = useRef(display);
  displayRef.current = display;

  useEffect(() => subscribeSessionTokens(setTarget), []);

  useEffect(() => {
    const from = displayRef.current;
    const to = target;
    if (to === from) return;
    if (to < from) {
      setDisplay(to);
      return;
    }
    const start = performance.now();
    const span = Math.min(1400, 320 + (to - from) * 4);
    let raf = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / span);
      const eased = 1 - (1 - t) ** 3;
      const next = Math.round(from + (to - from) * eased);
      setDisplay(next);
      if (t < 1) raf = requestAnimationFrame(tick);
      else setDisplay(to);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target]);

  const label = target === 0 ? 'tokens waiting' : 'tokens burned';

  return (
    <div
      className={`token-burn${compact ? ' token-burn--compact' : ''}${target > 0 ? ' is-hot' : ''}`}
      aria-live="polite"
      title="API tokens Capella has spent this session"
    >
      <span className="token-burn__label">{label}</span>
      <span className="token-burn__value">{display.toLocaleString()}</span>
    </div>
  );
}
