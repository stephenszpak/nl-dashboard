import json
import logging
import re
import sys
from pathlib import Path
from typing import List, Dict, Any
from urllib.parse import urljoin, urlparse, parse_qs
import ssl
import certifi
import urllib3
import os

urllib3.disable_warnings()
ssl_context = ssl.create_default_context(cafile=certifi.where())
verify_ssl = False if os.getenv("SCRAPER_DEV_MODE") else certifi.where()

import requests
from bs4 import BeautifulSoup

HEADERS = {"User-Agent": "Mozilla/5.0"}
CONFIG_PATH = Path(__file__).with_name("scrape_config_urls.json")

logging.basicConfig(stream=sys.stderr, level=logging.INFO)


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def normalize_company_name(name: str) -> str:
    """Normalize company names to ensure consistency."""
    name = name.strip()
    
    # Handle specific company name variations
    if "blackrock" in name.lower():
        return "BlackRock"
    elif "j.p. morgan" in name.lower() or "jp morgan" in name.lower() or "jpmorgan" in name.lower():
        return "J.P. Morgan Asset Management"
    elif "goldman sachs" in name.lower():
        return "Goldman Sachs Private Wealth"
    elif "fidelity" in name.lower():
        return "Fidelity Investments"
    
    return name


def extract_youtube_video_id(url: str) -> str:
    """Extract YouTube video ID from various YouTube URL formats."""
    if not url or "youtube.com" not in url and "youtu.be" not in url:
        return ""
    
    # Handle different YouTube URL formats
    if "youtu.be/" in url:
        # Short format: https://youtu.be/VIDEO_ID
        return url.split("youtu.be/")[-1].split("?")[0]
    elif "watch?v=" in url:
        # Standard format: https://www.youtube.com/watch?v=VIDEO_ID
        parsed = urlparse(url)
        return parse_qs(parsed.query).get("v", [""])[0]
    elif "/shorts/" in url:
        # Shorts format: https://www.youtube.com/shorts/VIDEO_ID
        return url.split("/shorts/")[-1].split("?")[0]
    
    return ""


