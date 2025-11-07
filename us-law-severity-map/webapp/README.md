# US Law Severity Map - React/Next.js Version 🚀

Modern, interactive map built with React, Next.js 14, TypeScript, and Mapbox GL.

## ✨ Features

- 🗺️ **Mapbox GL** - WebGL-powered interactive maps
- ⚛️ **React 18** - Modern React with hooks
- 📘 **TypeScript** - Type-safe development
- 🎬 **Framer Motion** - Smooth animations
- 💅 **Tailwind CSS** - Utility-first styling
- 🌙 **Dark Mode** - Beautiful dark theme
- 🎨 **Glassmorphism** - Modern UI design

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn
- Mapbox account (free tier works!)

### Installation

```bash
# 1. Navigate to webapp directory
cd webapp

# 2. Install dependencies
npm install

# 3. Create environment file
cp .env.local.example .env.local

# 4. Add your Mapbox token to .env.local
# Get free token at: https://account.mapbox.com/
NEXT_PUBLIC_MAPBOX_TOKEN=your_token_here

# 5. Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser!

## 🎮 Usage

- **Click** any state to zoom in and view detailed statistics
- **Hover** over states to see highlight effects
- **Click Reset** button (X) to return to full US view
- **Scroll** to zoom in/out
- **Drag** to pan the map

## 📁 Project Structure

```
webapp/
├── app/                    # Next.js app directory
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Home page
│   └── globals.css        # Global styles
├── components/            # React components
│   ├── InteractiveMap.tsx # Main map component
│   └── StatePopup.tsx     # State details popup
├── data/                  # State data
│   └── states.ts          # State statistics
├── lib/                   # Utilities
│   └── utils.ts           # Helper functions
└── public/                # Static assets
```

## 🎨 Features Showcase

### Smooth Animations

- Zoom transitions with custom easing
- Slide-in popup animations
- Progress bar animations
- Hover glow effects

### Modern UI

- Glassmorphism design
- Gradient overlays
- Backdrop blur effects
- Responsive layout

### Interactive Elements

- Click-to-zoom with flyTo animation
- State highlighting on hover
- Dynamic statistics comparison
- Color-coded severity scale

## 🛠️ Development

```bash
# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Run linter
npm run lint
```

## 🌐 Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Add environment variable in Vercel dashboard:
# NEXT_PUBLIC_MAPBOX_TOKEN
```

### AWS (with existing infrastructure)

```bash
# Build static export
npm run build

# Upload to S3
aws s3 sync out/ s3://your-bucket-name/
```

## 📦 Dependencies

### Core

- `next` - React framework
- `react` - UI library
- `typescript` - Type safety

### Mapping

- `mapbox-gl` - Interactive maps
- `@types/mapbox-gl` - TypeScript types

### UI/Animation

- `framer-motion` - Animations
- `tailwindcss` - Styling
- `lucide-react` - Icons
- `recharts` - Charts

### Utils

- `clsx` - Conditional classes
- `tailwind-merge` - Merge Tailwind classes

## 🎯 Roadmap

- [ ] Add all 50 states data
- [ ] Add search functionality
- [ ] Add state comparison mode
- [ ] Add dark/light mode toggle
- [ ] Add 3D terrain view
- [ ] Add data export (CSV/JSON)
- [ ] Add mobile gestures
- [ ] Add keyboard navigation
- [ ] Add animation presets
- [ ] Add custom color schemes

## 🤝 Contributing

1. Add missing state data in `data/states.ts`
2. Improve animations in components
3. Add new visualization modes
4. Enhance mobile experience
5. Add accessibility features

## 📝 Notes

- This is the **modern React version** of the original Python/Plotly map
- Uses Mapbox GL for better performance and animations
- Fully client-side rendered for best interactivity
- All data is embedded (no API calls needed)

## 🔗 Related

- **Python Version**: `../main.py` - Original Plotly version
- **Infrastructure**: `../terraform/` - AWS deployment
- **Documentation**: `../docs/` - Guides and docs

---

**Made with ❤️ using React + Next.js + Mapbox**
