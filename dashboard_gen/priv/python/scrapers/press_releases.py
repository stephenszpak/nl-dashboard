import argparse
import json
import sys
import requests
import time
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright


def scrape_blackstone():
    url = "https://www.blackstone.com/news/press/"
    headers = {"User-Agent": "Mozilla/5.0"}

    res = requests.get(url, headers=headers)
    soup = BeautifulSoup(res.text, "html.parser")
    articles = soup.select("article.bx-article-column")

    results = []

    for article in articles:
        title_el = article.select_one("h4.bx-article-title a")
        date_el = article.select_one("p.bx-article-post_date")

        if title_el:
            results.append({
                "company": "Blackstone",
                "title": title_el.get_text(strip=True),
                "url": title_el["href"],
                "date": date_el.get_text(strip=True) if date_el else None,
                "content": "",
                "source": "press_release"
            })

    return results

def scrape_jpmorgan():
    url = (
        "https://www.jpmorgan.com/services/json/v1/dynamic-grid.service/"
        "parent=jpmorgan/global/US/en/about-us/corporate-news&"
        "comp=root/content-parsys/multi_tab_copy_copy/tab-par-2/dynamic_grid_copy&"
        "page=p1.json"
    )

    headers = {
        "User-Agent": "Mozilla/5.0"
    }

    res = requests.get(url, headers=headers)
    res.raise_for_status()
    data = res.json()

    results = []

    for item in data.get("items", []):
        results.append({
            "company": "JP Morgan",
            "title": item.get("title", "").strip(),
            "url": "https://www.jpmorgan.com" + item.get("link", ""),
            "date": item.get("date", ""),
            "content": item.get("description", ""),
            "source": "press_release"
        })

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", required=True)
    args = parser.parse_args()

    try:
        if args.company == "blackstone":
            data = scrape_blackstone()
        elif args.company == "jpmorgan":
            data = scrape_jpmorgan()
        else:
            raise ValueError(f"Unsupported company: {args.company}")

        with open("scrape_output.json", "w") as f:
            json.dump(data, f)

    except Exception as e:
        with open("scrape_output.json", "w") as f:
            json.dump({"error": str(e)}, f)


if __name__ == "__main__":
    main()


if __name__ == "__main__":
    main()