def get_youtube_video_metrics(video_ids: List[str], api_key: str = None) -> Dict[str, Dict]:
    """Fetch YouTube video metrics using YouTube Data API v3."""
    if not video_ids or not api_key:
        return {}
    
    # Remove empty video IDs
    video_ids = [vid for vid in video_ids if vid]
    if not video_ids:
        return {}
    
    try:
        # YouTube Data API v3 endpoint
        api_url = "https://www.googleapis.com/youtube/v3/videos"
        params = {
            "part": "statistics,snippet",
            "id": ",".join(video_ids),
            "key": api_key
        }
        
        response = requests.get(api_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        metrics = {}
        for item in data.get("items", []):
            video_id = item["id"]
            stats = item.get("statistics", {})
            snippet = item.get("snippet", {})
            
            metrics[video_id] = {
                "view_count": int(stats.get("viewCount", 0)),
                "like_count": int(stats.get("likeCount", 0)),
                "comment_count": int(stats.get("commentCount", 0)),
                "duration": snippet.get("duration", ""),
                "published_at": snippet.get("publishedAt", "")
            }
        
        return metrics
        
    except Exception as e:
        logging.warning("YouTube API request failed: %s", e)
        return {}


def load_config() -> Dict[str, Dict[str, Any]]:
    with open(CONFIG_PATH) as f:
        data = json.load(f)
    config = {}
    for entry in data:
        slug = slugify(entry["company"])
        config[slug] = entry
    return config


def _fetch(url: str, retries: int = 3, delay: float = 1.0) -> BeautifulSoup | None:
    import time
    
    for attempt in range(retries):
        try:
            # Add more realistic headers to avoid bot detection
            headers = {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.5",
                "Accept-Encoding": "gzip, deflate",
                "Connection": "keep-alive",
                "Upgrade-Insecure-Requests": "1",
            }
            
            res = requests.get(url, headers=headers, timeout=15, verify=verify_ssl)
            res.raise_for_status()
            
            if url.endswith(".xml"):
                return BeautifulSoup(res.text, "xml")
            return BeautifulSoup(res.text, "html.parser")
            
        except requests.exceptions.HTTPError as e:
            status = getattr(e.response, "status_code", None)
            if status in (403, 404, 429):
                if attempt < retries - 1:
                    logging.info("HTTP %s for %s, retrying in %s seconds (attempt %d/%d)", 
                               status, url, delay, attempt + 1, retries)
                    time.sleep(delay * (attempt + 1))  # Exponential backoff
                    continue
                else:
                    logging.warning("fetch %s returned %s after %d retries", url, status, retries)
                    return None
            else:
                logging.warning("fetch failed %s: HTTP %s", url, status)
                return None
                
        except requests.exceptions.Timeout:
            if attempt < retries - 1:
                logging.info("Timeout for %s, retrying in %s seconds (attempt %d/%d)", 
                           url, delay, attempt + 1, retries)
                time.sleep(delay)
                continue
            else:
                logging.warning("fetch %s timed out after %d retries", url, retries)
                return None
                
        except Exception as e:
            if attempt < retries - 1:
                logging.info("Error fetching %s: %s, retrying in %s seconds (attempt %d/%d)", 
                           url, str(e), delay, attempt + 1, retries)
                time.sleep(delay)
                continue
            else:
                logging.warning("fetch failed %s after %d retries: %s", url, retries, e)
                return None
    
    return None


def scrape_press_releases(urls, company: str) -> List[Dict[str, Any]]:
    if isinstance(urls, str):
        urls = [urls]
    results: List[Dict[str, Any]] = []
    
    for url in urls:
        soup = _fetch(url)
        if not soup:
            continue
            
        if url.endswith(".xml"):
            # Handle RSS/XML feeds
            for item in soup.select("item")[:10]:
                title = item.findtext("title", "").strip()
                link = item.findtext("link", "").strip()
                date = item.findtext("pubDate", "").strip()
                content = item.findtext("description", "").strip()
                if not title:
                    continue
                results.append({
                    "source": "press_release",
                    "company": company,
                    "date": date,
                    "title": title,
                    "content": content,
                    "url": link,
                })
        else:
            # Site-specific selectors based on URL patterns
            if "blackrock.com" in url:
                # BlackRock specific selectors
                for item in soup.select("li.article-cntnr")[:10]:
                    title_el = item.select_one("h2.title")
                    link_el = item.select_one("a.article-wrapper-link")
                    date_el = item.select_one(".attribution-text span")
                    
                    if title_el and link_el:
                        title = title_el.get_text(strip=True)
                        href = link_el.get("href", "")
                        date = date_el.get_text(strip=True) if date_el else ""
                        
                        results.append({
                            "source": "press_release",
                            "company": company,
                            "date": date,
                            "title": title,
                            "content": "",
                            "url": urljoin(url, href),
                        })
                        
            elif "vanguard.com" in url:
                # Vanguard specific selectors
                for item in soup.select("div.cmp-contentListEntry__gridLeftColumn")[:10]:
                    title_el = item.select_one("a.cmp-contentListEntry__headlineLink")
                    date_el = item.select_one("p.cmp-contentListEntry__date")
                    
                    if title_el:
                        title = title_el.get_text(strip=True)
                        href = title_el.get("href", "")
                        date = date_el.get_text(strip=True) if date_el else ""
                        
                        results.append({
                            "source": "press_release",
                            "company": company,
                            "date": date,
                            "title": title,
                            "content": "",
                            "url": urljoin(url, href),
                        })
                        
            elif "fidelity.com" in url:
                # Fidelity specific selectors (multiple strategies)
                found_items = []
                
                # Strategy 1: Main news items with data-guid
                for item in soup.select("p a[data-guid]")[:5]:
                    title = item.get_text(strip=True)
                    href = item.get("href", "")
                    if title and href:
                        found_items.append({
                            "source": "press_release",
                            "company": company,
                            "date": "",
                            "title": title,
                            "content": "",
                            "url": urljoin(url, href),
                        })
                
                # Strategy 2: Featured items in rotator
                for item in soup.select("div.divh2 a")[:5]:
                    title = item.get_text(strip=True)
                    href = item.get("href", "")
                    if title and href:
                        found_items.append({
                            "source": "press_release",
                            "company": company,
                            "date": "",
                            "title": title,
                            "content": "",
                            "url": urljoin(url, href),
                        })
                
                results.extend(found_items[:10])
                
            else:
                # Fallback: generic selectors for other sites
                selectors = [
                    "article a",
                    ".news-item a",
                    ".press-release a",
                    "a[href*='press']",
                    "a[href*='news']"
                ]
                
                for selector in selectors:
                    items = soup.select(selector)[:10]
                    if items:
                        for item in items:
                            title = item.get_text(strip=True)
                            href = item.get("href", "")
                            if title and href and len(title) > 10:
                                results.append({
                                    "source": "press_release",
                                    "company": company,
                                    "date": "",
                                    "title": title,
                                    "content": "",
                                    "url": urljoin(url, href),
                                })
                        break  # Use first successful selector
                        
    return results


def scrape_twitter(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []
    
    # Twitter/X scraping requires API access - return empty results silently
    # to avoid cluttering logs with warnings for every company
    return []


def scrape_linkedin(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []
    return [{
        "source": "linkedin",
        "company": company,
        "date": "",
        "title": "LinkedIn scraping disabled (API/login required)",
        "content": "LinkedIn scraping disabled (API/login required)",
        "url": url,
    }]


def scrape_youtube(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []
    
    # Try RSS feed first (more reliable)
    channel_handle = url.split('/')[-1]
    rss_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_handle}"
    
    # Try with @handle format
    if channel_handle.startswith('@'):
        rss_url = f"https://www.youtube.com/feeds/videos.xml?user={channel_handle[1:]}"
    
    soup = _fetch(rss_url)
    if soup and soup.find('entry'):
        results = []
        for entry in soup.select('entry')[:5]:
            title_el = entry.find('title')
            link_el = entry.find('link')
            date_el = entry.find('published')
            
            if title_el and link_el:
                title = title_el.get_text(strip=True)
                href = link_el.get('href', '')
                date = date_el.get_text(strip=True)[:10] if date_el else ''  # YYYY-MM-DD format
                
                results.append({
                    "source": "social_media",
                    "company": company,
                    "date": date,
                    "title": title[:100],  # Truncate for consistency
                    "content": title,
                    "url": href,
                })
        return results
    
    # Fallback to web scraping (less reliable)
    channel_url = url.rstrip('/') + '/videos'
    soup = _fetch(channel_url)
    if not soup:
        return []

    results: List[Dict[str, Any]] = []
    for vid in soup.select('ytd-grid-video-renderer')[:5]:
        a = vid.select_one('a#video-title')
        if not a:
            continue
        title = a.get('title') or a.get_text(strip=True)
        href = a.get('href')
        date_el = vid.select_one('#metadata-line span:nth-child(2)')
        date = date_el.get_text(strip=True) if date_el else ''
        if not href or not title:
            continue
        results.append({
            "source": "social_media",
            "company": company,
            "date": date,
            "title": title[:100],
            "content": title,
            "url": urljoin('https://www.youtube.com', href),
        })
    return results


def scrape_company(slug: str) -> List[Dict[str, Any]]:
    config = load_config().get(slug)
    if not config:
        logging.warning("No config for %s", slug)
        return []
    
    # Normalize company name for consistency
    company = normalize_company_name(config["company"])
    results: List[Dict[str, Any]] = []
    
    try:
        results.extend(scrape_press_releases(config.get("press_releases") or config.get("rss"), company))
    except Exception as e:
        logging.warning("press release scrape failed for %s: %s", company, e)
    try:
        results.extend(scrape_twitter(config.get("twitter"), company))
    except Exception as e:
        logging.warning("twitter scrape failed for %s: %s", company, e)
    try:
        results.extend(scrape_linkedin(config.get("linkedin"), company))
    except Exception as e:
        logging.warning("linkedin scrape failed for %s: %s", company, e)
    try:
        results.extend(scrape_youtube(config.get("youtube"), company))
    except Exception as e:
        logging.warning("youtube scrape failed for %s: %s", company, e)
    
    # Normalize company names in all results
    for item in results:
        item["company"] = normalize_company_name(item["company"])
    
    # Fetch YouTube engagement metrics if API key is available
    youtube_api_key = os.getenv("YOUTUBE_API_KEY")
    if youtube_api_key:
        # Collect all YouTube video IDs
        video_ids = []
        for item in results:
            if item.get("source") == "social_media" and "youtube.com" in item.get("url", ""):
                video_id = extract_youtube_video_id(item["url"])
                if video_id:
                    video_ids.append(video_id)
        
        # Fetch metrics for all videos in one API call
        if video_ids:
            try:
                metrics = get_youtube_video_metrics(video_ids, youtube_api_key)
                
                # Add metrics to corresponding items
                for item in results:
                    if item.get("source") == "social_media" and "youtube.com" in item.get("url", ""):
                        video_id = extract_youtube_video_id(item["url"])
                        if video_id in metrics:
                            item.update(metrics[video_id])
                            
            except Exception as e:
                logging.warning("YouTube metrics fetch failed for %s: %s", company, e)
    
    return results
