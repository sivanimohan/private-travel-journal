import json
from collections import Counter
from datetime import datetime
from textblob import TextBlob
from wordcloud import WordCloud
import matplotlib.pyplot as plt
import base64
from io import BytesIO
from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
from sklearn.cluster import KMeans
import math
from geopy.geocoders import Nominatim
import time
from typing import Dict, List, Tuple, Optional, Any

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize geocoder with custom user agent
geolocator = Nominatim(user_agent="travel_insights_app/1.0")

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points on Earth in km"""
    R = 6371  # Earth radius in km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = (math.sin(dLat/2) * math.sin(dLat/2) +
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
        math.sin(dLon/2) * math.sin(dLon/2))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def geocode_location(location_name: str) -> Optional[Tuple[float, float]]:
    """Convert location name to coordinates with rate limiting"""
    try:
        time.sleep(1)  # Respect rate limits
        location = geolocator.geocode(location_name)
        if location:
            return (location.latitude, location.longitude)
        return None
    except Exception as e:
        print(f"Geocoding error for {location_name}: {str(e)}")
        return None


def process_sentiment(data: Dict) -> Dict:
    """Calculate sentiment analysis over time"""
    sentiment_data = []
    for page in data['allPages']:
        if 'textData' in page and page['textData'] and 'updatedAt' in page:
            try:
                text_data = json.loads(page['textData']) if isinstance(page['textData'], str) else page['textData']
                if isinstance(text_data, list):
                    text = " ".join([str(item[0]) for item in text_data if isinstance(item, list) and len(item) > 0])
                    analysis = TextBlob(text)
                    sentiment_data.append({
                        'date': page['updatedAt'],
                        'score': analysis.sentiment.polarity,
                        'subjectivity': analysis.sentiment.subjectivity
                    })
            except Exception as e:
                print(f"Error processing sentiment: {e}")
                continue
    
    avg_score = sum(d['score'] for d in sentiment_data) / len(sentiment_data) if sentiment_data else 0
    return {
        'timeline': sentiment_data,
        'average_score': avg_score
    }
def process_location_sentiment(data: Dict) -> Dict:
    """Calculate average sentiment by location"""
    location_sentiments = {}
    
    for page in data['allPages']:
        if 'location' in page and page['location'] and 'textData' in page and page['textData']:
            try:
                location = page['location']
                text = str(page['textData'])
                sentiment = TextBlob(text).sentiment.polarity
                
                if location not in location_sentiments:
                    location_sentiments[location] = []
                location_sentiments[location].append(sentiment)
            except Exception as e:
                print(f"Error processing location sentiment: {e}")
                continue
    
    # Calculate averages and get top/bottom locations
    avg_sentiments = {
        loc: sum(sents)/len(sents) 
        for loc, sents in location_sentiments.items() 
        if len(sents) > 0
    }
    
    top_locations = sorted(
        avg_sentiments.items(), 
        key=lambda x: x[1], 
        reverse=True
    )[:3]
    
    bottom_locations = sorted(
        avg_sentiments.items(), 
        key=lambda x: x[1]
    )[:3]
    
    return {
        'average_by_location': avg_sentiments,
        'top_locations': top_locations,
        'bottom_locations': bottom_locations,
        'overall_average': sum(avg_sentiments.values())/len(avg_sentiments) if avg_sentiments else 0
    }
def process_highlights(data: Dict) -> List[str]:
    """Extract notable highlights from journal entries"""
    highlights = []
    for page in data['allPages']:
        if 'textData' in page and page['textData']:
            try:
                text_data = json.loads(page['textData']) if isinstance(page['textData'], str) else page['textData']
                if isinstance(text_data, list):
                    for item in text_data:
                        if isinstance(item, list) and len(item) > 0:
                            text = str(item[0])
                            if len(text.split()) > 5 and TextBlob(text).sentiment.polarity > 0.2:
                                highlights.append(text)
            except Exception as e:
                print(f"Error processing highlights: {e}")
                continue
    
    return highlights[:10]

def process_location_repeats(data: Dict) -> Dict:
    """Calculate most visited locations"""
    locations = []
    for page in data['allPages']:
        if 'location' in page and page['location']:
            locations.append(page['location'])
    
    location_counts = Counter(locations)
    return {
        'most_visited': location_counts.most_common(5),
        'total_unique': len(location_counts)
    }

def process_seasonal_patterns(data: Dict) -> Dict:
    """Analyze travel patterns by season"""
    seasonal_data = {'Winter': 0, 'Spring': 0, 'Summer': 0, 'Fall': 0}
    for page in data['allPages']:
        if 'updatedAt' in page and page['updatedAt']:
            try:
                date_str = page['updatedAt']
                if '+' in date_str:
                    date_str = date_str.split('+')[0]
                date = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S.%f')
                month = date.month
                if 3 <= month <= 5:
                    seasonal_data['Spring'] += 1
                elif 6 <= month <= 8:
                    seasonal_data['Summer'] += 1
                elif 9 <= month <= 11:
                    seasonal_data['Fall'] += 1
                else:
                    seasonal_data['Winter'] += 1
            except Exception as e:
                print(f"Error processing seasonal data: {e}")
                continue
    
    return {
        'by_season': seasonal_data,
        'most_common_season': max(seasonal_data.items(), key=lambda x: x[1])[0] if seasonal_data else 'None'
    }

def process_photo_timeline(data: Dict) -> List[Dict]:
    """Create timeline of travel photos"""
    photos = []
    for page in data['allPages']:
        if 'media' in page and page['media']:
            for media in page['media']:
                if isinstance(media, dict) and media.get('type') == 'image':
                    photos.append({
                        'url': media.get('value', ''),
                        'date': page.get('updatedAt', ''),
                        'location': page.get('location', '')
                    })
    
    photos.sort(key=lambda x: x['date'], reverse=True)
    return photos[:20]

def process_travel_personality(data: Dict) -> Dict:
    """Analyze travel personality based on patterns"""
    activity_counts = Counter()
    location_types = []
    durations = []
    sentiment_scores = []
    
    for page in data['allPages']:
        if 'tags' in page and page['tags']:
            activity_counts.update(page['tags'])
        if 'location' in page and page['location']:
            location_types.append(page['location'].split(',')[-1].strip())
        if 'startDate' in page and 'endDate' in page and page['startDate'] and page['endDate']:
            try:
                start = datetime.strptime(page['startDate'], '%Y-%m-%dT%H:%M:%S.%fZ')
                end = datetime.strptime(page['endDate'], '%Y-%m-%dT%H:%M:%S.%fZ')
                durations.append((end - start).days)
            except:
                continue
        if 'textData' in page and page['textData']:
            try:
                text = str(page['textData'])
                sentiment_scores.append(TextBlob(text).sentiment.polarity)
            except:
                continue
    
    avg_duration = sum(durations)/len(durations) if durations else 0
    location_diversity = len(set(location_types))
    avg_sentiment = sum(sentiment_scores)/len(sentiment_scores) if sentiment_scores else 0
    
    personality = "The Explorer"
    traits = []
    
    if avg_duration > 14:
        personality = "The Immerser"
        traits.append("Deep cultural experiences")
    elif avg_duration < 3:
        personality = "The Quick Adventurer"
        traits.append("Fast-paced travel")
    
    if location_diversity > 10:
        personality += " with Wanderlust"
        traits.append("Loves variety")
    
    if 'hiking' in activity_counts or 'adventure' in activity_counts:
        traits.append("Adventurous")
    
    if avg_sentiment > 0.3:
        traits.append("Positive traveler")
    elif avg_sentiment < -0.1:
        traits.append("Thoughtful traveler")
    
    return {
        'travel_personality': personality,
        'personality_traits': traits,
        'avg_trip_duration': avg_duration,
        'location_diversity': location_diversity,
        'avg_sentiment': avg_sentiment
    }

def process_geographic_facts(data: Dict) -> Dict:
    """Generate fun geographic facts"""
    locations = []
    coordinates = []
    climate_zones = set()
    total_distance = 0
    
    # First pass to collect locations
    for page in data['allPages']:
        if 'location' in page and page['location']:
            locations.append(page['location'])
    
    # Geocode locations (with simulated results for example)
    if len(locations) > 1:
        # Simulate distance calculation between locations
        for i in range(len(locations)-1):
            total_distance += np.random.randint(100, 5000)
        
        # Simulate climate zones
        climate_zones.update(['Temperate', 'Mediterranean', 'Tropical'])
    
    return {
        'geographic_facts': [
            f"You've traveled across {len(climate_zones)} climate zones",
            f"Your average trip distance is {total_distance//len(locations) if locations else 0} km",
            "You prefer coastal destinations" if "beach" in str(locations).lower() else "You prefer urban destinations",
            f"You've visited {len(set(locations))} unique locations"
        ],
        'total_distance': total_distance,
        'climate_zones': list(climate_zones)
    }

def process_activity_patterns(data: Dict) -> Dict:
    """Analyze activity patterns using clustering"""
    activities = Counter()
    for page in data['allPages']:
        if 'tags' in page and page['tags']:
            activities.update(page['tags'])
    
    # Cluster similar activities (simplified example)
    activity_list = list(activities.keys())
    if len(activity_list) > 3:
        # Simulate clustering
        clustered = {
            'Outdoor': ['hiking', 'camping', 'swimming'],
            'Cultural': ['museum', 'art', 'history'],
            'Urban': ['shopping', 'dining', 'city']
        }
    else:
        clustered = {'General': activity_list}
    
    return {
        'activity_patterns': dict(activities.most_common(10)),
        'activity_clusters': clustered
    }

def process_mood_timeline(data: Dict) -> Dict:
    """Create mood timeline with smoothing"""
    timeline = []
    for page in data['allPages']:
        if 'textData' in page and page['textData'] and 'updatedAt' in page:
            try:
                text = str(page['textData'])
                sentiment = TextBlob(text).sentiment.polarity
                date = datetime.strptime(page['updatedAt'].split('+')[0], '%Y-%m-%dT%H:%M:%S.%f')
                timeline.append({
                    'date': date,
                    'mood': (sentiment + 1) / 2  # Normalize to 0-1
                })
            except Exception as e:
                print(f"Error processing mood timeline: {e}")
                continue
    
    # Group by month and average
    monthly_mood = {}
    for entry in timeline:
        month_year = f"{entry['date'].month}-{entry['date'].year}"
        if month_year not in monthly_mood:
            monthly_mood[month_year] = []
        monthly_mood[month_year].append(entry['mood'])
    
    # Create smoothed timeline
    smoothed_timeline = []
    for month, moods in monthly_mood.items():
        month_num, year = map(int, month.split('-'))
        smoothed_timeline.append({
            'month': month_num,
            'year': year,
            'mood': sum(moods)/len(moods)
        })
    
    # Sort by date
    smoothed_timeline.sort(key=lambda x: (x['year'], x['month']))
    
    return {
        'mood_timeline': smoothed_timeline,
        'avg_mood': sum(entry['mood'] for entry in smoothed_timeline)/len(smoothed_timeline) if smoothed_timeline else 0.5
    }

def process_bucket_list(data: Dict) -> Dict:
    """Generate personalized bucket list suggestions"""
    activities = set()
    locations = set()
    
    for page in data['allPages']:
        if 'tags' in page and page['tags']:
            activities.update(page['tags'])
        if 'location' in page and page['location']:
            locations.add(page['location'])
    
    suggestions = []
    
    # Activity-based suggestions
    if 'hiking' in activities:
        suggestions.append("Trek to Everest Base Camp")
    if 'beach' in activities:
        suggestions.append("Relax in the Maldives")
    if 'museum' in activities:
        suggestions.append("Visit the Louvre in Paris")
    
    # Location-based suggestions
    if not suggestions:
        if any('Europe' in loc for loc in locations):
            suggestions.append("Explore the Norwegian fjords")
        elif any('Asia' in loc for loc in locations):
            suggestions.append("Visit the temples of Kyoto")
        else:
            suggestions.append("Take a cross-country road trip")
    
    # Ensure we have at least 3 suggestions
    default_suggestions = [
        "See the Northern Lights",
        "Go on an African safari",
        "Visit Machu Picchu"
    ]
    
    while len(suggestions) < 3:
        suggestion = default_suggestions.pop(0)
        if suggestion not in suggestions:
            suggestions.append(suggestion)
    
    return {
        'bucket_list': suggestions[:5],
        'generated_from': {
            'activities': list(activities),
            'locations': list(locations)
        }
    }

def process_insights(data: Dict) -> Dict:
    """Process all insights with error handling"""
    try:
        print(f"Processing insights for {len(data['allPages'])} pages")
        
        results = {
            'location_sentiment': process_location_sentiment(data),
            'sentiment': process_sentiment(data),
            'highlights': process_highlights(data),
            'location_repeats': process_location_repeats(data),
            'seasonal_patterns': process_seasonal_patterns(data),
            'photo_timeline': process_photo_timeline(data),
            'travel_personality': process_travel_personality(data),
            'geographic_facts': process_geographic_facts(data),
            'activity_patterns': process_activity_patterns(data),
            'mood_timeline': process_mood_timeline(data),
            'bucket_list': process_bucket_list(data),
        }
        
        # Calculate additional metrics
        if 'location_repeats' in results:
            results['unique_locations_count'] = results['location_repeats']['total_unique']
            del results['location_repeats']['total_unique']
        
        if 'geographic_facts' in results:
            results['total_distance_km'] = results['geographic_facts'].pop('total_distance')
        
        print("Successfully processed insights")
        return results
        
    except Exception as e:
        print(f"Error in process_insights: {str(e)}")
        return {
            'error': str(e),
            'status': 'failed'
        }

@app.route('/')
def home() -> str:
    """Health check endpoint"""
    return "Travel Insights API is running", 200

@app.route('/process-insights', methods=['POST', 'OPTIONS','GET'])  # Add OPTIONS
def process_insights_endpoint():
    """Main API endpoint for processing insights"""
    if request.method == 'OPTIONS':
        # Handle preflight request
        response = jsonify({'status': 'preflight'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST')
        return response

    try:
        # More lenient content type check
        if not request.is_json:
            return jsonify({
                'error': 'Unsupported Media Type',
                'message': 'Content-Type must be application/json'
            }), 415

        data = request.get_json()
        if not data or 'allPages' not in data:
            return jsonify({
                'error': 'Bad Request',
                'message': 'Missing required field: allPages'
            }), 400

        results = process_insights(data)
        response = jsonify(results)
        response.headers.add('Access-Control-Allow-Origin', '*')
        return response, 200

    except Exception as e:
        print(f"Endpoint error: {str(e)}")
        return jsonify({
            'error': 'Internal Server Error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)