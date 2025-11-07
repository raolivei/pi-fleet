# AI Prompt: Recreate US Law Severity Map Project

This prompt can be used with AI assistants (Claude, ChatGPT, etc.) to recreate this entire project from scratch.

---

## Main Prompt

```
Create a complete, professional data visualization project that displays US law severity
by state with comprehensive crime statistics. The project should be production-ready
with AWS deployment infrastructure.

PROJECT SPECIFICATIONS:

1. INTERACTIVE MAP FEATURES:
   - Choropleth map of all 50 US states
   - Click-to-zoom functionality with state-specific centering
   - Hover shows state name only
   - Click displays detailed statistics panel (squared box overlay on right side)
   - Double-click resets view and clears panel
   - Color gradient: green (lenient) → yellow → orange → red (severe)
   - Professional UI with smooth animations

2. DATA TO DISPLAY:

   Law Severity Metrics:
   - Severity score (0-100 scale):
     * 100: Very Severe (death penalty active)
     * 80-95: Severe (long sentences)
     * 40-60: Moderate (balanced approach)
     * 20-40: Lenient (rehabilitation focus)
   - Death penalty status (Active/Abolished/Moratorium)

   Crime Statistics (per 100,000 population):
   - Murder rate (with US average comparison)
   - Gun death rate (with US average comparison)
   - Traffic fatality rate (with US average comparison)

   Demographics:
   - Population (2023 estimates)
   - Incarceration rate (per 100k)

   Contextual Information:
   - Historical notes for each state
   - Notable policies and facts

3. TECHNICAL STACK:
   - Python 3.8+ with virtual environment
   - Plotly for interactive visualizations (NOT matplotlib)
   - GeoPandas for geographic data handling
   - US Census Bureau shapefiles (automatic download)
   - HTML/CSS/JavaScript for overlay panel
   - All text in English

4. USER INTERFACE:
   - Statistics panel as HTML overlay (not Plotly annotation)
   - Fixed position on right side, vertically centered
   - Width: 380px, scrollable if needed
   - Red border (3px), rounded corners (12px)
   - Drop shadow for depth
   - Close button (×) in top right
   - Organized sections with icons:
     * ⚖️ Law Severity
     * 📊 Crime Statistics
     * 📈 Population & Incarceration
     * 📝 Notes (yellow highlighted box)
   - Smooth slide-in animation
   - Clean, professional design

5. AWS DEPLOYMENT INFRASTRUCTURE:

   Terraform (Infrastructure as Code):
   - S3 bucket for static website hosting
   - CloudFront CDN distribution with caching
   - Bucket policies for public read access
   - Versioning enabled on S3
   - Origin Access Identity for security
   - Variables for easy configuration

   GitHub Actions CI/CD:
   - Automatic deployment on push to main branch
   - Python environment setup
   - Dependency installation from requirements.txt
   - Generate map HTML file
   - Sync to S3 with proper exclusions
   - Invalidate CloudFront cache
   - Use secrets for AWS credentials

   Cost Optimization:
   - Target: $0.00-$0.50/month for 5-50 visits/day
   - Use free tier eligible services
   - Enable compression
   - Proper cache headers
   - S3 lifecycle policies

6. DOCUMENTATION REQUIRED:

   README.md:
   - Project overview with features
   - Installation instructions
   - Usage guide (local and AWS)
   - Data sources and methodology
   - Interaction guide
   - Contributing guidelines

   CHANGELOG.md:
   - Version history (currently v2.0.0)
   - Added/Changed/Fixed format
   - Keep it concise

   AWS_DEPLOYMENT.md:
   - Multiple deployment options
   - S3 + CloudFront (recommended)
   - AWS Amplify alternative
   - Lambda + API Gateway (future)
   - EKS comparison (not recommended for this scale)
   - Security best practices
   - Monitoring and cost tracking

   AWS_COST_ANALYSIS.md:
   - Detailed breakdown by service
   - Monthly and annual projections
   - Scaling scenarios
   - Comparison with alternatives
   - Cost optimization tips

   DEPLOYMENT_QUICKSTART.md:
   - 3 deployment options with step-by-step
   - Manual S3 (5 min)
   - Terraform (10 min)
   - AWS Amplify (2 min)
   - Troubleshooting section

   COST_SUMMARY.txt:
   - ASCII table format
   - Visual cost breakdown
   - Free tier benefits
   - Scaling scenarios
   - Service comparisons

7. PROJECT STRUCTURE:
```

