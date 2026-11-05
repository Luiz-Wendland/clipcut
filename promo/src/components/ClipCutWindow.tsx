import React from 'react';
import {Img, staticFile} from 'remotion';
import {tokens} from '../design';
import {PreviewArtwork} from './PreviewArtwork';

export type ClipCutWindowProps = {
  tool?: 'Corte' | 'Enquadrar' | 'Áudio';
  inPoint?: number;
  outPoint?: number;
  playhead?: number;
  cropRatio?: '16:9' | '9:16' | '1:1' | '4:3';
  cropAspect?: number;
  showExport?: boolean;
  exportProgress?: number;
  compact?: boolean;
};

const C = tokens.colors;
const R = tokens.radii;

export const ClipCutWindow: React.FC<ClipCutWindowProps> = ({
  tool = 'Corte', inPoint = 0.16, outPoint = 0.77, playhead = 0.42,
  cropRatio = '16:9', cropAspect, showExport = false, exportProgress = 0, compact = false,
}) => {
  const aspect = cropAspect ?? ({'16:9': 16 / 9, '4:3': 4 / 3, '1:1': 1, '9:16': 9 / 16}[cropRatio] ?? 16 / 9);
  const previewAspect = 1.76;
  const cropWidthPct = Math.min(74, aspect * 82 / previewAspect);
  const cropHeightPct = Math.min(82, cropWidthPct / aspect * previewAspect);
  const timecode = (fraction: number) => {
    const seconds = Math.max(0, fraction * 8);
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${(seconds % 60).toFixed(2).padStart(5, '0')}`;
  };
  const selectedDuration = (outPoint - inPoint) * 8;
  const outputDimensions = cropRatio === '16:9' ? '1280 × 720' : cropRatio === '4:3' ? '960 × 720' : cropRatio === '1:1' ? '720 × 720' : '405 × 720';
  return (
    <div style={{
      width: compact ? 1450 : 1500, height: compact ? 790 : 900,
      background: C.surface, border: `1px solid ${C.outline}`, borderRadius: R.extraLarge,
      color: C.foreground, padding: 14, fontFamily: 'Inter, sans-serif',
      boxShadow: '0 44px 140px rgba(0,0,0,.52)', position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column', gap: 10,
    }}>
      <div style={{height: 56, flexShrink: 0, display: 'flex', alignItems: 'center', gap: 12, borderBottom: `1px solid ${C.outline}`, padding: '0 8px 10px'}}>
        <Img src={staticFile('clipcut-brand.svg')} style={{width: 38, height: 38}} />
        <div style={{minWidth: 205}}>
          <div style={{fontSize: 14, fontWeight: 600}}>ClipCut</div>
          <div style={{fontSize: 11, color: C.muted}}>sunset-over-lake.mp4</div>
        </div>
        <div style={{flex: 1}} />
        <div style={{borderRadius: 99, background: C.surfaceLow, color: C.muted, padding: '7px 12px', fontSize: 11, display: 'flex', gap: 7, alignItems: 'center'}}>
          <span style={{width: 7, height: 7, borderRadius: 9, background: C.success}} /> Vídeo pronto
        </div>
        <Button>⚙ Preferências</Button>
        <Button primary>↗ Exportar</Button>
      </div>

      <div style={{display: 'flex', flex: 1, minHeight: 0, gap: 8}}>
        <div style={{width: 72, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 8, paddingTop: 12, alignItems: 'center'}}>
          {(['Corte', 'Enquadrar', 'Áudio'] as const).map((label, i) => (
            <div key={label} style={{width: 64, height: 54, borderRadius: R.medium, background: tool === label ? C.accentSoft : 'transparent', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', gap: 2}}>
              <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke={tool === label ? C.accent : C.muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">{i === 0 ? <><circle cx="6" cy="6" r="3" /><circle cx="6" cy="18" r="3" /><path d="M8.5 7.5L21 21M8.5 16.5L21 3" /></> : i === 1 ? <><path d="M7 3v14h14M3 7h14v14" /></> : <><path d="M9 18V5l11-2v13M9 8l11-2" /><ellipse cx="6" cy="18" rx="3" ry="2" /><ellipse cx="17" cy="16" rx="3" ry="2" /></>}</svg>
              <span style={{fontSize: 11, fontWeight: tool === label ? 600 : 400, color: tool === label ? C.foreground : C.muted}}>{label}</span>
            </div>
          ))}
        </div>

        <div style={{flex: 1, minWidth: 0, position: 'relative', borderRadius: R.large, overflow: 'hidden', background: C.preview, display: 'grid', placeItems: 'center'}}>
          <div style={{position: 'absolute', inset: 0}}><PreviewArtwork /></div>
          {tool === 'Enquadrar' && <CropFrame ratio={cropRatio} width={cropWidthPct} height={cropHeightPct} />}
          <div style={{position: 'absolute', bottom: 14, width: 'min(520px, calc(100% - 28px))', height: 48, borderRadius: 99, border: '1px solid rgba(255,255,255,.14)', background: 'rgba(27,29,36,.90)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, fontSize: 12}}>
            <span style={{color: C.muted}}>− quadro</span><span style={{background: C.accentSoft, borderRadius: 99, padding: '8px 14px', color: C.foreground}}>Ⅱ Pausar</span><span style={{color: C.muted}}>+ quadro</span><span style={{fontFamily: 'JetBrains Mono', marginLeft: 22}}>{timecode(playhead)} / 00:08.00</span>
          </div>
        </div>

        {tool !== 'Corte' && <div style={{width: 252, flexShrink: 0, padding: '16px 8px 12px 16px', display: 'flex', flexDirection: 'column', gap: 14}}>
          <div style={{fontSize: 22, fontWeight: 600}}>{tool}</div>
          {tool === 'Enquadrar' ? <>
            <Label>PROPORÇÃO</Label>
            <div style={{display: 'flex', flexWrap: 'wrap', gap: 6}}>{['Original', '4:3', '16:9', '21:9', '9:16', '1:1', '4:5'].map((x) => <Chip key={x} selected={x === cropRatio}>{x}</Chip>)}</div>
            <Button>⊙ Centralizar moldura</Button>
            <div style={{height: 1, background: C.outline}} />
            <Label>SAÍDA</Label><div style={{color: C.muted, fontSize: 12}}>{outputDimensions} px</div>
          </> : <>
            <div style={{height: 1, background: C.outline}} />
            <div style={{fontSize: 13}}>Incluir áudio</div><div style={{fontSize: 11, color: C.muted}}>AAC estéreo · 192 kb/s</div>
            <Label>VOLUME DA PRÉVIA</Label><Button>Mudo</Button><div style={{height: 4, background: C.surfaceHighest, borderRadius: 99}}><div style={{height: 4, width: '80%', background: C.accent, borderRadius: 99}} /></div>
          </>}
        </div>}
      </div>

      <div style={{height: 178, flexShrink: 0, borderRadius: R.large, background: C.surfaceLow, border: `1px solid ${C.outline}`, padding: 12, position: 'relative'}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 8, height: 32, fontSize: 12}}>
          <span style={{color: C.muted}}>IN</span><TimeBox>{timecode(inPoint)}</TimeBox>
          <span style={{color: C.muted, marginLeft: 8}}>OUT</span><TimeBox>{timecode(outPoint)}</TimeBox>
          <div style={{flex: 1}} />
          <span style={{color: C.muted}}>Duração</span><span style={{color: C.accent, fontFamily: 'JetBrains Mono'}}>{timecode(selectedDuration / 8)}</span>
          <Button small>1.0×</Button><Button small>+</Button><span style={{fontSize: 11}}>Reproduzir só o trecho</span>
        </div>
        <div style={{height: 112, position: 'relative', marginTop: 8, border: `1px solid ${C.outline}`, borderRadius: 13, overflow: 'hidden', background: C.canvas}}>
          <div style={{position: 'absolute', inset: 0, display: 'flex', opacity: .9}}>{Array.from({length: 12}, (_, i) => <div key={i} style={{flex: 1, minWidth: 0, overflow: 'hidden', borderRight: '1px solid rgba(255,255,255,.12)'}}><svg viewBox="0 0 160 110" width="100%" height="100%" preserveAspectRatio="xMidYMid slice"><rect width="160" height="110" fill="#8b7195" /><circle cx={114-i} cy="24" r="13" fill="#ffe2c4" /><path d="M0 80L35 26L80 73L112 35L160 81V110H0Z" fill="#3c435c" /><path d="M0 82Q50 72 90 85T160 80V110H0Z" fill="#536b83" /></svg></div>)}</div>
          <div style={{position: 'absolute', bottom: 0, height: '32%', left: 0, right: 0, background: 'rgba(17,18,22,.7)', display: 'flex', alignItems: 'center', gap: 5, padding: '0 10px'}}>
            {Array.from({length: 160}, (_, i) => { const h = 5 + (Math.abs(Math.sin(i * 1.17) * Math.cos(i * .39)) * 27); return <div key={i} style={{flex: 1, height: h, borderRadius: 2, background: 'rgba(208,188,255,.72)'}} />; })}
          </div>
          <div style={{position: 'absolute', inset: '0 auto 0 0', width: `${inPoint * 100}%`, background: 'rgba(9,10,15,.55)'}} />
          <div style={{position: 'absolute', inset: '0 0 0 auto', width: `${(1 - outPoint) * 100}%`, background: 'rgba(9,10,15,.55)'}} />
          <div style={{position: 'absolute', top: 0, bottom: 0, left: `${inPoint * 100}%`, width: `${(outPoint - inPoint) * 100}%`, border: `2px solid ${C.accent}`, background: 'rgba(208,188,255,.13)'}} />
          <div style={{position: 'absolute', top: 0, bottom: 0, left: `${playhead * 100}%`, width: 2, background: C.foreground, boxShadow: '0 0 12px rgba(255,255,255,.45)'}}><div style={{position: 'absolute', top: 2, left: -5, width: 12, height: 12, borderRadius: 8, background: C.foreground, border: `2px solid ${C.surface}`}} /></div>
          <div style={{position: 'absolute', top: 0, left: `${inPoint * 100}%`, bottom: 0, width: 8, borderRadius: 5, background: C.accent}} />
          <div style={{position: 'absolute', top: 0, left: `${outPoint * 100}%`, bottom: 0, width: 8, borderRadius: 5, background: C.accent}} />
        </div>
      </div>

      {showExport && <div style={{position: 'absolute', top: 76, right: 18, bottom: 190, width: 390, borderRadius: R.extraLarge, background: C.surfaceHigh, border: `1px solid ${C.outline}`, boxShadow: '0 24px 80px rgba(0,0,0,.5)', padding: 20, display: 'flex', flexDirection: 'column', gap: 13}}>
        <div style={{fontSize: 22, fontWeight: 600}}>Exportar clipe</div>
        <div style={{fontSize: 12, color: C.muted}}>sunset-over-lake.mp4</div><div style={{height: 1, background: C.outline}} />
        <Label>CODEC</Label><div style={{display: 'flex', gap: 6}}><Chip selected>H.264</Chip><Chip>HEVC</Chip><Chip>AV1</Chip></div>
        <Label>ENCODER</Label><div style={{display: 'flex', gap: 6}}><Chip selected>CPU</Chip><Chip>GPU</Chip></div>
        <Label>QUALIDADE</Label><div style={{display: 'flex', gap: 6}}><Chip selected>Alta</Chip><Chip>Máxima</Chip><Chip>Compacto</Chip></div>
        <Label>ENQUADRAMENTO</Label><div style={{fontSize: 12, color: C.muted}}>Original　·　16:9</div>
        <Label>ÁUDIO</Label><div style={{fontSize: 12, color: C.muted}}>AAC estéreo · 192 kb/s</div>
        <Label>SAÍDA</Label><div style={{fontSize: 12, color: C.muted}}>clip-sunset-over-lake.mp4　·　MP4</div>
        <div style={{flex: 1}} />
        <div style={{borderRadius: R.medium, background: C.surface, padding: 12, fontSize: 11, color: C.muted}}>{outputDimensions} px　·　{timecode(selectedDuration / 8)}<br/>H.264 · CPU · 30 fps · MP4</div>
        <div style={{height: 4, background: C.surfaceHighest, borderRadius: 4}}><div style={{height: 4, width: `${Math.max(4, exportProgress * 100)}%`, background: C.accent, borderRadius: 4}} /></div>
        <Button primary>↗ {exportProgress >= 1 ? 'Exportação concluída' : 'Exportar vídeo'}</Button>
      </div>}
    </div>
  );
};

const Button: React.FC<React.PropsWithChildren<{primary?: boolean; small?: boolean}>> = ({children, primary, small}) => <div style={{height: small ? 30 : 38, borderRadius: 999, padding: '0 12px', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: primary ? C.accent : C.control, color: primary ? C.onAccent : C.foreground, fontSize: small ? 11 : 12, fontWeight: primary ? 600 : 500, whiteSpace: 'nowrap'}}>{children}</div>;
const Chip: React.FC<React.PropsWithChildren<{selected?: boolean}>> = ({children, selected}) => <div style={{borderRadius: 999, padding: '7px 10px', background: selected ? C.accentSoft : C.control, color: C.foreground, fontSize: 11, whiteSpace: 'nowrap'}}>{children}</div>;
const Label: React.FC<React.PropsWithChildren> = ({children}) => <div style={{fontSize: 10, letterSpacing: 1.1, fontWeight: 600, color: C.muted}}>{children}</div>;
const TimeBox: React.FC<React.PropsWithChildren> = ({children}) => <div style={{padding: '6px 10px', background: C.surface, borderRadius: R.small, fontFamily: 'JetBrains Mono', fontSize: 11}}>{children}</div>;
const CropFrame: React.FC<{ratio: string; width: number; height: number}> = ({ratio, width, height}) => <div style={{position: 'absolute', width: `${width}%`, height: `${height}%`, border: `2px solid ${C.accent}`, borderRadius: 5, boxShadow: '0 0 0 9999px rgba(5,6,10,.52)', display: 'grid', placeItems: 'center'}}><span style={{position: 'absolute', top: -27, left: 0, fontSize: 11, color: '#fff', textShadow: '0 1px 5px #000'}}>{ratio}</span><div style={{position: 'absolute', inset: '33.33% 0', borderTop: '1px solid rgba(255,255,255,.36)', borderBottom: '1px solid rgba(255,255,255,.36)'}} /><div style={{position: 'absolute', inset: '0 33.33%', borderLeft: '1px solid rgba(255,255,255,.36)', borderRight: '1px solid rgba(255,255,255,.36)'}} /></div>;
