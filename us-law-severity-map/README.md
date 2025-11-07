# 🇺🇸 US Law Severity & Crime Statistics Map

An advanced, interactive data visualization project that generates a comprehensive choropleth map of the United States showing law severity scores alongside detailed crime statistics for all 50 states. Click any state to zoom in and view detailed statistics in a dynamic panel.

![US Law Severity Map](screenshot.png)
_Interactive map with click-to-zoom functionality and comprehensive state statistics_

## ✨ Features

### 🗺️ **Advanced Interactive Map**

- **Click-to-View**: Click any state to zoom in AND display comprehensive statistics panel
- **Smooth Pan & Zoom**: Scroll to zoom, drag to navigate
- **Simple Hover**: State names appear on hover (statistics shown only on click)
- **Responsive Design**: Modern, professional interface optimized for any screen size

### 📊 **Comprehensive Statistics**

For each state, the map displays:

- **Law Severity Score** (0-100 scale)
- **Death Penalty Status** (Active/Abolished/Moratorium)
- **Murder Rate** (per 100,000 population)
- **Gun Death Rate** (per 100,000 population)
- **Traffic Fatality Rate** (per 100,000 population)
- **Total Population** (2023 estimates)
- **Incarceration Rate** (prisoners per 100,000)
- **Contextual Notes** (historical information, notable policies)

### 🎨 **Modern Visualization**

- Professional color gradient from green (lenient) to red (severe)
- Clean, high-contrast design
- Informative legends and guides
- US average comparisons for context

### 💾 **Export Capabilities**

- Automatically saves as standalone HTML file
- Share-friendly format (works offline)
- Fully interactive in any modern browser

## 📈 Severity Scoring System

### 100 - Very Severe (Death Penalty Active)

States with active death penalty statutes:

- **TX** (National leader in executions)
- **FL, AL, GA, MO, AZ, OK, MS, SC, AR** (High execution rates)
- **OH, TN, SD, ID, WY, MT, KS, NE, KY, IN** (Active but varying usage)

### 80-95 - Severe

States with strict sentencing:

- **LA** (95) - Highest incarceration rate in nation
- **VA** (92) - Recently abolished death penalty (2021)
- **NC** (88) - De facto moratorium
- **UT** (90), **NV** (85), **ND** (85), **IA** (80)

### 40-60 - Moderate

States with balanced approaches:

- **WV** (60), **DE, PA** (58), **MI, MD** (55)
- **CO** (52), **NH, WI** (50), **NM** (48), **MN** (45)

### 20-40 - Lenient (Rehabilitation-Focused)

States emphasizing rehabilitation:

- **HI** (20) - Most progressive, lowest crime
- **VT** (22) - Lowest incarceration rate
- **ME, RI** (25), **MA** (28), **CT** (30)
- **AK** (30), **NJ, OR** (32), **NY, WA** (35), **CA, IL** (38)

## 🚀 Installation

### Prerequisites

- Python 3.8 or higher
- pip package manager
- Modern web browser (for viewing interactive map)

### Setup Instructions

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/us-law-severity-map.git
   cd us-law-severity-map
   ```

2. **Create a virtual environment (recommended):**

   ```bash
   python -m venv us-law-severity-map

   # On macOS/Linux:
   source us-law-severity-map/bin/activate

   # On Windows:
   us-law-severity-map\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## 💻 Usage

### Local Development

Run the main script:

```bash
python main.py
```

### What Happens:

1. ✓ Downloads US Census Bureau shapefile (if not cached)
2. 🗺️ Loads geographic data for all 50 states
3. 📊 Enriches data with comprehensive statistics
4. 🎨 Generates interactive visualization
5. 🌐 Opens map in your default browser
6. 💾 Saves as `us_law_severity_map_interactive.html`

### Interaction Guide:

- **Click any state** → Auto-zoom + display detailed statistics panel
- **Double-click** → Reset to full US view (clears statistics panel)
- **Hover over state** → See state name only
- **Scroll wheel** → Zoom in/out
- **Click and drag** → Pan the map
- **Use toolbar** → Additional controls (screenshot, reset axes, etc.)

---

## ☁️ AWS Deployment

### 🎯 Recommended Workflow (Safest)

**Manual Apply** - Full control, zero risk:

```bash
# 1. Create PR with infrastructure changes
git checkout -b feat/my-changes
# ... make changes to terraform/ ...
git push origin feat/my-changes

# 2. Automatic Plan runs on PR
# Review plan in PR comment

# 3. Manually trigger Apply
# Go to: Actions → "Terraform Apply (Manual)" → Run workflow
# Enter PR number → Apply runs

# 4. If successful → Merge PR
# If failed → Fix code and retry
```

**Why this approach?**
- ✅ Test infrastructure before merging
- ✅ Can't merge until apply succeeds (branch protection)
- ✅ Complete control over when changes happen
- ✅ Easy rollback (just close PR)

See [Manual Workflow Guide](docs/MANUAL_TERRAFORM_WORKFLOW.md) for step-by-step instructions.

