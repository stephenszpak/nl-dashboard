import argparse
import json
import sys
import requests
import time
from bs4 import BeautifulSoup
from typing import List, Dict

HEADERS = {"User-Agent": "Mozilla/5.0"}


def _fetch(url: str) -> BeautifulSoup | None:
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        res.raise_for_status()
        return BeautifulSoup(res.text, "html.parser")
    except Exception:
        return None


def scrape_blackrock() -> List[Dict]:
    urls = [
        "https://www.blackrock.com/corporate/insights/blackrock-investment-institute/publications",
        "https://www.blackrock.com/institutions/en-us/insights",
        "https://www.blackrock.com/us/individual/insights",
    ]

    results = []

    for url in urls:
        soup = _fetch(url)
        if not soup:
            continue

        for item in soup.select("article, .insight-tile, .media-article")[:10]:
            title_el = item.select_one("a")
            date_el = item.select_one("time, .published-date, .date")

            title = title_el.get_text(strip=True) if title_el else ""
            href = title_el["href"] if title_el and title_el.has_attr("href") else ""
            date = date_el.get_text(strip=True) if date_el else ""

            if title and href:
                results.append(
                    {
                        "company": "BlackRock",
                        "title": title,
                        "url": href if href.startswith("http") else f"https://www.blackrock.com{href}",
                        "date": date,
                        "content": "",
                        "source": "insight_article",
                    }
                )

    return results


def scrape_jp_morgan_am() -> List[Dict]:
    feed = "https://am.jpmorgan.com/us/en/asset-management/adv/_jcr_content/pressReleaseFeed.xml"
    try:
        res = requests.get(feed, headers=HEADERS)
        res.raise_for_status()
        soup = BeautifulSoup(res.text, "xml")
        return [
            {
                "company": "J.P. Morgan Asset Management",
                "title": item.findtext("title", "").strip(),
                "url": item.findtext("link", "").strip(),
                "date": item.findtext("pubDate", "").strip(),
                "content": item.findtext("description", "").strip(),
                "source": "press_release",
            }
            for item in soup.select("item")
        ]
    except Exception:
        return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", required=True)
    args = parser.parse_args()

    try:
        if args.company == "blackrock":
            data = scrape_blackrock()
        elif args.company == "jp-morgan-am":
            data = scrape_jp_morgan_am()
        else:
            raise ValueError(f"Unsupported company: {args.company}")
    except Exception:
        data = []

    with open("scrape_output.json", "w") as f:
        json.dump(data if isinstance(data, list) else [], f)


if __name__ == "__main__":
    main()
