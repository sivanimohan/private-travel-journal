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

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

@app.route('/')
def home():
    return "Travel Insights API is running", 200

@app.route('/process-insights', methods=['GET','POST'])
def process_insights_endpoint():
    print("Received request with data:", request.json)  # Debug logging
    try:
        data = request.json
        if not data or 'allPages' not in data:
            return jsonify({'error': 'Invalid data format. Expected allPages field.'}), 400
            
        results = process_insights(data)
        return jsonify(results)
    except Exception as e:
        print("Error processing request:", str(e))  # Error logging
        return jsonify({'error': str(e)}), 500

def process_insights(data):
    """Process raw data and generate all insights"""
    results = {
        'word_cloud': process_word_cloud(data),
        'sentiment': process_sentiment(data),
        'highlights': process_highlights(data),
        'location_repeats': process_location_repeats(data),
        'seasonal_patterns': process_seasonal_patterns(data),
        'photo_timeline': process_photo_timeline(data),
    }
    return results

def process_word_cloud(data):
    """Generate word cloud and top words from journal entries"""
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    from matplotlib import pyplot as plt
    
    all_text = []
    for page in data['allPages']:
        if 'textData' in page and page['textData']:
            try:
                text_data = json.loads(page['textData']) if isinstance(page['textData'], str) else page['textData']
                if isinstance(text_data, list):
                    for item in text_data:
                        if isinstance(item, list) and len(item) > 0:
                            all_text.append(str(item[0]))
            except Exception as e:
                print(f"Error processing textData: {e}")
                continue
    
    word_counts = Counter(" ".join(all_text).lower().split())
    common_words = {'the', 'and', 'you', 'that', 'was', 'for', 'are', 'with'}
    filtered_words = Counter({
        k: v for k, v in word_counts.items() 
        if k not in common_words and len(k) > 2
    })
    
    try:
        wordcloud = WordCloud(width=800, height=400).generate_from_frequencies(filtered_words)
        plt.figure(figsize=(10, 5))
        plt.imshow(wordcloud, interpolation='bilinear')
        plt.axis("off")
        
        buffer = BytesIO()
        plt.savefig(buffer, format='png')
        buffer.seek(0)
        wordcloud_base64 = base64.b64encode(buffer.read()).decode('utf-8')
        
        return {
            'top_words': dict(filtered_words.most_common(20)),
            'wordcloud_image': wordcloud_base64
        }
    finally:
        plt.close()
def process_sentiment(data):
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

def process_highlights(data):
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
                            if len(text.split()) > 5:  # Simple highlight detection
                                highlights.append(text)
            except Exception as e:
                print(f"Error processing highlights: {e}")
                continue
    
    return highlights[:10]  # Return top 10 highlights

def process_location_repeats(data):
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

def process_seasonal_patterns(data):
    """Analyze travel patterns by season"""
    seasonal_data = {'Winter': 0, 'Spring': 0, 'Summer': 0, 'Fall': 0}
    for page in data['allPages']:
        if 'updatedAt' in page and page['updatedAt']:
            try:
                date = datetime.strptime(page['updatedAt'], '%Y-%m-%dT%H:%M:%S.%fZ')
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
        'most_common_season': max(seasonal_data.items(), key=lambda x: x[1])[0]
    }

def process_photo_timeline(data):
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
    
    # Sort by date and take most recent 20
    photos.sort(key=lambda x: x['date'], reverse=True)
    return photos[:20]

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)