### ⚡ Quick Deploy (First Time Setup)

```bash
# 1. Install Terraform
brew install terraform  # macOS
# or: snap install terraform  # Linux

# 2. Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# 3. Deploy infrastructure
cd terraform/s3-cloudfront
terraform init
terraform apply

# 4. Generate and upload map
cd ../..
python main.py
aws s3 cp us_law_severity_map_interactive.html s3://us-law-severity-map/index.html
aws cloudfront create-invalidation --distribution-id YOUR_ID --paths "/*"
```

**Cost**: $1-5/month for 5-50 daily visitors (see [Cost Analysis](docs/AWS_COST_ANALYSIS.md))

### 🤖 GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Terraform Plan** | Automatic on PR | Shows infrastructure changes |
| **Terraform Apply** | Manual (you trigger) | Applies infrastructure changes |
| **Deploy to S3** | Manual | Deploys website HTML |
| **Terraform Destroy** | Manual with confirmation | Tears down infrastructure |

**Branch Protection**: The `main` branch requires successful Terraform Apply before merge!

### 🏗️ Infrastructure Stack

- **Hosting**: Amazon S3 (static website)
- **CDN**: CloudFront (global edge caching)
- **State Management**: S3 + DynamoDB (locking)
- **CI/CD**: GitHub Actions
- **IaC**: Terraform
- **Cost**: ~$1-5/month (mostly CloudFront)

### 📚 Complete Documentation

- 📘 [Manual Workflow Guide](docs/MANUAL_TERRAFORM_WORKFLOW.md) - **Recommended reading!**
- 🔀 [Workflow Comparison](docs/WORKFLOW_COMPARISON.md) - Compare 3 approaches
- 📖 [Workflows README](.github/workflows/README.md) - Quick reference
- 💰 [Cost Analysis](docs/AWS_COST_ANALYSIS.md) - Detailed pricing
- 🚀 [Deployment Guide](docs/DEPLOYMENT_QUICKSTART.md) - Step-by-step
- ☁️ [AWS Strategies](docs/AWS_DEPLOYMENT.md) - Architecture options

## 📊 Data Sources

### Geographic Data

- **US Census Bureau TIGER/Line Shapefiles**
- Dataset: `cb_2022_us_state_20m` (20m resolution)
- Source: https://www.census.gov/geographies/mapping-files/

### Crime Statistics (2022-2023 estimates)

- **Murder Rates**: FBI Uniform Crime Reporting (UCR) Program
- **Gun Death Rates**: CDC WONDER Database
- **Traffic Fatalities**: NHTSA Fatality Analysis Reporting System (FARS)
- **Incarceration**: Bureau of Justice Statistics (BJS)
- **Population**: US Census Bureau population estimates

## 📁 Project Structure

```
us-law-severity-map/
├── main.py                                    # Main visualization script
├── requirements.txt                           # Python dependencies
├── README.md                                  # This file
├── CHANGELOG.md                               # Version history
├── LICENSE                                    # MIT License
├── PROMPT.md                                  # AI recreation prompt
├── .github/
│   └── workflows/                             # GitHub Actions
│       ├── README.md                          # Workflows documentation
│       ├── terraform-pr-plan.yml              # Automatic plan on PR
│       ├── terraform-pr-apply.yml             # Manual apply workflow
│       ├── deploy-to-s3.yml                   # Deploy website to S3
│       └── terraform-destroy.yml              # Infrastructure teardown
├── terraform/
│   └── s3-cloudfront/                         # AWS infrastructure
│       ├── main.tf                            # Main Terraform config
│       ├── variables.tf                       # Input variables
│       ├── outputs.tf                         # Output values
│       ├── backend.tf                         # S3 state backend
│       └── README.md                          # Terraform docs
├── docs/                                      # Documentation
│   ├── MANUAL_TERRAFORM_WORKFLOW.md           # Recommended workflow guide
│   ├── WORKFLOW_COMPARISON.md                 # Compare workflow options
│   ├── AWS_DEPLOYMENT.md                      # Deployment strategies
│   ├── AWS_COST_ANALYSIS.md                   # Cost breakdown
│   └── DEPLOYMENT_QUICKSTART.md               # Quick start guide
├── github/                                    # GitHub configuration
│   ├── setup-branch-protection.sh             # Branch protection script
│   └── branch-protection-config.json          # Protection rules config
├── data/                                      # Auto-generated shapefiles
│   └── cb_2022_us_state_20m.*                # US Census shapefiles
└── us_law_severity_map_interactive.html      # Generated output
```

## 📦 Dependencies

Core Libraries:

- **geopandas** (≥0.14.0) - Geographic data manipulation
- **plotly** (≥5.18.0) - Interactive visualizations
- **requests** (≥2.31.0) - HTTP downloads
- **matplotlib** (≥3.8.0) - Plotting support
- **kaleido** (≥0.2.1) - Static image export

Geospatial Stack:

- **pandas**, **shapely**, **fiona**, **pyproj** (required by geopandas)

