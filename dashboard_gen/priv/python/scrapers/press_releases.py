import argparse
import json
import sys
import requests
import time
from bs4 import BeautifulSoup
from typing import List, Dict



def _parse_rss(feed_url: str, company: str) -> List[Dict]:
    res = requests.get(feed_url, headers={"User-Agent": "Mozilla/5.0"})
    res.raise_for_status()
    soup = BeautifulSoup(res.text, "xml")

    items = []
    for item in soup.select("item"):
        items.append(
            {
                "company": company,
                "title": item.findtext("title", "").strip(),
                "url": item.findtext("link", "").strip(),
                "date": item.findtext("pubDate", "").strip(),
                "content": item.findtext("description", "").strip(),
                "source": "press_release",
            }
        )

    return items


def scrape_blackrock() -> List[Dict]:
    # BlackRock provides an RSS feed for press releases
    feed = "https://www.blackrock.com/corporate/newsroom/press-releases?rss=true"
    return _parse_rss(feed, "BlackRock")

def scrape_jp_morgan_am() -> List[Dict]:
    # JP Morgan Asset Management RSS feed for press releases
    feed = "https://am.jpmorgan.com/us/en/asset-management/adv/_jcr_content/pressReleaseFeed.xml"
    return _parse_rss(feed, "J.P. Morgan Asset Management")


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

        with open("scrape_output.json", "w") as f:
            json.dump(data, f)

    except Exception as e:
        with open("scrape_output.json", "w") as f:
            json.dump({"error": str(e)}, f)


if __name__ == "__main__":
    main()
