import json
import sys
import logging
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from base import load_config, scrape_company

COMPANY_SLUGS = [
    "blackrock",
    "j_p_morgan_asset_management", 
    "goldman_sachs_private_wealth",
    "fidelity_investments",
]


def scrape_all():
    results = []
    config = load_config()
    
    for slug in COMPANY_SLUGS:
        if slug in config:
            try:
                items = scrape_company(slug)
                if items:
                    results.extend(items)
            except Exception as e:
                logging.warning("scraper for %s failed: %s", slug, e)
        else:
            logging.warning("No config found for %s", slug)
    
    return results


def main():
    print(json.dumps(scrape_all()))


if __name__ == "__main__":
    main()
