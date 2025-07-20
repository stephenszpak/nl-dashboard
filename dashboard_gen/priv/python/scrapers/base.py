import json
import logging
import re
import sys
from pathlib import Path
from typing import List, Dict, Any
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

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
        res = requests.get(url, headers=HEADERS, timeout=10)
        res.raise_for_status()
        if url.endswith(".xml"):
            return BeautifulSoup(res.text, "xml")
        return BeautifulSoup(res.text, "html.parser")
    except Exception as e:
        logging.warning("fetch failed %s: %s", url, e)
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
    handle = url.rstrip("/").split("/")[-1].lstrip("@")
    nitter_url = f"https://nitter.net/{handle}"
    soup = _fetch(nitter_url)
    if not soup:
        return []
    results = []
    for item in soup.select("div.timeline-item")[:5]:
        content_el = item.select_one(".tweet-content")
        date_el = item.select_one(".tweet-date a")
        if not content_el or not date_el:
            continue
        date = (date_el.get("title") or date_el.text).split(" ")[0]
        results.append({
            "source": "twitter",
            "company": company,
            "date": date,
            "title": content_el.get_text(" ", strip=True)[:100],
            "content": content_el.get_text(" ", strip=True),
            "url": f"https://twitter.com{date_el.get('href')}",
        })
    return results


def scrape_linkedin(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []
    soup = _fetch(url)
    if not soup:
        return []
    results = []
    for post in soup.select("div.feed-shared-update-v2")[:5]:
        text = post.get_text(" ", strip=True)
        date_el = post.select_one("span.visually-hidden")
        date = date_el.get_text(strip=True) if date_el else ""
        if not text:
            continue
        results.append({
            "source": "linkedin",
            "company": company,
            "date": date,
            "title": text[:100],
            "content": text,
            "url": url,
        })
    return results


def scrape_youtube(url, company: str) -> List[Dict[str, Any]]:
    if not url:
        return []
    handle = url.rstrip("/").split("/")[-1].lstrip("@")
    feed_url = f"https://www.youtube.com/feeds/videos.xml?user={handle}"
    soup = _fetch(feed_url)
    if not soup:
        return []
    results = []
    for entry in soup.select("entry")[:5]:
        title_el = entry.find("title")
        link_el = entry.find("link")
        date_el = entry.find("published")
        if not (title_el and link_el and date_el):
            continue
        results.append({
            "source": "youtube",
            "company": company,
            "date": date_el.text.split("T")[0],
            "title": title_el.text,
            "content": title_el.text,
            "url": link_el.get("href"),
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
