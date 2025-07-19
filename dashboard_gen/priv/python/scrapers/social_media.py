import argparse
import json
import sys
import time


def scrape(company: str):
    # Placeholder for scraping social media via APIs
    time.sleep(1)
    return [
        {
            "company": company.title(),
            "title": "Social Post",
            "content": "Mock social media mention.",
            "date": "2024-05-02",
            "source": "social_media",
            "url": f"https://social.example.com/{company}/post/1",
        }
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", default="blackstone")
    args = parser.parse_args()
    data = scrape(args.company)
    json.dump(data, sys.stdout)


if __name__ == "__main__":
    main()
