import React from 'react';
import {AbsoluteFill, Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {ClipCutWindow} from '../components/ClipCutWindow';
import {PreviewArtwork} from '../components/PreviewArtwork';
import {tokens} from '../design';

const C = tokens.colors;
const ease = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(.22, 1, .36, 1)} as const;

// Editorial graphics live outside the reconstructed application.
const Backdrop: React.FC<React.PropsWithChildren> = ({children}) => <AbsoluteFill style={{background: C.canvas, color: C.foreground, fontFamily: 'Inter', overflow: 'hidden'}}>
  <div style={{position: 'absolute', inset: 0, background: `radial-gradient(ellipse at 78% 35%, ${C.accentSoft}88, transparent 63%)`}} />
  <svg width="1920" height="1080" style={{position: 'absolute', inset: 0, opacity: .12}}><defs><pattern id="grid" width="80" height="80" patternUnits="userSpaceOnUse"><path d="M80 0H0V80" fill="none" stroke={C.muted} strokeWidth=".5" /></pattern></defs><rect width="100%" height="100%" fill="url(#grid)" /></svg>
  {children}
  <div style={{position: 'absolute', left: 76, bottom: 37, right: 76, display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 12, letterSpacing: 1.5, color: C.muted}}>
    <span>CLIPCUT <span style={{opacity: .35, padding: '0 16px'}}> / </span> UM PROJETO PESSOAL</span>
    <span style={{fontSize: 10, letterSpacing: .6}}>INTERFACE RECONSTITUÍDA · DEMONSTRAÇÃO VISUAL</span>
  </div>
</AbsoluteFill>;

const Eyebrow: React.FC<React.PropsWithChildren> = ({children}) => <div style={{fontSize: 14, color: C.accent, letterSpacing: 3, fontWeight: 500, marginBottom: 26, display: 'flex', alignItems: 'center', gap: 14}}><span style={{width: 30, height: 2, background: C.accent}} />{children}</div>;

const Reveal: React.FC<React.PropsWithChildren<{delay?: number}>> = ({children, delay = 0}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = spring({frame: frame-delay, fps, config: {damping: 24, stiffness: 130}});
  return <div style={{opacity: p, transform: `translateY(${(1-p)*55}px)`, filter: `blur(${(1-p)*7}px)`}}>{children}</div>;
};

const Cursor: React.FC<{x: number; y: number; pressed?: boolean}> = ({x, y, pressed}) => <div style={{position: 'absolute', left: x, top: y, pointerEvents: 'none', transform: `scale(${pressed ? .86 : 1})`, filter: 'drop-shadow(0 4px 8px #0008)'}}>
  {pressed && <div style={{position: 'absolute', width: 52, height: 52, left: -20, top: -20, borderRadius: 99, border: `2px solid ${C.accent}`, background: `${C.accent}22`}} />}
  <svg width="28" height="34" viewBox="0 0 28 34"><path d="M3 2L24 21L14 22L9 31Z" fill={C.foreground} stroke={C.canvas} strokeWidth="2" /></svg>
</div>;

export const Intro: React.FC = () => {
  const f = useCurrentFrame();
  const cut = interpolate(f, [102, 130], [0, 1], ease);
  const exit = interpolate(f, [240, 258], [1, 0], ease);
  return <Backdrop>
    <div style={{position: 'absolute', left: 100, top: 84, display: 'flex', alignItems: 'center', gap: 15}}><Img src={staticFile('clipcut-brand.svg')} style={{width: 46, height: 46}} /><span style={{fontSize: 22, fontWeight: 600}}>ClipCut</span></div>
    <div style={{position: 'absolute', left: 130, top: 232, opacity: exit}}>
      <Reveal><Eyebrow>MENOS EDIÇÃO. MAIS MOMENTO.</Eyebrow></Reveal>
      <Reveal delay={8}><div style={{fontSize: 116, lineHeight: 1.06, letterSpacing: -7, fontWeight: 600}}>Seu vídeo tem</div></Reveal>
      <Reveal delay={20}><div style={{fontSize: 116, lineHeight: 1.12, letterSpacing: -7, fontWeight: 600}}>uma <span style={{color: C.accent}}>parte boa.</span></div></Reveal>
      <Reveal delay={75}><div style={{fontSize: 28, color: C.muted, marginTop: 30}}>Fique com ela.</div></Reveal>
    </div>
    <div style={{position: 'absolute', left: 130, right: 130, top: 735, height: 132, display: 'flex', gap: 10, opacity: exit, transform: `translateY(${interpolate(f, [35, 75], [65, 0], ease)}px)`}}>
      {Array.from({length: 9}, (_, i) => <div key={i} style={{flex: 1, borderRadius: 14, overflow: 'hidden', position: 'relative', opacity: i < 2 || i > 6 ? 1-cut*.8 : 1, transform: `translateX(${i < 2 ? -cut*65 : i > 6 ? cut*65 : 0}px)`, border: `1px solid ${C.outline}`}}><PreviewArtwork /></div>)}
      <div style={{position: 'absolute', left: '22.2%', right: '22.2%', top: -7, bottom: -7, border: `2px solid ${C.accent}`, borderRadius: 18, boxShadow: `0 0 45px ${C.accent}18`, opacity: interpolate(f, [80, 100], [0, 1], ease)}}><span style={{position: 'absolute', top: -28, left: 0, color: C.accent, fontSize: 11, letterSpacing: 2}}>SÓ O QUE IMPORTA</span></div>
    </div>
  </Backdrop>;
};

