#!/usr/bin/env python3
"""
US Law Severity Map Generator - Click-to-View Edition
Displays a modern, interactive choropleth map showing law severity and crime statistics by state.
Features: click-to-zoom with statistics panel, simplified hover, comprehensive data.
"""

import geopandas as gpd
import plotly.graph_objects as go
import requests
import zipfile
import os
import json
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
        print(f"✓ Shapefile already exists at {shapefile_path}")
        return shapefile_path

    print(f"📥 Downloading shapefile from US Census Bureau...")
    zip_path = os.path.join(SHAPEFILE_DIR, "states.zip")

    response = requests.get(SHAPEFILE_URL, stream=True)
    response.raise_for_status()

    with open(zip_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    print(f"📦 Extracting shapefile...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(SHAPEFILE_DIR)

    os.remove(zip_path)
    print(f"✓ Shapefile ready at {shapefile_path}")
    return shapefile_path

def get_state_statistics():
    """
    Return comprehensive statistics for each state including law severity and crime data.
    
    Data includes:
    - Law severity score (0-100)
    - Murder rate per 100k population (2022 FBI data estimates)
    - Gun death rate per 100k (CDC data estimates)
    - Traffic fatality rate per 100k (NHTSA data estimates)
    - Population (2023 estimates)
    - Incarceration rate per 100k
    """
    stats = {
        # Format: 'state': {severity, murder_rate, gun_death_rate, traffic_fatality_rate, population, incarceration_rate, death_penalty, notes}
        'AL': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 12.9, 'gun_death_rate': 26.4, 'traffic_fatality_rate': 20.1,
            'population': 5074296, 'incarceration_rate': 840, 
            'notes': 'High incarceration and violent crime rates'
        },
        'AK': {
            'severity': 30, 'category': 'Lenient', 'death_penalty': 'Abolished 1957',
            'murder_rate': 8.4, 'gun_death_rate': 24.5, 'traffic_fatality_rate': 10.3,
            'population': 733583, 'incarceration_rate': 740,
            'notes': 'Rehabilitative focus but high violent crime'
        },
        'AZ': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 8.9, 'gun_death_rate': 17.4, 'traffic_fatality_rate': 13.4,
            'population': 7359197, 'incarceration_rate': 820,
            'notes': 'Strict laws, active death penalty'
        },
        'AR': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 11.5, 'gun_death_rate': 22.6, 'traffic_fatality_rate': 18.2,
            'population': 3045637, 'incarceration_rate': 1010,
            'notes': 'Very high incarceration rate'
        },
        'CA': {
            'severity': 38, 'category': 'Lenient', 'death_penalty': 'Moratorium',
            'murder_rate': 5.7, 'gun_death_rate': 9.0, 'traffic_fatality_rate': 10.6,
            'population': 39538223, 'incarceration_rate': 550,
            'notes': 'Largest death row but executions suspended'
        },
        'CO': {
            'severity': 52, 'category': 'Moderate', 'death_penalty': 'Abolished 2020',
            'murder_rate': 6.5, 'gun_death_rate': 15.4, 'traffic_fatality_rate': 12.1,
            'population': 5773714, 'incarceration_rate': 630,
            'notes': 'Recently abolished death penalty'
        },
        'CT': {
            'severity': 30, 'category': 'Lenient', 'death_penalty': 'Abolished 2012',
            'murder_rate': 4.6, 'gun_death_rate': 6.6, 'traffic_fatality_rate': 8.9,
            'population': 3605944, 'incarceration_rate': 480,
            'notes': 'Progressive criminal justice reforms'
        },
        'DE': {
            'severity': 58, 'category': 'Moderate', 'death_penalty': 'Abolished 2016',
            'murder_rate': 8.4, 'gun_death_rate': 13.2, 'traffic_fatality_rate': 12.8,
            'population': 1018396, 'incarceration_rate': 650,
            'notes': 'Death penalty ruled unconstitutional'
        },
        'FL': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 6.9, 'gun_death_rate': 13.7, 'traffic_fatality_rate': 14.8,
            'population': 22244823, 'incarceration_rate': 770,
            'notes': 'High death row population'
        },
        'GA': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 10.2, 'gun_death_rate': 18.0, 'traffic_fatality_rate': 13.6,
            'population': 10912876, 'incarceration_rate': 900,
            'notes': 'Strict sentencing laws'
        },
        'HI': {
            'severity': 20, 'category': 'Lenient', 'death_penalty': 'Abolished 1957',
            'murder_rate': 2.9, 'gun_death_rate': 4.8, 'traffic_fatality_rate': 9.4,
            'population': 1455271, 'incarceration_rate': 490,
            'notes': 'Lowest violent crime rate, most progressive'
        },
        'ID': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 3.6, 'gun_death_rate': 16.7, 'traffic_fatality_rate': 15.8,
            'population': 1939033, 'incarceration_rate': 860,
            'notes': 'Firing squad available as execution method'
        },
        'IL': {
            'severity': 38, 'category': 'Lenient', 'death_penalty': 'Abolished 2011',
            'murder_rate': 9.1, 'gun_death_rate': 14.1, 'traffic_fatality_rate': 9.2,
            'population': 12812508, 'incarceration_rate': 520,
            'notes': 'Abolished after wrongful convictions scandal'
        },
        'IN': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 8.0, 'gun_death_rate': 16.7, 'traffic_fatality_rate': 12.9,
            'population': 6833037, 'incarceration_rate': 800,
            'notes': 'Conservative laws with active death penalty'
        },
        'IA': {
            'severity': 80, 'category': 'Severe', 'death_penalty': 'Abolished 1965',
            'murder_rate': 3.2, 'gun_death_rate': 11.2, 'traffic_fatality_rate': 11.4,
            'population': 3200517, 'incarceration_rate': 610,
            'notes': 'No death penalty but long sentences'
        },
        'KS': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 6.3, 'gun_death_rate': 15.1, 'traffic_fatality_rate': 13.2,
            'population': 2937880, 'incarceration_rate': 680,
            'notes': 'Death penalty on books, no executions since 1965'
        },
        'KY': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 8.8, 'gun_death_rate': 20.1, 'traffic_fatality_rate': 17.4,
            'population': 4505836, 'incarceration_rate': 920,
            'notes': 'Electric chair available as backup method'
        },
        'LA': {
            'severity': 95, 'category': 'Severe', 'death_penalty': 'Active',
            'murder_rate': 15.8, 'gun_death_rate': 26.3, 'traffic_fatality_rate': 18.4,
            'population': 4657757, 'incarceration_rate': 1090,
            'notes': 'Highest incarceration rate in the nation'
        },
        'ME': {
            'severity': 25, 'category': 'Lenient', 'death_penalty': 'Abolished 1887',
            'murder_rate': 1.8, 'gun_death_rate': 11.0, 'traffic_fatality_rate': 10.2,
            'population': 1385340, 'incarceration_rate': 370,
            'notes': 'Very low crime, early abolition'
        },
        'MD': {
            'severity': 55, 'category': 'Moderate', 'death_penalty': 'Abolished 2013',
            'murder_rate': 9.6, 'gun_death_rate': 15.0, 'traffic_fatality_rate': 8.5,
            'population': 6177224, 'incarceration_rate': 590,
            'notes': 'Recent criminal justice reforms'
        },
        'MA': {
            'severity': 28, 'category': 'Lenient', 'death_penalty': 'Abolished 1984',
            'murder_rate': 3.2, 'gun_death_rate': 3.7, 'traffic_fatality_rate': 5.1,
            'population': 7029917, 'incarceration_rate': 340,
            'notes': 'Lowest gun death rate, strong rehabilitation focus'
        },
        'MI': {
            'severity': 55, 'category': 'Moderate', 'death_penalty': 'Abolished 1846',
            'murder_rate': 7.6, 'gun_death_rate': 14.6, 'traffic_fatality_rate': 10.8,
            'population': 10077331, 'incarceration_rate': 620,
            'notes': 'First English-speaking jurisdiction to abolish death penalty'
        },
        'MN': {
            'severity': 45, 'category': 'Moderate', 'death_penalty': 'Abolished 1911',
            'murder_rate': 3.5, 'gun_death_rate': 9.3, 'traffic_fatality_rate': 7.8,
            'population': 5706494, 'incarceration_rate': 370,
            'notes': 'Strong emphasis on rehabilitation'
        },
        'MS': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 20.5, 'gun_death_rate': 28.6, 'traffic_fatality_rate': 22.2,
            'population': 2961279, 'incarceration_rate': 1030,
            'notes': 'Highest murder rate in the nation'
        },
        'MO': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 11.8, 'gun_death_rate': 23.9, 'traffic_fatality_rate': 14.7,
            'population': 6177957, 'incarceration_rate': 860,
            'notes': 'High execution rate'
        },
        'MT': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 4.5, 'gun_death_rate': 22.5, 'traffic_fatality_rate': 18.6,
            'population': 1122867, 'incarceration_rate': 720,
            'notes': 'High gun death rate'
        },
        'NE': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 3.7, 'gun_death_rate': 10.2, 'traffic_fatality_rate': 11.9,
            'population': 1961504, 'incarceration_rate': 540,
            'notes': 'Death penalty reinstated by referendum in 2016'
        },
        'NV': {
            'severity': 85, 'category': 'Severe', 'death_penalty': 'Active',
            'murder_rate': 10.2, 'gun_death_rate': 18.5, 'traffic_fatality_rate': 12.7,
            'population': 3104614, 'incarceration_rate': 840,
            'notes': 'High violent crime rate in urban areas'
        },
        'NH': {
            'severity': 50, 'category': 'Moderate', 'death_penalty': 'Abolished 2019',
            'murder_rate': 1.3, 'gun_death_rate': 9.3, 'traffic_fatality_rate': 9.1,
            'population': 1377529, 'incarceration_rate': 400,
            'notes': 'Lowest murder rate, last northeast state to abolish'
        },
        'NJ': {
            'severity': 32, 'category': 'Lenient', 'death_penalty': 'Abolished 2007',
            'murder_rate': 3.4, 'gun_death_rate': 5.2, 'traffic_fatality_rate': 6.4,
            'population': 9288994, 'incarceration_rate': 450,
            'notes': 'First state to abolish death penalty in 21st century'
        },
        'NM': {
            'severity': 48, 'category': 'Moderate', 'death_penalty': 'Abolished 2009',
            'murder_rate': 8.8, 'gun_death_rate': 24.2, 'traffic_fatality_rate': 16.8,
            'population': 2117522, 'incarceration_rate': 570,
            'notes': 'Progressive reforms, high gun death rate'
        },
        'NY': {
            'severity': 35, 'category': 'Lenient', 'death_penalty': 'Abolished 2007',
            'murder_rate': 4.2, 'gun_death_rate': 5.4, 'traffic_fatality_rate': 5.8,
            'population': 20201249, 'incarceration_rate': 380,
            'notes': 'Major criminal justice reforms in recent years'
        },
        'NC': {
            'severity': 88, 'category': 'Severe', 'death_penalty': 'Active',
            'murder_rate': 7.9, 'gun_death_rate': 16.1, 'traffic_fatality_rate': 13.6,
            'population': 10439388, 'incarceration_rate': 570,
            'notes': 'De facto moratorium on executions'
        },
        'ND': {
            'severity': 85, 'category': 'Severe', 'death_penalty': 'Abolished 1973',
            'murder_rate': 3.3, 'gun_death_rate': 13.4, 'traffic_fatality_rate': 13.2,
            'population': 779094, 'incarceration_rate': 430,
            'notes': 'Long sentences despite no death penalty'
        },
        'OH': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 6.3, 'gun_death_rate': 15.2, 'traffic_fatality_rate': 10.5,
            'population': 11799448, 'incarceration_rate': 730,
            'notes': 'Recent informal moratorium on executions'
        },
        'OK': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 9.2, 'gun_death_rate': 20.7, 'traffic_fatality_rate': 17.3,
            'population': 4019800, 'incarceration_rate': 1050,
            'notes': 'Highest execution rate per capita'
        },
        'OR': {
            'severity': 32, 'category': 'Lenient', 'death_penalty': 'Moratorium',
            'murder_rate': 4.5, 'gun_death_rate': 14.9, 'traffic_fatality_rate': 11.2,
            'population': 4237256, 'incarceration_rate': 600,
            'notes': 'Governor-imposed moratorium on executions'
        },
        'PA': {
            'severity': 58, 'category': 'Moderate', 'death_penalty': 'Moratorium',
            'murder_rate': 7.8, 'gun_death_rate': 13.6, 'traffic_fatality_rate': 10.1,
            'population': 13002700, 'incarceration_rate': 650,
            'notes': 'Large prison population, execution moratorium'
        },
        'RI': {
            'severity': 25, 'category': 'Lenient', 'death_penalty': 'Abolished 1984',
            'murder_rate': 3.5, 'gun_death_rate': 4.4, 'traffic_fatality_rate': 5.9,
            'population': 1097379, 'incarceration_rate': 410,
            'notes': 'Very progressive criminal justice system'
        },
        'SC': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 11.2, 'gun_death_rate': 22.8, 'traffic_fatality_rate': 19.4,
            'population': 5118425, 'incarceration_rate': 730,
            'notes': 'Recently added firing squad as execution method'
        },
        'SD': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 4.5, 'gun_death_rate': 13.5, 'traffic_fatality_rate': 16.2,
            'population': 886667, 'incarceration_rate': 590,
            'notes': 'Conservative laws, active death penalty'
        },
        'TN': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 10.6, 'gun_death_rate': 21.3, 'traffic_fatality_rate': 16.5,
            'population': 7051339, 'incarceration_rate': 870,
            'notes': 'Highly punitive justice system'
        },
        'TX': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 8.2, 'gun_death_rate': 14.7, 'traffic_fatality_rate': 13.2,
            'population': 30029572, 'incarceration_rate': 880,
            'notes': 'National leader in executions'
        },
        'UT': {
            'severity': 90, 'category': 'Severe', 'death_penalty': 'Active',
            'murder_rate': 2.8, 'gun_death_rate': 13.6, 'traffic_fatality_rate': 10.4,
            'population': 3380800, 'incarceration_rate': 410,
            'notes': 'Firing squad available, low crime rate'
        },
        'VT': {
            'severity': 22, 'category': 'Lenient', 'death_penalty': 'Abolished 1964',
            'murder_rate': 2.2, 'gun_death_rate': 11.6, 'traffic_fatality_rate': 9.8,
            'population': 643077, 'incarceration_rate': 320,
            'notes': 'Lowest incarceration rate, most progressive'
        },
        'VA': {
            'severity': 92, 'category': 'Severe', 'death_penalty': 'Abolished 2021',
            'murder_rate': 6.1, 'gun_death_rate': 13.4, 'traffic_fatality_rate': 9.6,
            'population': 8631393, 'incarceration_rate': 680,
            'notes': 'Former leader in executions, recently abolished'
        },
        'WA': {
            'severity': 35, 'category': 'Lenient', 'death_penalty': 'Abolished 2018',
            'murder_rate': 4.2, 'gun_death_rate': 10.9, 'traffic_fatality_rate': 8.4,
            'population': 7705281, 'incarceration_rate': 510,
            'notes': 'Death penalty ruled unconstitutional'
        },
        'WV': {
            'severity': 60, 'category': 'Moderate', 'death_penalty': 'Abolished 1965',
            'murder_rate': 7.8, 'gun_death_rate': 17.8, 'traffic_fatality_rate': 15.9,
            'population': 1793716, 'incarceration_rate': 610,
            'notes': 'Moderate laws, high drug-related crime'
        },
        'WI': {
            'severity': 50, 'category': 'Moderate', 'death_penalty': 'Abolished 1853',
            'murder_rate': 4.8, 'gun_death_rate': 11.8, 'traffic_fatality_rate': 11.2,
            'population': 5893718, 'incarceration_rate': 580,
            'notes': 'Balanced justice system'
        },
        'WY': {
            'severity': 100, 'category': 'Very Severe', 'death_penalty': 'Active',
            'murder_rate': 3.4, 'gun_death_rate': 25.9, 'traffic_fatality_rate': 22.6,
            'population': 576851, 'incarceration_rate': 710,
            'notes': 'Very high traffic fatality rate, active death penalty'
        },
    }
    return stats

