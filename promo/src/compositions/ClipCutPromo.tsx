import React from 'react';
import {AbsoluteFill, Audio, staticFile} from 'remotion';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {wipe} from '@remotion/transitions/wipe';
import {CropDemo, ExportDemo, Intro, OpenVideo, Outro, TimelineDemo} from '../scenes/Scenes';

export const ClipCutPromo: React.FC = () => <AbsoluteFill style={{backgroundColor: '#0c0d10'}}>
  <Audio src={staticFile('audio/clipcut-original.wav')} volume={1} />
  <TransitionSeries>
    <TransitionSeries.Sequence name="Identidade" durationInFrames={258}><Intro /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={wipe({direction: 'from-right'})} timing={linearTiming({durationInFrames: 18})} />
    <TransitionSeries.Sequence name="Interface" durationInFrames={318}><OpenVideo /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={wipe({direction: 'from-bottom'})} timing={linearTiming({durationInFrames: 18})} />
    <TransitionSeries.Sequence name="Timeline" durationInFrames={498}><TimelineDemo /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={wipe({direction: 'from-right'})} timing={linearTiming({durationInFrames: 18})} />
    <TransitionSeries.Sequence name="Enquadramento" durationInFrames={378}><CropDemo /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={wipe({direction: 'from-right'})} timing={linearTiming({durationInFrames: 18})} />
    <TransitionSeries.Sequence name="Exportação" durationInFrames={318}><ExportDemo /></TransitionSeries.Sequence>
    <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 18})} />
    <TransitionSeries.Sequence name="Encerramento" durationInFrames={240}><Outro /></TransitionSeries.Sequence>
  </TransitionSeries>
</AbsoluteFill>;
