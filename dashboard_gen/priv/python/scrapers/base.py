import json
import logging
import re
import sys
from pathlib import Path
from typing import List, Dict, Any
from urllib.parse import urljoin
import ssl
import certifi
import urllib3
import os

urllib3.disable_warnings()
ssl_context = ssl.create_default_context(cafile=certifi.where())
verify_ssl = False if os.getenv("SCRAPER_DEV_MODE") else certifi.where()

import requests
from bs4 import BeautifulSoup
import snscrape.modules.twitter as sntwitter

HEADERS = {"User-Agent": "Mozilla/5.0"}
CONFIG_PATH = Path(__file__).with_name("scrape_config_urls.json")

logging.basicConfig(stream=sys.stderr, level=logging.INFO)


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def load_config() -> Dict[str, Dict[str, Any]]:
    with open(CONFIG_PATH) as f:
        data = json.load(f)
    config = {}
    for entry in data:
        slug = slugify(entry["company"])
        config[slug] = entry
    return config


def _fetch(url: str) -> BeautifulSoup | None:
    try:
        res = requests.get(url, headers=HEADERS, timeout=10, verify=verify_ssl)
        res.raise_for_status()
    except requests.exceptions.HTTPError as e:
        status = getattr(e.response, "status_code", None)
        if status in (403, 404):
            logging.warning("fetch %s returned %s", url, status)
            return None
        logging.warning("fetch failed %s: %s", url, e)
        return None
    except Exception as e:
        logging.warning("fetch failed %s: %s", url, e)
        return None

    if url.endswith(".xml"):
        return BeautifulSoup(res.text, "xml")
    return BeautifulSoup(res.text, "html.parser")


def scrape_press_releases(urls, company: str) -> List[Dict[str, Any]]:
    if isinstance(urls, str):
        urls = [urls]
    results: List[Dict[str, Any]] = []
    for url in urls:
        soup = _fetch(url)
        if not soup:
            continue
        if url.endswith(".xml"):
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
            for art in soup.select("article a")[:10]:
                title = art.get_text(strip=True)
                href = art.get("href")
                if not href or not title:
                    continue
                results.append({
                    "source": "press_release",
                    "company": company,
                    "date": "",
                    "title": title,
                    "content": "",
                    "url": urljoin(url, href),
                })
    return results


def scrape_twitter(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []

    handles: List[str] = []
    if isinstance(url, list):
        for u in url:
            if isinstance(u, str):
                handles.append(u.rstrip("/").split("/")[-1].lstrip("@"))
    elif isinstance(url, str):
        handles.append(url.rstrip("/").split("/")[-1].lstrip("@"))

    results: List[Dict[str, Any]] = []
    for handle in handles:
        try:
            scraper = sntwitter.TwitterUserScraper(handle)
            for i, tweet in enumerate(scraper.get_items()):
                if i >= 5:
                    break
                if not hasattr(tweet, "content"):
                    continue
                results.append({
                    "source": "twitter",
                    "company": company,
                    "date": tweet.date.date().isoformat() if hasattr(tweet, "date") else "",
                    "title": tweet.content[:100],
                    "content": tweet.content,
                    "url": tweet.url,
                })
        except Exception as e:
            logging.warning("twitter scrape failed for %s handle %s: %s", company, handle, e)
    return results


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
            "source": "youtube",
            "company": company,
            "date": date,
            "title": title,
            "content": title,
            "url": urljoin('https://www.youtube.com', href),
        })
    return results


def scrape_company(slug: str) -> List[Dict[str, Any]]:
    config = load_config().get(slug)
    if not config:
        logging.warning("No config for %s", slug)
        return []
    company = config["company"]
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
    return results