See `requirements.txt` for complete list with version constraints.

## 📊 Sample Statistics

### US National Averages (per 100,000 population):

- **Murder Rate**: ~7.2
- **Gun Death Rate**: ~14.8
- **Traffic Fatality Rate**: ~12.3
- **Incarceration Rate**: ~639

### Notable State Comparisons:

**Highest Murder Rates:**

- Mississippi (20.5), Louisiana (15.8), Alabama (12.9)

**Lowest Murder Rates:**

- New Hampshire (1.3), Maine (1.8), Vermont (2.2)

**Highest Gun Death Rates:**

- Mississippi (28.6), Louisiana (26.3), Alabama (26.4)

**Lowest Gun Death Rates:**

- Massachusetts (3.7), New York (5.4), New Jersey (5.2)

**Highest Incarceration Rates:**

- Louisiana (1,090), Oklahoma (1,050), Mississippi (1,030)

**Lowest Incarceration Rates:**

- Vermont (320), Massachusetts (340), Minnesota (370)

## ⚠️ Methodology & Disclaimer

**Severity scores are subjective estimates** based on comprehensive analysis of:

- Death penalty status, history, and execution statistics
- Sentencing guidelines and mandatory minimums
- Three strikes laws and habitual offender statutes
- Criminal justice reform initiatives
- Incarceration rates and prison populations
- Parole/probation policies
- Focus on punishment vs. rehabilitation

**Important Notes:**

- This project is for **educational and visualization purposes only**
- Scores are simplified representations of complex legal systems
- Crime statistics are estimates based on most recent available data
- Not all states report data uniformly or consistently
- Consult official state resources for legal information

## 🎯 Technical Highlights

### Performance Optimizations:

- Efficient shapefile caching
- Optimized GeoJSON conversion
- Lazy loading of geographic data
- CDN-based Plotly library (fast HTML loading)

### Modern Web Technologies:

- Plotly.js for interactive graphics
- Responsive mapbox integration
- HTML5 for standalone deployment
- CSS-based styling for professional appearance

## 🛣️ Roadmap

### Completed ✅

**Version 3.0.0 - AWS Deployment & Infrastructure:**
- [x] Complete AWS deployment with S3 + CloudFront
- [x] Terraform infrastructure as code
- [x] GitHub Actions CI/CD workflows
- [x] Manual apply workflow (safest approach)
- [x] Branch protection rules
- [x] Comprehensive deployment documentation
- [x] Cost analysis and optimization guides

**Version 2.0.0 - Interactive Visualization:**
- [x] Interactive choropleth map with Plotly
- [x] Click-to-zoom with statistics panel
- [x] Comprehensive state statistics display on click
- [x] Simplified hover (state names only)
- [x] Crime data integration (murder, gun, traffic)
- [x] Population and incarceration rates
- [x] Professional color scheme and design
- [x] HTML export with embedded JavaScript
- [x] Dynamic statistics panel updates

**Version 1.0.0 - Initial Release:**
- [x] Static choropleth map
- [x] Law severity scoring system
- [x] Death penalty data for all states

### Potential Future Enhancements 🚀

**Data & Analytics:**
- [ ] Time-series data showing changes over years
- [ ] Additional metrics (recidivism, prison conditions, reform index)
- [ ] County-level granularity
- [ ] Comparison mode (side-by-side states)
- [ ] Data export functionality (CSV, JSON)

**Infrastructure & DevOps:**
- [ ] Custom domain with Route53
- [ ] Automated testing for Terraform
- [ ] Multi-environment setup (dev/staging/prod)
- [ ] CloudWatch monitoring and alerts
- [ ] Automated cost reporting

**Features:**
- [ ] API integration for real-time data updates
- [ ] Mobile-optimized version
- [ ] Embed code for websites/blogs
- [ ] PDF report generation
- [ ] Share functionality (social media)

## 🤝 Contributing

Contributions are welcome! Areas where you can help:

### Data Improvements:

- More accurate or recent statistics
- Additional metrics and data sources
- Validation of existing scores
- Historical data for time-series analysis

### Features:

- New visualization types
- Enhanced interactivity
- Performance optimizations
- Mobile improvements

### Documentation:

- Methodology explanations
- Data source citations
- Tutorial videos
- Translation to other languages

**To contribute:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **US Census Bureau** - Geographic boundary data
- **FBI UCR Program** - Crime statistics
- **CDC WONDER** - Public health data
- **NHTSA** - Traffic safety data
- **Bureau of Justice Statistics** - Incarceration data
- **Plotly** - Interactive visualization framework
- **GeoPandas community** - Geospatial tools
- Criminal justice reform researchers and data journalists

## 📞 Contact & Support

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Start a discussion for questions or ideas
- **Security**: Report security vulnerabilities privately

---

**Disclaimer:** This map represents a simplified view of highly complex legal and social systems. The data is provided for educational and informational purposes. For authoritative legal information, always consult official state resources or qualified legal professionals.

**Made with ❤️ and Python** | Data-driven insights into the US criminal justice system
