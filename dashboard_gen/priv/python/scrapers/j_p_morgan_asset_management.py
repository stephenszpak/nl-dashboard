import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent))
from base import scrape_company



def scrape():
    return scrape_company('j_p_morgan_asset_management')


if __name__ == '__main__':
    import json
    print(json.dumps(scrape()))