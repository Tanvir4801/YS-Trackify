/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        trackify: {
          bg: '#080E1A',
          card: '#0F1A2E',
          cardBorder: '#1E2D48',
          amber: '#F59E0B',
          amberDark: '#D97706',
          cyan: '#0EA5E9',
          emerald: '#10B981',
          textMain: '#F8FAFC',
          textMuted: '#94A3B8',
          darkSurface: '#0B1322',
        },
      },
      fontFamily: {
        heading: ['"Space Grotesk"', 'sans-serif'],
        body: ['"Inter"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      animation: {
        'float': 'float 6s ease-in-out infinite',
        'float-delayed': 'float 6s ease-in-out 2s infinite',
        'scan-line': 'scanLine 2s linear infinite',
        'draw-underline': 'drawUnderline 1s ease-out forwards',
        'pulse-glow': 'pulseGlow 2s ease-in-out infinite',
        'sync-dot': 'syncDot 1.5s ease-in-out infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-12px)' },
        },
        scanLine: {
          '0%': { top: '10%' },
          '100%': { top: '90%' },
        },
        drawUnderline: {
          '0%': { width: '0%' },
          '100%': { width: '100%' },
        },
        pulseGlow: {
          '0%, 100%': { opacity: '0.4' },
          '50%': { opacity: '1' },
        },
        syncDot: {
          '0%, 100%': { transform: 'scale(1)', opacity: '1' },
          '50%': { transform: 'scale(1.5)', opacity: '0.5' },
        },
      },
    },
  },
  plugins: [],
};

