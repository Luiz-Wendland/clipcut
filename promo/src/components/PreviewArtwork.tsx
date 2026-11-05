import React from 'react';
import {useCurrentFrame} from 'remotion';

export const PreviewArtwork: React.FC = () => {
  const frame = useCurrentFrame();
  const phase = frame / 240 * Math.PI * 2;
  const sunY = Math.sin(phase) * 8;
  const drift = Math.sin(phase) * 22;

  return (
    <svg viewBox="0 0 1280 720" width="100%" height="100%" preserveAspectRatio="xMidYMid slice">
      <defs>
        <linearGradient id="sky" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#263552" />
          <stop offset=".55" stopColor="#8b7195" />
          <stop offset="1" stopColor="#f1b99b" />
        </linearGradient>
        <linearGradient id="water" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stopColor="#536b83" />
          <stop offset="1" stopColor="#243749" />
        </linearGradient>
        <radialGradient id="sunGlow">
          <stop stopColor="#ffe1bc" stopOpacity=".9" />
          <stop offset="1" stopColor="#ffc5a3" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width="1280" height="720" fill="url(#sky)" />
      <circle cx="880" cy={180 + sunY} r="152" fill="url(#sunGlow)" />
      <circle cx="880" cy={180 + sunY} r="62" fill="#ffe2c4" opacity=".88" />
      <path d={`M0 390 Q220 240 440 385 T880 340 T1280 390 V720 H0Z`} fill="#635b78" />
      <path d={`M0 440 L200 305 L355 435 L590 260 L815 450 L1010 310 L1280 455 V720 H0Z`} fill="#3c435c" />
      <path d="M468 376 590 260 690 383 617 352 580 371 548 342Z" fill="#c6b8bd" opacity=".72" />
      <path d="M885 382 1010 310 1126 408 1056 372 1014 390 977 354Z" fill="#d0c1c7" opacity=".58" />
      <path d={`M0 455 Q300 425 580 478 T1280 456 V720 H0Z`} fill="url(#water)" />
      <g fill="none" stroke="#e9c9bd" strokeOpacity=".42" strokeWidth="3">
        <path d={`M${80 + drift} 520 Q270 497 450 521 T820 520`} />
        <path d={`M${410 - drift} 568 Q625 546 840 570 T1180 560`} />
        <path d={`M${140 + drift} 627 Q390 606 630 628 T1040 625`} />
      </g>
      <g fill="#1c2935" opacity=".84">
        <path d="M0 475 55 360 110 475 83 459 55 470 30 454Z" />
        <path d="M86 482 157 330 230 482 197 459 158 473 126 450Z" />
        <path d="M1090 475 1150 352 1210 475 1182 458 1151 470 1120 454Z" />
        <path d="M1180 484 1240 370 1300 484 1268 463 1241 477 1211 456Z" />
      </g>
      <rect width="1280" height="720" fill="#111216" opacity=".08" />
    </svg>
  );
};