export const OpenVideo: React.FC = () => {
  const f = useCurrentFrame();
  const p = interpolate(f, [0, 100, 280, 318], [0, 1, 1, 1], ease);
  return <Backdrop>
    <div style={{position: 'absolute', left: 100, top: 280, width: 530}}>
      <Reveal delay={14}><Eyebrow>01 / O ESSENCIAL</Eyebrow></Reveal>
      <Reveal delay={25}><h1 style={{fontSize: 88, lineHeight: 1.04, letterSpacing: -5, fontWeight: 600, margin: 0}}>Um vídeo.<br/>Um bom<br/><span style={{color: C.accent}}>começo.</span></h1></Reveal>
      <Reveal delay={58}><p style={{fontSize: 23, lineHeight: 1.6, color: C.muted, maxWidth: 420}}>Abra seu arquivo local.<br/>O próximo passo é escolher o trecho.</p></Reveal>
      <Reveal delay={100}><div style={{display: 'flex', gap: 12, marginTop: 32}}>{['LOCAL', 'DIRETO', 'SEM EXCESSOS'].map(x => <span key={x} style={{fontSize: 10, letterSpacing: 1.4, padding: '12px 15px', border: `1px solid ${C.outline}`, borderRadius: 99}}>{x}</span>)}</div></Reveal>
    </div>
    <div style={{position: 'absolute', left: 660, top: 160+(1-p)*100, transformOrigin: '0 50%', transform: `perspective(2200px) rotateY(${-8+p*5}deg) rotateX(2deg) scale(.82)`, opacity: interpolate(f, [0, 28], [0, 1], ease)}}><ClipCutWindow playhead={interpolate(f, [40, 270], [.16, .6], ease)} /></div>
  </Backdrop>;
};

export const TimelineDemo: React.FC = () => {
  const f = useCurrentFrame();
  const zoom = interpolate(f, [55, 115, 400, 480], [0, 1, 1, 0], ease);
  const inPoint = interpolate(f, [110, 165], [.08, .23], ease);
  const outPoint = interpolate(f, [225, 285], [.91, .72], ease);
  const playhead = interpolate(f, [0, 110, 165, 300, 395, 470], [.08, .23, .23, .23, .72, .23], ease);
  const x = 28 + 1444*(f < 165 ? inPoint : f < 225 ? interpolate(f, [175, 215], [.23, .91], ease) : outPoint);
  const press = (f >= 110 && f <= 165) || (f >= 225 && f <= 285);
  return <Backdrop>
    <div style={{position: 'absolute', left: 210-zoom*180, top: 240-zoom*510, transformOrigin: 'top left', transform: `scale(${.99+zoom*.23})`}}>
      <ClipCutWindow inPoint={inPoint} outPoint={outPoint} playhead={playhead} />
      {f > 80 && f < 300 && <Cursor x={x} y={810} pressed={press} />}
    </div>
    <div style={{position: 'absolute', inset: '0 0 auto', height: 355, background: `linear-gradient(${C.canvas} 78%, transparent)`, padding: '83px 100px'}}>
      <Reveal><Eyebrow>02 / ESCOLHA O MOMENTO</Eyebrow></Reveal>
      <Reveal delay={12}><div style={{fontSize: 80, lineHeight: 1, letterSpacing: -4, fontWeight: 600}}>{f < 210 ? <>Onde <span style={{color: C.accent}}>começa.</span></> : f < 330 ? <>Onde <span style={{color: C.accent}}>termina.</span></> : <>O resto <span style={{color: C.accent}}>fica de fora.</span></>}</div></Reveal>
    </div>
    <div style={{position: 'absolute', bottom: 125, left: 110, right: 110, display: 'flex', justifyContent: 'space-between', opacity: zoom}}>
      <div style={{color: C.muted, fontSize: 20}}>Arraste as alças. Refine sua seleção.</div>
      <div style={{fontFamily: 'JetBrains Mono', color: C.accent, fontSize: 20}}>{((outPoint-inPoint)*8).toFixed(2)} s <span style={{color: C.muted, fontFamily: 'Inter', fontSize: 14}}>selecionados</span></div>
    </div>
  </Backdrop>;
};

