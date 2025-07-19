import argparse
import json
import sys
import requests
from bs4 import BeautifulSoup


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
    # TODO: implement
    return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", default="blackstone")
    args = parser.parse_args()

    try:
        if args.company == "blackstone":
            data = scrape_blackstone()
        elif args.company == "jpmorgan":
            data = scrape_jpmorgan()
        else:
            raise ValueError(f"Unsupported company: {args.company}")

        print(json.dumps(data))
    except Exception as e:
        print(json.dumps({"error": str(e)}))


if __name__ == "__main__":
    main()