us-law-severity-map/
├── main.py # Main application
├── requirements.txt # Python dependencies
├── README.md # Main documentation
├── CHANGELOG.md # Version history
├── PROMPT.md # This file
├── LICENSE # MIT License
├── .gitignore # Git ignore rules
├── data/ # Auto-downloaded shapefiles
├── docs/ # Documentation
│ ├── AWS_DEPLOYMENT.md
│ ├── AWS_COST_ANALYSIS.md
│ ├── DEPLOYMENT_QUICKSTART.md
│ └── COST_SUMMARY.txt
├── aws/ # AWS configurations
│ └── s3-bucket-policy.json
├── terraform/ # Infrastructure as Code
│ └── s3-cloudfront/
│ ├── main.tf
│ ├── variables.tf
│ └── README.md
└── .github/ # CI/CD workflows
└── workflows/
└── deploy-to-s3.yml

````

8. STATE DATA (All 50 states with complete info):
- Use realistic estimates for crime statistics
- Murder rates: 1.3 (NH) to 20.5 (MS)
- Gun death rates: 3.7 (MA) to 28.6 (MS)
- Traffic fatalities: 5.1 (MA) to 22.6 (WY)
- Include all death penalty states correctly
- Add historical context for each state

9. KEY IMPLEMENTATION DETAILS:

JavaScript Event Handling:
- Use Plotly's .on('plotly_click') for state clicks
- Proper event delegation
- Update HTML overlay dynamically
- Smooth map re-centering with state-specific coordinates
- Handle double-click for reset

State Centering:
- Each state has specific lat/lon center coordinates
- Appropriate zoom levels (3.5-8.5) based on state size
- Smaller states (RI, DE) get higher zoom
- Large states (AK, TX) get lower zoom

CSS Animations:
- Slide-in effect for statistics panel
- Transform and opacity transitions
- Smooth 0.3s ease-out timing

Data Embedding:
- State data as JSON in JavaScript
- Proper JSON escaping in f-strings
- US averages pre-calculated
- Efficient data access

10. REQUIREMENTS.TXT CONTENTS:
 ```
 geopandas>=0.14.0,<1.0.0
 matplotlib>=3.8.0,<4.0.0
 requests>=2.31.0,<3.0.0
 plotly>=5.18.0,<6.0.0
 kaleido>=0.2.1,<1.0.0
 pandas>=2.1.0,<3.0.0
 shapely>=2.0.0,<3.0.0
 fiona>=1.9.0,<2.0.0
 pyproj>=3.6.0,<4.0.0
 ```

11. GITHUB ACTIONS WORKFLOW:
 - Trigger on push to main
 - Python 3.11 environment
 - Install dependencies with pip cache
 - Generate map with main.py
 - Configure AWS credentials from secrets
 - Sync to S3 with exclusions
 - Invalidate CloudFront cache
 - Use proper AWS CLI commands

12. TERRAFORM CONFIGURATION:
 - Provider: AWS (~> 5.0)
 - S3 bucket with website configuration
 - Public access block settings
 - Bucket policy for public read
 - Versioning enabled
 - CloudFront with OAI
 - Price class: PriceClass_100 (North America/Europe)
 - HTTPS redirect
 - Compression enabled
 - Outputs: bucket name, website endpoint, CloudFront domain

13. QUALITY REQUIREMENTS:
 - Professional code with comments
 - Type hints where appropriate
 - Error handling for shapefile download
 - Responsive design
 - Cross-browser compatibility
 - No linter errors
 - Clean git history
 - Proper .gitignore

14. IMPORTANT NOTES:
 - DO NOT use matplotlib for the main visualization
 - DO use Plotly Mapbox for interactivity
 - Statistics panel MUST be HTML overlay, not Plotly annotation
 - All text in English (no Portuguese)
 - Cost target: $0.00-$0.50/month
 - Free tier eligible architecture
 - Click should zoom AND show stats simultaneously
 - Double-click should reset AND hide stats
 - Use state-specific zoom centers, not generic zoom

15. TESTING CHECKLIST:
 - [ ] Map loads without errors
 - [ ] All 50 states clickable
 - [ ] Statistics panel appears on click
 - [ ] Panel positioned correctly (right side, centered)
 - [ ] Close button works
 - [ ] Double-click resets view
 - [ ] Zoom centers correctly on each state
 - [ ] US averages calculated correctly
 - [ ] All data displays properly
 - [ ] HTML exports correctly
 - [ ] Terraform deploys successfully
 - [ ] GitHub Actions workflow runs
 - [ ] No console errors in browser

DELIVERABLES:
1. Complete working Python application
2. Interactive HTML map file
3. Full AWS deployment infrastructure
4. Comprehensive documentation
5. CI/CD pipeline configured
6. Cost analysis documentation
7. Git repository ready to push

OUTPUT FORMAT:
- Start with project structure
- Create all files in order
- Test locally before AWS deployment
- Provide step-by-step deployment instructions
- Include cost estimates
````