export const CropDemo: React.FC = () => {
  const f = useCurrentFrame();
  const aspect = interpolate(f, [0, 85, 135, 205, 255, 378], [16/9, 16/9, 1, 1, 9/16, 9/16], ease);
  const ratio = f < 110 ? '16:9' : f < 230 ? '1:1' : '9:16';
  return <Backdrop>
    <div style={{position: 'absolute', left: 100, top: 175}}><Reveal><Eyebrow>03 / MUDE O ENQUADRAMENTO</Eyebrow></Reveal><Reveal delay={12}><div style={{fontSize: 74, letterSpacing: -4, fontWeight: 600}}>O mesmo momento.<br/><span style={{color: C.accent}}>Outro formato.</span></div></Reveal></div>
    <div style={{position: 'absolute', left: 100, top: 460, width: 365}}>
      {(['16:9', '1:1', '9:16'] as const).map((r, i) => <div key={r} style={{display: 'flex', gap: 25, alignItems: 'center', padding: '24px 0', color: r === ratio ? C.accent : C.muted, borderBottom: `1px solid ${C.outline}`, opacity: r === ratio ? 1 : .5}}><div style={{width: 50, display: 'grid', placeItems: 'center'}}><div style={{width: i === 2 ? 19 : 38, height: i === 0 ? 22 : 38, border: '2px solid currentColor', borderRadius: 4}} /></div><span style={{fontSize: 26, fontFamily: 'JetBrains Mono'}}>{r}</span><span style={{marginLeft: 'auto', fontSize: 18}}>{r === ratio ? '↗' : '—'}</span></div>)}
      <p style={{fontSize: 18, color: C.muted, lineHeight: 1.6}}>Quadrado, horizontal ou vertical.<br/>Você escolhe o recorte.</p>
    </div>
    <div style={{position: 'absolute', left: 590, top: 380, width: 1330, height: 590, overflow: 'hidden', borderRadius: 28, maskImage: 'linear-gradient(black 94%, transparent)'}}><div style={{transformOrigin: 'top left', transform: `scale(.85) translateY(${interpolate(f, [0, 50], [55, 0], ease)}px)`}}><ClipCutWindow tool="Enquadrar" cropRatio={ratio} cropAspect={aspect} inPoint={.23} outPoint={.72} /></div></div>
  </Backdrop>;
};

export const ExportDemo: React.FC = () => {
  const f = useCurrentFrame();
  const progress = interpolate(f, [70, 250], [0, 1], ease);
  const zoom = interpolate(f, [0, 75], [0, 1], ease);
  return <Backdrop>
    <div style={{position: 'absolute', left: 110, top: 250, width: 550}}>
      <Reveal><Eyebrow>04 / FINALIZE SEU CLIPE</Eyebrow></Reveal>
      <Reveal delay={16}><div style={{fontSize: 92, fontWeight: 600, letterSpacing: -5, lineHeight: 1.05}}>Seu corte.<br/>Suas <span style={{color: C.accent}}>opções.</span></div></Reveal>
      <Reveal delay={45}><p style={{fontSize: 23, lineHeight: 1.6, color: C.muted}}>Formato, qualidade e áudio.<br/>Ajuste a saída do seu jeito.</p></Reveal>
      <Reveal delay={80}><div style={{marginTop: 36, fontSize: 14, color: C.accent, letterSpacing: 2}}>H.264 <span style={{padding: '0 16px', color: C.outline}}>/</span> HEVC <span style={{padding: '0 16px', color: C.outline}}>/</span> AV1</div></Reveal>
      <div style={{marginTop: 38, fontSize: 12, color: C.muted}}>Progresso ilustrativo; não representa tempo real de exportação.</div>
    </div>
    <div style={{position: 'absolute', left: 760, top: 90, width: 1160, height: 900, overflow: 'hidden', borderRadius: 32, maskImage: 'linear-gradient(to right, transparent, black 5%)'}}><div style={{position: 'absolute', left: 20-zoom*1000, top: 30, transformOrigin: 'top left', transform: `scale(${.86+zoom*.34})`}}><ClipCutWindow showExport exportProgress={progress} inPoint={.23} outPoint={.72} />{f > 25 && f < 70 && <Cursor x={1330} y={620} pressed={f > 50} />}</div></div>
  </Backdrop>;
};

export const Outro: React.FC = () => {
  const f = useCurrentFrame();
  return <Backdrop>
    <div style={{position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', opacity: interpolate(f, [220, 240], [1, 0], ease)}}>
      <Reveal><Img src={staticFile('clipcut-brand.svg')} style={{width: 120, height: 120, marginBottom: 16}} /></Reveal>
      <Reveal delay={8}><div style={{fontSize: 110, fontWeight: 600, letterSpacing: -6}}>ClipCut</div></Reveal>
      <Reveal delay={22}><div style={{fontSize: 34, color: C.muted, marginTop: 12}}>Menos excesso. <span style={{color: C.foreground}}>Mais momento.</span></div></Reveal>
      <Reveal delay={45}><div style={{marginTop: 52, padding: '17px 26px', color: C.onAccent, background: C.accent, borderRadius: 99, fontSize: 18}}>Conheça o projeto <span style={{paddingLeft: 25}}>↗</span></div></Reveal>
      <Reveal delay={60}><div style={{marginTop: 24, fontSize: 14, color: C.muted}}>github.com/Luiz-Wendland/clipcut</div></Reveal>
      <Reveal delay={75}><div style={{marginTop: 52, fontSize: 11, letterSpacing: 3, color: C.accent}}>LOCAL　 /　 OPEN SOURCE　 /　 MIT</div></Reveal>
    </div>
  </Backdrop>;
};
