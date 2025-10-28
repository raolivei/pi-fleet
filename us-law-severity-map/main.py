#!/usr/bin/env python3
"""
US Law Severity Map Generator
Displays a choropleth map of the United States showing law severity by state.
"""

import geopandas as gpd
import matplotlib.pyplot as plt
import requests
import zipfile
import os
from pathlib import Path

# URLs for US Census Bureau shapefiles (20m resolution)
SHAPEFILE_URL = "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_state_20m.zip"
SHAPEFILE_DIR = "data"
SHAPEFILE_NAME = "cb_2022_us_state_20m"

def download_shapefile():
    """Download and extract US states shapefile if not already present."""
    Path(SHAPEFILE_DIR).mkdir(exist_ok=True)
    shapefile_path = os.path.join(SHAPEFILE_DIR, f"{SHAPEFILE_NAME}.shp")

    if os.path.exists(shapefile_path):
        print(f"Shapefile already exists at {shapefile_path}")
        return shapefile_path

    print(f"Downloading shapefile from US Census Bureau...")
    zip_path = os.path.join(SHAPEFILE_DIR, "states.zip")

    response = requests.get(SHAPEFILE_URL, stream=True)
    response.raise_for_status()

    with open(zip_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    print(f"Extracting shapefile...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(SHAPEFILE_DIR)

    os.remove(zip_path)
    print(f"Shapefile ready at {shapefile_path}")
    return shapefile_path

def get_severity_scores():
    """
    Return a dictionary mapping state abbreviations to severity scores.

    Scoring criteria:
    - 100: Active death penalty states (most severe)
    - 80-95: Severe laws without death penalty
    - 40-60: Moderate laws
    - 20-40: More lenient, rehabilitation-focused states
    """
    scores = {
        # Death penalty states (100)
        'TX': 100, 'FL': 100, 'AL': 100, 'GA': 100, 'MO': 100,
        'AZ': 100, 'OK': 100, 'MS': 100, 'SC': 100, 'AR': 100,
        'OH': 100, 'TN': 100, 'SD': 100, 'ID': 100, 'WY': 100,
        'MT': 100, 'KS': 100, 'NE': 100, 'KY': 100, 'IN': 100,

        # Severe without death penalty (80-95)
        'UT': 90, 'LA': 95, 'ND': 85, 'IA': 80, 'NC': 88,
        'VA': 92, 'NV': 85,

        # Moderate states (40-60)
        'MI': 55, 'PA': 58, 'WI': 50, 'MN': 45, 'CO': 52,
        'NM': 48, 'WV': 60, 'MD': 55, 'NH': 50, 'DE': 58,

        # Lenient/rehabilitation-focused states (20-40)
        'NY': 35, 'IL': 38, 'NJ': 32, 'MA': 28, 'CT': 30,
        'RI': 25, 'VT': 22, 'ME': 25, 'HI': 20, 'AK': 30,
        'WA': 35, 'OR': 32, 'CA': 38,
    }
    return scores

def create_severity_map():
    """Generate and display the US law severity map."""
    # Download shapefile
    shapefile_path = download_shapefile()

    # Load shapefile
    print("Loading geographic data...")
    gdf = gpd.read_file(shapefile_path)

    # Filter to 50 states only (remove territories, DC, etc.)
    # Keep only states with STUSPS (state abbreviation) in standard 50 states
    us_states = {
        'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
        'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
        'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
        'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
        'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
    }
    gdf = gdf[gdf['STUSPS'].isin(us_states)]

    # Get severity scores
    scores = get_severity_scores()

    # Assign severity to each state (default 50 for unlisted states)
    gdf['severity'] = gdf['STUSPS'].map(lambda x: scores.get(x, 50))

    # Create the map
    print("Generating map...")
    fig, ax = plt.subplots(1, 1, figsize=(16, 10))

    # Plot with severity colors
    gdf.plot(
        column='severity',
        cmap='Reds',
        linewidth=0.8,
        ax=ax,
        edgecolor='0.2',
        legend=True,
        legend_kwds={
            'label': "Severidade (0-100)",
            'orientation': "vertical",
            'shrink': 0.5
        }
    )

    # Set title and clean up axes
    ax.set_title(
        'Severidade das Leis por Estado (EUA)',
        fontsize=20,
        fontweight='bold',
        pad=20
    )
    ax.axis('off')

    # Add note
    fig.text(
        0.5, 0.02,
        'Escuro = Mais Severo | Claro = Mais Brando\n'
        'Baseado em pena de morte, sentenças, foco em reabilitação',
        ha='center',
        fontsize=10,
        style='italic'
    )

    plt.tight_layout()
    print("Displaying map...")
    plt.show()

    print("\nMap generation complete!")

if __name__ == "__main__":
    create_severity_map()
