import argparse
import json
import sys


def scrape_blackstone():
    """Return mocked social media posts for Blackstone."""
    return [
        {
            "company": "Blackstone",
            "content": "Blackstone announces new infrastructure fund launch.",
            "url": "https://social.example.com/blackstone/post/1",
            "date": "2024-05-05",
            "source": "social_media",
        },
        {
            "company": "Blackstone",
            "content": "CEO discusses market outlook on major news outlet.",
            "url": "https://social.example.com/blackstone/post/2",
            "date": "2024-05-04",
            "source": "social_media",
        },
        {
            "company": "Blackstone",
            "content": "Celebrating a successful portfolio company IPO.",
            "url": "https://social.example.com/blackstone/post/3",
            "date": "2024-05-03",
            "source": "social_media",
        },
    ]


def scrape_jpmorgan():
    """Return mocked social media posts for JP Morgan."""
    return [
        {
            "company": "JP Morgan",
            "content": "JP Morgan unveils new digital banking features.",
            "url": "https://social.example.com/jpmorgan/post/1",
            "date": "2024-05-06",
            "source": "social_media",
        },
        {
            "company": "JP Morgan",
            "content": "Analysts applaud JP Morgan quarterly earnings beat.",
            "url": "https://social.example.com/jpmorgan/post/2",
            "date": "2024-05-04",
            "source": "social_media",
        },
        {
            "company": "JP Morgan",
            "content": "Community outreach event highlights financial literacy.",
            "url": "https://social.example.com/jpmorgan/post/3",
            "date": "2024-05-02",
            "source": "social_media",
        },
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--company", default="blackstone")
    args = parser.parse_args()

    if args.company == "blackstone":
        data = scrape_blackstone()
    elif args.company == "jpmorgan":
        data = scrape_jpmorgan()
    else:
        raise ValueError(f"Unsupported company: {args.company}")

    json.dump(data, sys.stdout)


if __name__ == "__main__":
    main()
