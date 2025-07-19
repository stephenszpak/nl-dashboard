"""Scrape recent social media activity for a given company."""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta
from typing import List, Dict

import requests
from bs4 import BeautifulSoup


HEADERS = {"User-Agent": "Mozilla/5.0"}


def _fetch(url: str, retries: int = 3, delay: float = 1.0) -> requests.Response | None:
    """Return a ``requests.Response`` with basic retry logic."""
    for attempt in range(retries):
        try:
            res = requests.get(url, headers=HEADERS, timeout=10)
            res.raise_for_status()
            return res
        except Exception:
            if attempt == retries - 1:
                return None
            time.sleep(delay)


def scrape_x(company: str) -> List[Dict]:
    """Scrape recent posts from a Nitter mirror for the given company."""
    url = f"https://nitter.net/{company}"
    res = _fetch(url)
    if not res:
        return []

    soup = BeautifulSoup(res.text, "html.parser")
    posts = []

    for item in soup.select("div.timeline-item")[:5]:
        content_el = item.select_one(".tweet-content")
        date_el = item.select_one(".tweet-date a")
        if not content_el or not date_el:
            continue

        date = date_el.get("title") or date_el.text
        posts.append(
            {
                "company": company.title(),
                "platform": "X",
                "content": content_el.get_text(" ", strip=True),
                "date": date.split(" ")[0],
                "url": f"https://nitter.net{date_el.get('href')}",
                "source": "social_media",
            }
        )

    return posts


def scrape_linkedin(company: str) -> List[Dict]:
    """Scrape public LinkedIn posts for the given company."""
    url = f"https://www.linkedin.com/company/{company}/posts/"
    res = _fetch(url)
    if not res:
        return []

    soup = BeautifulSoup(res.text, "html.parser")
    posts = []

    for post in soup.select("div.feed-shared-update-v2")[:5]:
        text = post.get_text(" ", strip=True)
        date_el = post.select_one("span.visually-hidden")
        date = date_el.get_text(strip=True) if date_el else ""
        posts.append(
            {
                "company": company.title(),
                "platform": "LinkedIn",
                "content": text,
                "date": date,
                "url": url,
                "source": "social_media",
            }
        )

    return posts


def scrape_youtube(company: str) -> List[Dict]:
    """Scrape recent YouTube videos for the given company."""
    feed_url = f"https://www.youtube.com/feeds/videos.xml?search_query={company}"
    res = _fetch(feed_url)
    if not res:
        return []

    soup = BeautifulSoup(res.text, "xml")
    posts = []

    cutoff = datetime.utcnow() - timedelta(days=60)

    for entry in soup.select("entry"):
        title_el = entry.find("title")
        link_el = entry.find("link")
        date_el = entry.find("published")
        if not (title_el and link_el and date_el):
            continue

        date = datetime.fromisoformat(date_el.text.replace("Z", "+00:00"))
        if date < cutoff:
            continue

        posts.append(
            {
                "company": company.title(),
                "platform": "YouTube",
                "content": title_el.text,
                "date": date.date().isoformat(),
                "url": link_el.get("href"),
                "source": "social_media",
            }
        )

    return posts


def scrape_company(company: str) -> List[Dict]:
    """Run all scrapers for the given company."""
    data: List[Dict] = []

    try:
        data.extend(scrape_x(company))
    except Exception:
        pass

    try:
        data.extend(scrape_linkedin(company))
    except Exception:
        pass

    try:
        yt_posts = scrape_youtube(company)
        if yt_posts:
            data.extend(yt_posts)
    except Exception:
        pass

    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", required=True)
    args = parser.parse_args()

    results = scrape_company(args.company)
    json.dump(results, sys.stdout)


if __name__ == "__main__":
    main()
