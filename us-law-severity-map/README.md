# US Law Severity Map

A data visualization project that generates an interactive choropleth map of the United States showing the relative severity of criminal justice laws by state.

![US Law Severity Map](screenshot.png)
*Screenshot placeholder - map shows severity gradient from light (lenient) to dark red (severe)*

## Overview

This project creates a color-coded map of all 50 US states based on the severity of their criminal justice systems. The severity score takes into account factors such as:

- Death penalty status and usage
- Mandatory minimum sentencing laws
- Three strikes laws
- Focus on punishment vs. rehabilitation
- Incarceration rates and sentencing guidelines

The map uses a **red gradient** color scheme where:
- **Dark red** = Most severe laws
- **Light red/pink** = More lenient laws

## Severity Scoring System

### 100 - Death Penalty States (Most Severe)
States with active death penalty statutes and recent executions:
- Texas, Florida, Alabama, Georgia, Missouri, Arizona, Oklahoma, Mississippi, South Carolina, Arkansas, Ohio, Tennessee, South Dakota, Idaho, Wyoming, Montana, Kansas, Nebraska, Kentucky, Indiana

### 80-95 - Severe Without Death Penalty
States with strict sentencing but no death penalty:
- Utah (90), Louisiana (95), North Dakota (85), Iowa (80), North Carolina (88), Virginia (92), Nevada (85)

### 40-60 - Moderate
States with balanced approaches to criminal justice:
- Michigan (55), Pennsylvania (58), Wisconsin (50), Minnesota (45), Colorado (52), New Mexico (48), West Virginia (60), Maryland (55), New Hampshire (50), Delaware (58)

### 20-40 - Lenient/Rehabilitation-Focused
States that emphasize rehabilitation and have abolished the death penalty:
- Hawaii (20), Vermont (22), Rhode Island (25), Maine (25), Massachusetts (28), Connecticut (30), Alaska (30), New Jersey (32), Oregon (32), New York (35), Washington (35), California (38), Illinois (38)

**Default Score:** States not explicitly listed receive a default score of 50 (moderate).

## Installation

### Prerequisites
- Python 3.8 or higher
- pip package manager

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/us-law-severity-map.git
   cd us-law-severity-map
   ```

2. **Create a virtual environment (recommended):**
   ```bash
   python -m venv venv

   # On macOS/Linux:
   source venv/bin/activate

   # On Windows:
   venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Usage

Simply run the main script:

```bash
python main.py
```

The script will:
1. Download the official US Census Bureau shapefile (20m resolution) if not already present
2. Filter to show only the 50 US states (excluding territories and DC)
3. Apply severity scores to each state
4. Generate and display the interactive map

The map will open in a new window. You can zoom, pan, and save the image using matplotlib's built-in controls.

## Data Source

Geographic data is sourced from the **US Census Bureau TIGER/Line Shapefiles**:
- Dataset: `cb_2022_us_state_20m` (20m resolution)
- Source: https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.html

Shapefiles are automatically downloaded and cached in the `data/` directory.

## Project Structure

```
us-law-severity-map/
├── main.py              # Main script to generate the map
├── requirements.txt     # Python dependencies
├── README.md           # This file
├── LICENSE             # MIT License
├── data/               # Auto-generated directory for shapefiles
└── screenshot.png      # Example output (to be added)
```

## Dependencies

- **geopandas**: Geographic data manipulation and visualization
- **matplotlib**: Plotting and visualization
- **requests**: Download shapefiles from US Census Bureau

## Methodology & Disclaimer

The severity scores in this project are **subjective estimates** based on publicly available information about:
- Death penalty status and execution statistics
- Sentencing guidelines and mandatory minimums
- Criminal justice reform initiatives
- Incarceration rates

**This project is for educational and visualization purposes only.** Severity scores are simplified representations and do not capture the full complexity of each state's criminal justice system.

## Future Enhancements

Potential improvements to this project:
- [ ] Add interactive tooltips showing state names and exact scores
- [ ] Include source data and methodology for each state's score
- [ ] Create web-based interactive version using Plotly or Folium
- [ ] Add time-series data to show changes over years
- [ ] Include additional metrics (incarceration rates, recidivism, etc.)
- [ ] Export high-resolution maps for publication

## Contributing

Contributions are welcome! If you have:
- More accurate data sources for severity scores
- Additional metrics to include
- Bug fixes or performance improvements
- Better visualization ideas

Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Geographic data provided by the US Census Bureau
- Inspired by criminal justice reform research and data journalism

---

**Note:** This map represents a simplified view of complex legal systems. For accurate legal information, consult official state resources or legal professionals.