def get_state_bounds(gdf, state_abbr):
    """Get the geographic bounds for a specific state."""
    state_geom = gdf[gdf['STUSPS'] == state_abbr].geometry.values[0]
    bounds = state_geom.bounds  # (minx, miny, maxx, maxy)
    
    # Calculate center and appropriate zoom
    center_lon = (bounds[0] + bounds[2]) / 2
    center_lat = (bounds[1] + bounds[3]) / 2
    
    # Calculate zoom level based on bounds size
    lon_range = bounds[2] - bounds[0]
    lat_range = bounds[3] - bounds[1]
    max_range = max(lon_range, lat_range)
    
    # Rough zoom calculation (adjust as needed)
    if max_range > 20:
        zoom = 3.5
    elif max_range > 10:
        zoom = 4.5
    elif max_range > 5:
        zoom = 5.5
    else:
        zoom = 6.5
    
    return center_lat, center_lon, zoom

def create_interactive_map():
    """Generate and display an advanced interactive US law severity map with click-to-view stats."""
    # Download shapefile
    shapefile_path = download_shapefile()

    # Load shapefile
    print("🗺️  Loading geographic data...")
    gdf = gpd.read_file(shapefile_path)

    # Filter to 50 states only
    us_states = {
        'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
        'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
        'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
        'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
        'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
    }
    gdf = gdf[gdf['STUSPS'].isin(us_states)]

    # Get state statistics
    state_stats = get_state_statistics()

    # Assign data to geodataframe
    for col in ['severity', 'category', 'death_penalty', 'murder_rate', 'gun_death_rate', 
                'traffic_fatality_rate', 'population', 'incarceration_rate', 'notes']:
        gdf[col] = gdf['STUSPS'].map(lambda x: state_stats.get(x, {}).get(col, 'N/A'))

    # Calculate US averages for context
    avg_murder = sum(s['murder_rate'] for s in state_stats.values()) / len(state_stats)
    avg_gun = sum(s['gun_death_rate'] for s in state_stats.values()) / len(state_stats)
    avg_traffic = sum(s['traffic_fatality_rate'] for s in state_stats.values()) / len(state_stats)

    # Create simple hover text (just state name)
    gdf['hover_text'] = (
        '<b>' + gdf['NAME'] + '</b> (' + gdf['STUSPS'] + ')<br>' +
        '<i>💡 Click state to zoom in and see details</i>' +
        '<extra></extra>'
    )

    # Prepare data for Plotly
    print("🎨 Creating interactive visualization with click-to-view statistics...")
    
    # Convert to JSON for Plotly
    gdf_json = json.loads(gdf.to_json())
    
    # Prepare state data as JSON for JavaScript
    state_data_dict = {}
    for idx, row in gdf.iterrows():
        state_data_dict[row['STUSPS']] = {
            'name': row['NAME'],
            'abbr': row['STUSPS'],
            'severity': int(row['severity']),
            'category': row['category'],
            'death_penalty': row['death_penalty'],
            'murder_rate': float(row['murder_rate']),
            'gun_death_rate': float(row['gun_death_rate']),
            'traffic_fatality_rate': float(row['traffic_fatality_rate']),
            'population': int(row['population']),
            'incarceration_rate': int(row['incarceration_rate']),
            'notes': row['notes']
        }
    
    # Create the figure with Plotly Choropleth
    fig = go.Figure(go.Choroplethmapbox(
        geojson=gdf_json,
        locations=gdf['STUSPS'],
        z=gdf['severity'],
        featureidkey="properties.STUSPS",
        colorscale=[
            [0.0, 'rgb(34, 139, 34)'],    # Forest green (lowest severity)
            [0.2, 'rgb(50, 205, 50)'],    # Lime green
            [0.4, 'rgb(255, 215, 0)'],    # Gold
            [0.6, 'rgb(255, 140, 0)'],    # Dark orange
            [0.8, 'rgb(220, 20, 60)'],    # Crimson
            [1.0, 'rgb(139, 0, 0)']       # Dark red (highest severity)
        ],
        text=gdf['hover_text'],
        hovertemplate='%{text}',
        colorbar=dict(
            title="<b>Severity<br>Score</b>",
            thickness=20,
            len=0.7,
            x=0.98,
            tickvals=[20, 40, 60, 80, 100],
            ticktext=['20<br>Lenient', '40', '60<br>Moderate', '80', '100<br>Very<br>Severe'],
            tickfont=dict(size=11, family='Arial, sans-serif'),
        ),
        marker_opacity=0.85,
        marker_line_width=1.5,
        marker_line_color='white',
        customdata=gdf['STUSPS']
    ))

    # Update layout
    fig.update_layout(
        title={
            'text': (
                '<b>🇺🇸 US Law Severity & Crime Statistics Map</b><br>'
                '<sub>Interactive visualization showing law severity, crime rates, and state statistics</sub><br>'
                '<sub style="color: #7f8c8d;">Click any state to zoom and view statistics | Double-click to reset | Hover for state names</sub>'
            ),
            'font': {'size': 24, 'family': 'Arial Black, Arial, sans-serif', 'color': '#2c3e50'},
            'x': 0.5,
            'xanchor': 'center',
            'y': 0.98,
            'yanchor': 'top'
        },
        mapbox_style="carto-positron",
        mapbox_zoom=3,
        mapbox_center={"lat": 37.0902, "lon": -95.7129},
        height=900,
        width=1600,
        paper_bgcolor='rgb(248, 249, 250)',
        font=dict(family='Arial, sans-serif', size=12, color='#34495e'),
        margin=dict(l=10, r=10, t=140, b=10),
        hoverlabel=dict(
            bgcolor="white",
            font_size=14,
            font_family="Arial, sans-serif",
            bordercolor="#2c3e50",
            align="left"
        )
    )

    # Add annotations for legend and instructions
    annotations = [
        # Legend box
        dict(
            text=(
                '<b>📊 STATISTICS GUIDE</b><br>'
                '━━━━━━━━━━━━━━━━━<br>'
                '<b>Severity Categories:</b><br>'
                '🔴 <b>100</b> = Very Severe (Death Penalty Active)<br>'
                '🟠 <b>80-95</b> = Severe (Long Sentences)<br>'
                '🟡 <b>40-60</b> = Moderate (Balanced)<br>'
                '🟢 <b>20-40</b> = Lenient (Rehabilitation Focus)<br>'
                '<br>'
                '<b>Crime Rates:</b> Per 100,000 population<br>'
                '<b>Incarceration:</b> Prisoners per 100,000<br>'
                '<br>'
                '<i>💡 US Averages:</i><br>'
                f'  Murder: {avg_murder:.1f} | Guns: {avg_gun:.1f}<br>'
                f'  Traffic: {avg_traffic:.1f} per 100k<br>'
                '<br>'
                '<b>Data Sources:</b> FBI UCR, CDC, NHTSA<br>'
                '<i>2022-2023 estimates</i>'
            ),
            xref="paper", yref="paper",
            x=0.01, y=0.99,
            xanchor='left', yanchor='top',
            showarrow=False,
            bgcolor='rgba(255, 255, 255, 0.95)',
            bordercolor='#2c3e50',
            borderwidth=2,
            borderpad=12,
            font=dict(size=11, family='Arial, sans-serif', color='#2c3e50'),
            align='left'
        ),
        # Instructions box
        dict(
            text=(
                '<b>🖱️ INTERACTION GUIDE</b><br>'
                '━━━━━━━━━━━━━━━━━<br>'
                '• <b>Click state</b> → Zoom & show stats<br>'
                '• <b>Double-click</b> → Reset zoom<br>'
                '• <b>Hover</b> → See state name<br>'
                '• <b>Scroll</b> → Zoom in/out<br>'
                '• <b>Drag</b> → Pan the map<br>'
                '<br>'
                '<i>Statistics panel appears on right!</i>'
            ),
            xref="paper", yref="paper",
            x=0.01, y=0.32,
            xanchor='left', yanchor='top',
            showarrow=False,
            bgcolor='rgba(255, 255, 255, 0.95)',
            bordercolor='#3498db',
            borderwidth=2,
            borderpad=12,
            font=dict(size=11, family='Arial, sans-serif', color='#2c3e50'),
            align='left'
        )
    ]
    
    fig.update_layout(annotations=annotations)

    print("✨ Generating interactive map with click-to-view functionality...")
    
    # Get the figure JSON and properly escape it
    fig_json = fig.to_json()
    
    # Create custom HTML with JavaScript for click handling
    html_template = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>US Law Severity & Crime Statistics Map</title>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>
        body {{
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
            background-color: #f8f9fa;
            overflow: hidden;
        }}
        #myDiv {{
            width: 100%;
            height: 100vh;
        }}
        #statsPanel {{
            position: fixed;
            top: 50%;
            right: 20px;
            transform: translateY(-50%);
            width: 380px;
            max-height: 80vh;
            overflow-y: auto;
            background: white;
            border: 3px solid #e74c3c;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            font-family: 'Courier New', monospace;
            font-size: 13px;
            line-height: 1.6;
            display: none;
            z-index: 1000;
            color: #2c3e50;
        }}
        #statsPanel.visible {{
            display: block;
            animation: slideIn 0.3s ease-out;
        }}
        @keyframes slideIn {{
            from {{
                opacity: 0;
                transform: translateY(-50%) translateX(50px);
            }}
            to {{
                opacity: 1;
                transform: translateY(-50%) translateX(0);
            }}
        }}
        #statsPanel h2 {{
            margin: 0 0 15px 0;
            padding-bottom: 10px;
            border-bottom: 2px solid #e74c3c;
            color: #e74c3c;
            font-size: 18px;
        }}
        #statsPanel .section {{
            margin: 15px 0;
            padding: 12px;
            background: #f8f9fa;
            border-radius: 6px;
        }}
        #statsPanel .section-title {{
            font-weight: bold;
            font-size: 14px;
            color: #2c3e50;
            margin-bottom: 8px;
            display: block;
        }}
        #statsPanel .stat-row {{
            margin: 5px 0;
        }}
        #statsPanel .stat-label {{
            font-weight: bold;
            color: #34495e;
        }}
        #statsPanel .stat-value {{
            color: #2c3e50;
        }}
        #statsPanel .us-avg {{
            color: #7f8c8d;
            font-size: 11px;
            font-style: italic;
            margin-left: 10px;
        }}
        #statsPanel .notes {{
            background: #fff3cd;
            padding: 10px;
            border-radius: 6px;
            border-left: 4px solid #ffc107;
            margin-top: 10px;
            font-size: 12px;
        }}
        #closePanel {{
            position: absolute;
            top: 15px;
            right: 15px;
            background: #e74c3c;
            color: white;
            border: none;
            border-radius: 50%;
            width: 30px;
            height: 30px;
            cursor: pointer;
            font-size: 18px;
            line-height: 1;
            font-weight: bold;
        }}
        #closePanel:hover {{
            background: #c0392b;
        }}
    </style>
