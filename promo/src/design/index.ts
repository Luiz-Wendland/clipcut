import source from './tokens.json';

export const tokens = {
  ...source,
  colors: {
    ...source.colors,
    panel: source.colors.surfaceHigh,
    control: source.colors.surfaceLow,
    controlHover: source.colors.surfaceHighest,
    accentHover: '#41384f',
  },
} as const;

export const px = (value: number) => `${value}px`;
