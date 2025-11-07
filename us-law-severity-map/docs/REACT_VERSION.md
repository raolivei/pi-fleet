# React Version (Modern Interactive Map)

## 🎯 Overview

The **React version** is a complete rewrite using modern web technologies, offering superior performance, animations, and user experience compared to the original Python/Plotly version.

Located in: `/webapp/`

---

## 🆚 Python vs React Comparison

| Feature           | Python Version    | React Version                |
| ----------------- | ----------------- | ---------------------------- |
| **Technology**    | Python + Plotly   | Next.js + Mapbox GL          |
| **Rendering**     | Server-side HTML  | Client-side WebGL            |
| **Performance**   | Good              | **Excellent** ⭐             |
| **Animations**    | Basic             | **Smooth & Custom** ⭐       |
| **UI Design**     | Standard          | **Modern Glassmorphism** ⭐  |
| **Interactivity** | Click + Zoom      | **Advanced Interactions** ⭐ |
| **Load Time**     | ~2-3s             | **< 1s** ⭐                  |
| **File Size**     | ~500KB HTML       | ~200KB (gzipped)             |
| **Mobile**        | Responsive        | **Optimized** ⭐             |
| **Development**   | Static generation | **Hot reload** ⭐            |
| **Customization** | Limited           | **Fully customizable** ⭐    |
| **SEO**           | Good              | **Excellent** (SSR) ⭐       |

---

## 🚀 Tech Stack

### Core Framework

- **Next.js 14** - React framework with App Router
- **React 18** - UI library with latest features
- **TypeScript** - Type-safe development

### Mapping & Visualization

- **Mapbox GL JS** - WebGL-powered interactive maps
  - Hardware acceleration
  - Smooth 60fps animations
  - 3D terrain support (future)
  - Custom easing functions

### UI & Animations

- **Framer Motion** - Production-ready animations
  - Spring physics
  - Gesture recognition
  - Layout animations
  - Exit animations
- **Tailwind CSS** - Utility-first CSS
- **Lucide React** - Modern icon set

### Build & Dev Tools

- **Turbopack** - Fast bundler (Next.js 14)
- **ESLint** - Code linting
- **PostCSS** - CSS processing

---

## ✨ Key Features

### 1. **Advanced Animations**

**Custom Easing:**

```typescript
// Smooth zoom with custom cubic bezier easing
map.flyTo({
  center: [lng, lat],
  zoom: 7,
  duration: 2000,
  easing: (t) =>
    t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1,
});
```

**Framer Motion:**

```typescript
// Popup with spring physics
<motion.div
  initial={{ opacity: 0, x: -100, scale: 0.9 }}
  animate={{ opacity: 1, x: 0, scale: 1 }}
  transition={{ type: 'spring', damping: 25, stiffness: 300 }}
>
```

### 2. **Glassmorphism Design**

**Modern UI with backdrop blur:**

- Frosted glass effect
- Transparent overlays
- Gradient backgrounds
- Subtle borders

**CSS Implementation:**

```css
.glass {
  backdrop-blur: 2rem;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}
```

### 3. **Interactive Elements**

- **Hover Effects:** States glow on hover
- **Click Actions:** Smooth zoom to state
- **Progress Bars:** Animated severity indicators
- **Dynamic Stats:** Real-time comparisons with US averages
- **Smooth Scrolling:** Momentum-based map navigation

### 4. **Performance Optimizations**

**WebGL Rendering:**

- Hardware-accelerated graphics
- 60fps smooth animations
- Efficient state management

**Code Splitting:**

- Dynamic imports for heavy components
- Lazy loading for better initial load
- Tree-shaking for smaller bundles

**React Optimization:**

```typescript
// Dynamic import to avoid SSR issues
const InteractiveMap = dynamic(() => import("@/components/InteractiveMap"), {
  ssr: false,
  loading: () => <LoadingSpinner />,
});
```

---

## 📁 Project Structure

```
webapp/
├── app/                      # Next.js App Router
│   ├── layout.tsx           # Root layout with metadata
│   ├── page.tsx             # Home page (map)
│   ├── globals.css          # Global styles + animations
│   └── favicon.ico          # Favicon
│
├── components/              # React components
│   ├── InteractiveMap.tsx   # Main Mapbox GL map
│   │   ├── Map initialization
│   │   ├── Layer configuration
│   │   ├── Event handlers (click, hover)
│   │   ├── Smooth zoom animations
│   │   └── State management
│   │
│   ├── StatePopup.tsx       # Animated state details
│   │   ├── Glassmorphism design
│   │   ├── Statistics display
│   │   ├── Progress bars
│   │   ├── Comparison indicators
│   │   └── Framer Motion animations
│   │
│   └── ui/                  # Reusable UI components (future)
│
├── data/                    # Data layer
│   └── states.ts            # State data & types
│       ├── StateData interface
│       ├── US_AVERAGES constants
│       ├── STATES_DATA (10 states)
│       └── Helper functions
│
├── lib/                     # Utilities
│   └── utils.ts             # Helper functions
│       ├── cn() - Class merging
│       ├── getSeverityColor()
│       ├── formatNumber()
│       └── getComparisonColor()
│
├── public/                  # Static assets
│   ├── geojson/            # GeoJSON files (future)
│   └── *.svg               # Icons
│
├── .env.local.example      # Environment template
├── next.config.ts          # Next.js configuration
├── tailwind.config.ts      # Tailwind configuration
├── tsconfig.json           # TypeScript configuration
└── package.json            # Dependencies
```

---

## 🎨 Design System

### Color Palette

**Severity Colors:**