</head>
<body>
    <div id="myDiv"></div>
    <div id="statsPanel">
        <button id="closePanel" onclick="closeStatsPanel()">×</button>
        <div id="panelContent"></div>
    </div>
    <script>
        // State data
        const stateData = {json.dumps(state_data_dict)};
        
        // US Averages
        const usAverages = {{
            murder: {avg_murder:.1f},
            gun: {avg_gun:.1f},
            traffic: {avg_traffic:.1f}
        }};
        
        // Plot data - embedded as JSON
        const plotData = {fig_json};
        const data = plotData.data;
        const layout = plotData.layout;
        const config = {{
            scrollZoom: true,
            displayModeBar: true,
            displaylogo: false,
            responsive: true
        }};
        
        // Create the plot
        Plotly.newPlot('myDiv', data, layout, config);
        
        // Get the plot div
        var myDiv = document.getElementById('myDiv');
        var statsPanel = document.getElementById('statsPanel');
        var panelContent = document.getElementById('panelContent');
        
        // State bounds for proper zoom centering (approximate center coordinates)
        const stateCenters = {{
            'AL': {{lat: 32.806671, lon: -86.791130, zoom: 6}},
            'AK': {{lat: 61.370716, lon: -152.404419, zoom: 3.5}},
            'AZ': {{lat: 33.729759, lon: -111.431221, zoom: 6}},
            'AR': {{lat: 34.969704, lon: -92.373123, zoom: 6}},
            'CA': {{lat: 36.116203, lon: -119.681564, zoom: 5}},
            'CO': {{lat: 39.059811, lon: -105.311104, zoom: 6}},
            'CT': {{lat: 41.597782, lon: -72.755371, zoom: 7.5}},
            'DE': {{lat: 39.318523, lon: -75.507141, zoom: 8}},
            'FL': {{lat: 27.766279, lon: -81.686783, zoom: 6}},
            'GA': {{lat: 33.040619, lon: -83.643074, zoom: 6}},
            'HI': {{lat: 21.094318, lon: -157.498337, zoom: 6.5}},
            'ID': {{lat: 44.240459, lon: -114.478828, zoom: 5.5}},
            'IL': {{lat: 40.349457, lon: -88.986137, zoom: 6}},
            'IN': {{lat: 39.849426, lon: -86.258278, zoom: 6.5}},
            'IA': {{lat: 42.011539, lon: -93.210526, zoom: 6.5}},
            'KS': {{lat: 38.526600, lon: -96.726486, zoom: 6}},
            'KY': {{lat: 37.668140, lon: -84.670067, zoom: 6.5}},
            'LA': {{lat: 31.169546, lon: -91.867805, zoom: 6}},
            'ME': {{lat: 44.693947, lon: -69.381927, zoom: 6}},
            'MD': {{lat: 39.063946, lon: -76.802101, zoom: 7}},
            'MA': {{lat: 42.230171, lon: -71.530106, zoom: 7}},
            'MI': {{lat: 43.326618, lon: -84.536095, zoom: 5.5}},
            'MN': {{lat: 45.694454, lon: -93.900192, zoom: 5.5}},
            'MS': {{lat: 32.741646, lon: -89.678696, zoom: 6}},
            'MO': {{lat: 38.456085, lon: -92.288368, zoom: 6}},
            'MT': {{lat: 46.921925, lon: -110.454353, zoom: 5}},
            'NE': {{lat: 41.125370, lon: -98.268082, zoom: 6}},
            'NV': {{lat: 38.313515, lon: -117.055374, zoom: 5.5}},
            'NH': {{lat: 43.452492, lon: -71.563896, zoom: 7}},
            'NJ': {{lat: 40.298904, lon: -74.521011, zoom: 7}},
            'NM': {{lat: 34.840515, lon: -106.248482, zoom: 5.5}},
            'NY': {{lat: 42.165726, lon: -74.948051, zoom: 6}},
            'NC': {{lat: 35.630066, lon: -79.806419, zoom: 6}},
            'ND': {{lat: 47.528912, lon: -99.784012, zoom: 6}},
            'OH': {{lat: 40.388783, lon: -82.764915, zoom: 6.5}},
            'OK': {{lat: 35.565342, lon: -96.928917, zoom: 6}},
            'OR': {{lat: 44.572021, lon: -122.070938, zoom: 6}},
            'PA': {{lat: 40.590752, lon: -77.209755, zoom: 6}},
            'RI': {{lat: 41.680893, lon: -71.511780, zoom: 8.5}},
            'SC': {{lat: 33.856892, lon: -80.945007, zoom: 6.5}},
            'SD': {{lat: 44.299782, lon: -99.438828, zoom: 6}},
            'TN': {{lat: 35.747845, lon: -86.692345, zoom: 6}},
            'TX': {{lat: 31.054487, lon: -97.563461, zoom: 5}},
            'UT': {{lat: 40.150032, lon: -111.862434, zoom: 6}},
            'VT': {{lat: 44.045876, lon: -72.710686, zoom: 7}},
            'VA': {{lat: 37.769337, lon: -78.169968, zoom: 6}},
            'WA': {{lat: 47.400902, lon: -121.490494, zoom: 6}},
            'WV': {{lat: 38.491226, lon: -80.954453, zoom: 6.5}},
            'WI': {{lat: 44.268543, lon: -89.616508, zoom: 6}},
            'WY': {{lat: 42.755966, lon: -107.302490, zoom: 6}}
        }};
        
        function closeStatsPanel() {{
            statsPanel.classList.remove('visible');
        }}
        
        // Add click event handler
        myDiv.on('plotly_click', function(eventData) {{
            if (eventData.points && eventData.points.length > 0) {{
                const point = eventData.points[0];
                const stateAbbr = point.location;
                const state = stateData[stateAbbr];
                const center = stateCenters[stateAbbr];
                
                if (state && center) {{
                    // Create detailed statistics panel HTML
                    const panelHTML = `
                        <h2>📍 ${{state.name}} (${{state.abbr}})</h2>
                        
                        <div class="section">
                            <span class="section-title">⚖️ LAW SEVERITY</span>
                            <div class="stat-row">
                                <span class="stat-label">Severity Score:</span>
                                <span class="stat-value">${{state.severity}}/100 (${{state.category}})</span>
                            </div>
                            <div class="stat-row">
                                <span class="stat-label">Death Penalty:</span>
                                <span class="stat-value">${{state.death_penalty}}</span>
                            </div>
                        </div>
                        
                        <div class="section">
                            <span class="section-title">📊 CRIME STATISTICS (per 100k)</span>
                            <div class="stat-row">
                                <span class="stat-label">Murder Rate:</span>
                                <span class="stat-value">${{state.murder_rate.toFixed(1)}}</span>
                                <span class="us-avg">(US avg: ${{usAverages.murder}})</span>
                            </div>
                            <div class="stat-row">
                                <span class="stat-label">Gun Deaths:</span>
                                <span class="stat-value">${{state.gun_death_rate.toFixed(1)}}</span>
                                <span class="us-avg">(US avg: ${{usAverages.gun}})</span>
                            </div>
                            <div class="stat-row">
                                <span class="stat-label">Traffic Deaths:</span>
                                <span class="stat-value">${{state.traffic_fatality_rate.toFixed(1)}}</span>
                                <span class="us-avg">(US avg: ${{usAverages.traffic}})</span>
                            </div>
                        </div>
                        
                        <div class="section">
                            <span class="section-title">📈 POPULATION & INCARCERATION</span>
                            <div class="stat-row">
                                <span class="stat-label">Population:</span>
                                <span class="stat-value">${{state.population.toLocaleString()}}</span>
                            </div>
                            <div class="stat-row">
                                <span class="stat-label">Incarceration Rate:</span>
                                <span class="stat-value">${{state.incarceration_rate}}/100k</span>
                            </div>
                        </div>
                        
                        <div class="notes">
                            <strong>📝 Note:</strong> ${{state.notes}}
                        </div>
                        
                        <div style="margin-top: 15px; text-align: center; color: #7f8c8d; font-size: 11px;">
                            <em>Double-click map to reset view</em>
                        </div>
                    `;
                    
                    // Update panel content and show it
                    panelContent.innerHTML = panelHTML;
                    statsPanel.classList.add('visible');
                    
                    // Zoom to state with proper centering
                    const newLayout = {{
                        ...layout,
                        mapbox: {{
                            ...layout.mapbox,
                            center: {{lat: center.lat, lon: center.lon}},
                            zoom: center.zoom
                        }}
                    }};
                    
                    Plotly.react('myDiv', data, newLayout, config);
                }}
            }}
        }});
        
        // Handle double-click to reset
        myDiv.on('plotly_doubleclick', function() {{
            // Reset zoom
            const resetLayout = {{
                ...layout,
                mapbox: {{
                    ...layout.mapbox,
                    center: {{"lat": 37.0902, "lon": -95.7129}},
                    zoom: 3
                }}
            }};
            Plotly.react('myDiv', data, resetLayout, config);
            
            // Hide stats panel
            closeStatsPanel();
        }});
    </script>
</body>
</html>
    """
    
    # Save as HTML
    output_file = "us_law_severity_map_interactive.html"
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_template)
    
    print(f"\n✅ Interactive map saved as '{output_file}'")
    print("💡 Open the HTML file in any modern browser!")
    print("📊 Click any state to zoom in and see detailed statistics!")
    
    # Open in browser
    import webbrowser
    webbrowser.open('file://' + os.path.abspath(output_file))

if __name__ == "__main__":
    print("=" * 70)
    print("  🇺🇸 US LAW SEVERITY & CRIME STATISTICS MAP")
    print("  Click-to-View Edition with Interactive Statistics")
    print("=" * 70)
    print()
    create_interactive_map()
    print()
    print("=" * 70)
    print("  ✨ Visualization complete! Click states to explore data.")
    print("=" * 70)
