#fills exercises.mechanic (compound/isolation) from the raw dataset since the notebook dropped it on import
#run from backend/: python scripts/backfill_mechanic.py
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1])) #lets us import app.* when run as a script

from sqlalchemy import update
from app.database import SessionLocal
from app.models import Exercise

DATA_PATH = Path(__file__).resolve().parents[1] / 'data-eval' / 'exercises.json'

def main():
    raw = json.loads(DATA_PATH.read_text(encoding='utf-8'))
    db = SessionLocal()
    try:
        updated = 0
        for row in raw:
            result = db.execute(update(Exercise).where(Exercise.name == row['name']).values(mechanic=row.get('mechanic'))) #names are unique so this hits at most one row
            updated += result.rowcount
        db.commit()
        print(f'updated {updated} of {len(raw)} exercises')
    finally:
        db.close()

if __name__ == '__main__':
    main()
