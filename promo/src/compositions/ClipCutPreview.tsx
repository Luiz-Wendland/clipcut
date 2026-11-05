import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {ClipCutWindow} from '../components/ClipCutWindow';
import {tokens} from '../design';

export const ClipCutPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const phase = frame / 240 * Math.PI * 2;
  const center = (Math.sin(phase - Math.PI / 2) + 1) / 2;
  const playhead = interpolate(center, [0, 1], [.21, .78]);
  const inPoint = interpolate((Math.sin(phase * 2 - Math.PI / 2) + 1) / 2, [0, 1], [.13, .23]);
  const outPoint = interpolate((Math.sin(phase * 2 + Math.PI / 2) + 1) / 2, [0, 1], [.68, .82]);
  return <AbsoluteFill style={{background: 'radial-gradient(ellipse at 50% 45%, #282630, #101115 78%)', display: 'grid', placeItems: 'center', overflow: 'hidden'}}>
    <div style={{transform: 'scale(.84)'}}><ClipCutWindow tool="Corte" compact inPoint={inPoint} outPoint={outPoint} playhead={playhead} /></div>
  </AbsoluteFill>;
};
