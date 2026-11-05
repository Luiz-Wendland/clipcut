import React from 'react';
import {Composition} from 'remotion';
import {ClipCutPromo} from './compositions/ClipCutPromo';
import {ClipCutPreview} from './compositions/ClipCutPreview';
import './design/global.css';

export const RemotionRoot: React.FC = () => <>
  <Composition id="ClipCutPromo" component={ClipCutPromo} width={1920} height={1080} fps={60} durationInFrames={1920} />
  <Composition id="ClipCutPreview" component={ClipCutPreview} width={1280} height={720} fps={30} durationInFrames={240} />
</>;
