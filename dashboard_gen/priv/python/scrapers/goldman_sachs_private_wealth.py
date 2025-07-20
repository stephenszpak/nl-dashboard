import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent))
from base import scrape_company



def scrape():
    return scrape_company('goldman_sachs_private_wealth')


if __name__ == '__main__':
    import json
    print(json.dumps(scrape()))