---

## Usage Instructions

### With Claude (Anthropic)

```
Copy the entire "Main Prompt" section above and paste it into a new Claude conversation.
Claude has excellent code generation and can handle complex multi-file projects.
```

### With ChatGPT (OpenAI)

```
Copy the prompt and paste into ChatGPT-4 or ChatGPT-4 Turbo.
May need to break into smaller parts for very long conversations.
Use Code Interpreter for testing the Python code.
```

### With Cursor AI

```
Open Cursor IDE and use Composer mode.
Paste the prompt to generate all files in your workspace.
Cursor can directly create the file structure and edit multiple files.
```

### Tips for Best Results

1. **Start Fresh**: Use a new conversation to avoid context confusion

2. **Specify Environment**:

   ```
   Additional context: I'm on macOS with Python 3.11 installed.
   AWS CLI is configured. I want to use Terraform for deployment.
   ```

3. **Request Step-by-Step**:

   ```
   After generating the code, walk me through:
   1. Local setup and testing
   2. Terraform deployment
   3. GitHub Actions configuration
   ```

4. **Ask for Clarifications**:

   ```
   Before starting, confirm:
   - What Python version do you recommend?
   - Should I create a virtual environment?
   - What AWS region should I use?
   ```

5. **Iterate on Design**:
   ```
   The statistics panel looks good, but can you:
   - Make the border thicker
   - Add more spacing between sections
   - Change the color scheme to blue
   ```

---

## Key Success Factors

### ✅ Must Have

- Plotly for interactivity (NOT matplotlib static map)
- HTML overlay for statistics panel (NOT Plotly annotation)
- State-specific zoom coordinates for all 50 states
- Click shows stats + zooms simultaneously
- Double-click resets + hides stats
- All text in English
- Complete AWS infrastructure
- GitHub Actions CI/CD
- Comprehensive documentation

### ❌ Common Mistakes to Avoid

- Using matplotlib instead of Plotly
- Using Plotly annotations instead of HTML overlay
- Generic zoom that doesn't center properly
- Missing state data
- Incomplete documentation
- No cost analysis
- Portuguese text in code/docs
- Missing Terraform files
- No CI/CD pipeline

---

## Customization Options

After generating the base project, you can request:

### Visual Enhancements

```
Make the map more visually appealing by:
- Adding a gradient background
- Improving the color scheme
- Adding drop shadows to states
- Better typography
```

### Additional Features

```
Add these features:
- Search bar to find states
- Filter by severity category
- Export data as CSV
- Time-series animation
- Comparison mode (2 states side-by-side)
```

### Infrastructure Improvements

```
Enhance the AWS setup:
- Add custom domain with Route53
- Enable CloudWatch monitoring
- Set up cost alerts
- Add staging environment
- Implement blue-green deployment
```

---

## Version Information

- **Current Version**: 2.0.0
- **Created**: October 29, 2025
- **Last Updated**: October 29, 2025
- **Tested With**: Claude 3.5 Sonnet, Python 3.11, Terraform 1.0+

---

## Expected Outcomes

After using this prompt, you should have:

1. ✅ **Functional Project**

   - Interactive map working locally
   - All 50 states with complete data
   - Professional UI with animations

2. ✅ **AWS Infrastructure**

   - Terraform files ready to deploy
   - GitHub Actions workflow configured
   - Estimated cost: $0.00-$0.50/month

3. ✅ **Complete Documentation**

   - README with instructions
   - Deployment guides
   - Cost analysis
   - Changelog

4. ✅ **Production Ready**
   - No linter errors
   - Cross-browser compatible
   - Mobile responsive
   - Proper error handling

---

## Troubleshooting

If the AI generates incorrect code:

1. **Re-iterate Requirements**:

   ```
   The map needs to use Plotly, not matplotlib.
   Please regenerate using plotly.graph_objects.Choroplethmapbox
   ```

2. **Request Specific Fixes**:

   ```
   The statistics panel is not showing. The issue is that it should be
   an HTML div element, not a Plotly annotation. Please fix.
   ```

3. **Ask for Explanations**:
   ```
   Why did you choose this approach for state centering?
   Can you explain the zoom level calculation?
   ```

---

## Maintenance

To keep this prompt updated:

1. **After Major Changes**: Update the specifications
2. **New Features**: Add to "Customization Options"
3. **Version Bumps**: Update version information
4. **Lessons Learned**: Add to "Common Mistakes to Avoid"

---

## License

This prompt is part of the US Law Severity Map project and is licensed under MIT.
Feel free to modify and use for your own projects.

---

**Repository**: https://github.com/raolivei/us-law-severity-map  
**Contact**: Open an issue on GitHub for questions or improvements
