from collections import Counter, defaultdict
from textblob import TextBlob
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # This enables CORS for all routes

@app.route('/process-insights', methods=['POST'])
def process_insights():
    # Enhanced CORS headers
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'preflight'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', '*')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS, GET')
        return response

    if request.method != 'POST':
        print(f"Invalid method received: {request.method}")  # Debug
        return jsonify({'error': 'Method not allowed'}), 405

    try:
        print(f"Request data: {request.get_json()}")  # Debug
        data = request.get_json() or {}
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        response = jsonify({
            'travel_summaries': travel_summaries(data),
            'mood_mapping': mood_mapping(data),
            'recommendations': recommendations(data),
            'travel_style': travel_style(data),
            'spot_analysis': spot_analysis(data),
            'status': 'success'
        })
        response.headers.add('Access-Control-Allow-Origin', '*')
        return response
    except Exception as e:
        print(f"Error processing request: {str(e)}")  # Debug
        return jsonify({'error': str(e), 'status': 'failed'}), 500

# ... (keep all other functions the same)
# 1. Automated Travel Summaries & Highlights
def travel_summaries(data):
    summaries = []
    loc_clusters = defaultdict(list)
    
    for page in get(data, 'allPages') or []:
        if (text := get(page, 'textData')) and (loc := get(page, 'location')):
            sentiment = TextBlob(str(text)).sentiment.polarity
            if sentiment > 0.6 and len(text.split()) > 15:
                loc_clusters[loc].append(text[:100] + "...")
    
    for loc, texts in loc_clusters.items():
        if texts:
            summaries.append({
                'location': loc,
                'highlight': f"Loved {loc}: " + texts[0]
            })
    
    return {'summaries': summaries[:5]}

# 2. Sentiment & Mood Mapping
def mood_mapping(data):
    location_sentiments = defaultdict(list)
    for page in get(data, 'allPages') or []:
        if (text := get(page, 'textData')) and (loc := get(page, 'location')):
            sentiment = TextBlob(str(text)).sentiment.polarity
            location_sentiments[loc].append(sentiment)
    
    happiest = sorted(
        [(loc, sum(sents)/len(sents)) for loc, sents in location_sentiments.items()],
        key=lambda x: -x[1]
    )[:3]
    
    return {
        'happiest_places': [{'location': loc, 'score': score} for loc, score in happiest],
        'mood_map': {loc: 'positive' if sum(sents)/len(sents) > 0 else 'negative'
                    for loc, sents in location_sentiments.items()}
    }

# 3. Personalized Recommendations
def recommendations(data):
    activity_keywords = Counter()
    location_types = Counter()
    
    for page in get(data, 'allPages') or []:
        if text := get(page, 'textData'):
            text = str(text).lower()
            if 'hiking' in text or 'trek' in text:
                activity_keywords['hiking'] += 1
            if 'museum' in text or 'gallery' in text:
                activity_keywords['culture'] += 1
            if 'beach' in text or 'coast' in text:
                location_types['beach'] += 1
            if 'mountain' in text or 'alps' in text:
                location_types['mountain'] += 1
    
    recs = []
    if activity_keywords:
        top_activity = activity_keywords.most_common(1)[0][0]
        recs.append(f"Try more {top_activity} activities")
    if location_types:
        top_loc = location_types.most_common(1)[0][0]
        recs.append(f"Visit more {top_loc} destinations")
    
    return {'recommendations': recs or ["Explore new places"]}

# 4. Travel Style Classification
def travel_style(data):
    style_counts = defaultdict(int)
    for page in get(data, 'allPages') or []:
        if text := get(page, 'textData'):
            text = str(text).lower()
            if any(word in text for word in ['adventure', 'hiking', 'trekking']):
                style_counts['adventurous'] += 1
            elif any(word in text for word in ['relax', 'spa', 'chill']):
                style_counts['relaxed'] += 1
            elif any(word in text for word in ['museum', 'history', 'culture']):
                style_counts['cultural'] += 1
    
    if style_counts:
        style = max(style_counts.items(), key=lambda x: x[1])[0]
    else:
        style = 'balanced'
    
    return {'travel_style': style}

# 5. Unexpected Gems vs Tourist Hotspots
def spot_analysis(data):
    locations = Counter()
    location_sentiments = defaultdict(list)
    
    for page in get(data, 'allPages') or []:
        if (loc := get(page, 'location')) and (text := get(page, 'textData')):
            locations[loc] += 1
            location_sentiments[loc].append(TextBlob(str(text)).sentiment.polarity)
    
    if not locations:
        return {'analysis': []}
    
    avg_freq = sum(locations.values())/len(locations)
    hidden_gems = []
    hotspots = []
    
    for loc, count in locations.items():
        avg_sentiment = sum(location_sentiments[loc])/len(location_sentiments[loc])
        if count < avg_freq and avg_sentiment > 0.3:
            hidden_gems.append({'location': loc, 'type': 'hidden_gem'})
        elif count > avg_freq * 1.5:
            hotspots.append({'location': loc, 'type': 'hotspot'})
    
    return {
        'hidden_gems': hidden_gems[:3],
        'tourist_hotspots': hotspots[:3]
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)