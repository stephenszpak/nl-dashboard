import json
import sys
import logging
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))

from blackrock import scrape as scrape_blackrock
from j_p_morgan_asset_management import scrape as scrape_jp_morgan_am
from morgan_stanley_wealth_management import scrape as scrape_morgan_stanley
from goldman_sachs_private_wealth import scrape as scrape_goldman
from fidelity_investments import scrape as scrape_fidelity
from t_rowe_price import scrape as scrape_trowe
from invesco import scrape as scrape_invesco
from franklin_templeton import scrape as scrape_franklin
from vanguard_group import scrape as scrape_vanguard
from ubs import scrape as scrape_ubs
from northern_trust import scrape as scrape_northern
from charles_schwab import scrape as scrape_schwab


SCRAPERS = [
    scrape_blackrock,
    scrape_jp_morgan_am,
    scrape_morgan_stanley,
    scrape_goldman,
    scrape_fidelity,
    scrape_trowe,
    scrape_invesco,
    scrape_franklin,
    scrape_vanguard,
    scrape_ubs,
    scrape_northern,
    scrape_schwab,
]


def scrape_all():
    results = []
    for scraper in SCRAPERS:
        try:
            items = scraper()
            if items:
                results.extend(items)
        except Exception as e:
            logging.warning("scraper %s failed: %s", scraper.__name__, e)
    return results


def main():
    print(json.dumps(scrape_all()))


if __name__ == "__main__":
    main()
