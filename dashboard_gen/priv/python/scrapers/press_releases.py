import argparse
import json
import sys
import time


def scrape(company: str):
    # Stub for scraping press releases from IR/PR pages
    time.sleep(1)
    return [
        {
            "company": company.title(),
            "title": "Q1 Earnings Announced",
            "content": "Mock earnings announcement details.",
            "date": "2024-04-15",
            "source": "press_release",
            "url": f"https://example.com/{company}/press/q1",
        }
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", default="jpmorgan")
    args = parser.parse_args()
    data = scrape(args.company)
    json.dump(data, sys.stdout)


if __name__ == "__main__":
    main()