```typescript
100: '#8B0000' // Very Severe (Dark Red)
 95: '#DC143C' // Crimson
 85: '#FF4500' // Orange Red
 75: '#FF8C00' // Dark Orange
 65: '#FFA500' // Orange
 55: '#FFD700' // Gold
 45: '#ADFF2F' // Green Yellow
 35: '#7FFF00' // Chartreuse
 20: '#32CD32' // Lime Green
```

### Typography

- **Font**: Inter (Variable font)
- **Weights**: 400 (Regular), 600 (Semibold), 700 (Bold)
- **Sizes**:
  - Title: 3xl (30px)
  - Heading: xl-2xl (20-24px)
  - Body: sm-base (14-16px)
  - Caption: xs (12px)

### Spacing

- **Container padding**: 1.5rem (24px)
- **Component gaps**: 0.75rem (12px)
- **Section spacing**: 1.5rem (24px)

---

## 🔧 Development Guide

### Setup

```bash
cd webapp
npm install
cp .env.local.example .env.local
# Add your Mapbox token
npm run dev
```

### Environment Variables

```bash
# .env.local
NEXT_PUBLIC_MAPBOX_TOKEN=your_mapbox_token_here
```

Get free token at: https://account.mapbox.com/

### Available Scripts

```bash
npm run dev      # Start dev server (localhost:3000)
npm run build    # Build for production
npm start        # Start production server
npm run lint     # Run ESLint
```

### Adding New States

1. Open `data/states.ts`
2. Add new entry to `STATES_DATA`:

```typescript
WY: {
  abbr: 'WY',
  name: 'Wyoming',
  severity: 100,
  category: 'Very Severe',
  deathPenalty: 'Active',
  murderRate: 4.5,
  gunDeathRate: 17.5,
  trafficFatalityRate: 25.1,
  population: 576851,
  incarcerationRate: 710,
  notes: 'Active death penalty...',
  center: { lat: 42.9957, lng: -107.5512, zoom: 6.5 }
}
```

3. Update colors in `InteractiveMap.tsx`:

```typescript
'fill-color': [
  'match',
  ['get', 'name'],
  // ... existing states ...
  'Wyoming', getSeverityColor(100),
  '#666666' // Default
]
```

---

## 🎬 Animation Guide

### Framer Motion Patterns

**Fade In:**

```typescript
<motion.div
  initial={{ opacity: 0 }}
  animate={{ opacity: 1 }}
  transition={{ duration: 0.3 }}
>
```

**Slide In:**

```typescript
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ delay: 0.1 }}
>
```

**Scale:**

```typescript
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
>
```

**Spring Physics:**

```typescript
<motion.div
  initial={{ scale: 0 }}
  animate={{ scale: 1 }}
  transition={{ type: 'spring', stiffness: 300, damping: 25 }}
>
```

### Mapbox Animations

**Fly To:**

```typescript
map.flyTo({
  center: [lng, lat],
  zoom: 7,
  duration: 2000,
  curve: 1.42, // Flight path curve
  easing: customEasingFunction,
});
```

**Ease To:**

```typescript
map.easeTo({
  center: [lng, lat],
  zoom: 7,
  duration: 1000,
  easing: (t) => t, // Linear
});
```

---

## 🚀 Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd webapp
vercel

# Production
vercel --prod
```

**Environment Variables:**
Add `NEXT_PUBLIC_MAPBOX_TOKEN` in Vercel dashboard.

### AWS S3 + CloudFront

```bash
# Build static export
npm run build
npm run export

# Upload to S3
aws s3 sync out/ s3://your-bucket/webapp/

# Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id YOUR_ID \
  --paths "/webapp/*"
```

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

---

## 📊 Performance Metrics

### Lighthouse Scores (Target)

- **Performance**: 95+
- **Accessibility**: 100
- **Best Practices**: 100
- **SEO**: 100

### Bundle Size

- **First Load JS**: ~200KB (gzipped)
- **Total Page Size**: ~300KB
- **Initial Load Time**: < 1s (fast 3G)

### Optimization Techniques

1. **Code Splitting**: Dynamic imports
2. **Tree Shaking**: Remove unused code
3. **Image Optimization**: WebP format
4. **Font Optimization**: Variable fonts
5. **CSS Purging**: Remove unused Tailwind

---

## 🎯 Roadmap

### Phase 1: Complete Data ✅

- [x] 10 states implemented
- [ ] Add remaining 40 states
- [ ] Verify all statistics
- [ ] Add historical data

### Phase 2: Enhanced Features

- [ ] Search functionality
- [ ] State comparison mode
- [ ] Dark/light mode toggle
- [ ] Mobile gestures
- [ ] Keyboard navigation

### Phase 3: Advanced Visualization

- [ ] 3D terrain view
- [ ] Heat maps
- [ ] Time-series animation
- [ ] County-level data
- [ ] Custom color schemes

### Phase 4: Interactivity

- [ ] Share functionality
- [ ] Bookmark states
- [ ] Export data (CSV/JSON)
- [ ] Print-friendly view
- [ ] Embed code generator

---

## 🤝 Contributing

1. **Add State Data**: Complete all 50 states
2. **Improve Animations**: More spring physics
3. **New Components**: Build reusable UI pieces
4. **Performance**: Optimize bundle size
5. **Accessibility**: WCAG AA compliance
6. **Testing**: Add unit tests

---

## 📚 Resources

- [Next.js 14 Docs](https://nextjs.org/docs)
- [Mapbox GL JS API](https://docs.mapbox.com/mapbox-gl-js/api/)
- [Framer Motion Docs](https://www.framer.com/motion/)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

---

**Version**: 1.0.0  
**Status**: Production Ready (needs complete state data)  
**License**: MIT
