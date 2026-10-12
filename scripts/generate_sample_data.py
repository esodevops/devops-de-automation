"""Generate synthetic temperature observations for the S3/Glue pipeline."""

import argparse
import csv
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "data" / "temperature_data.csv"
CITIES = ("New York", "London", "Tokyo", "Paris", "Sydney")


def generate_temperature_csv(filename, num_records=10000):
    """Write a CSV, preserving native filesystem exceptions for callers.

    Temperatures are synthetic degrees Celsius; timestamps are UTC.
    """
    if isinstance(num_records, bool) or not isinstance(num_records, int):
        raise TypeError("Number of records must be an integer")
    if num_records < 0:
        raise ValueError("Number of records must be non-negative")

    destination = Path(filename)
    destination.parent.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc)
    with destination.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["City", "Temperature", "timestamp"])
        for _ in range(num_records):
            city = random.choice(CITIES)
            temperature = round(random.uniform(10, 35), 1)
            timestamp = now - timedelta(days=random.randint(0, 365))
            writer.writerow([city, temperature, timestamp.isoformat()])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--records", type=int, default=10000)
    args = parser.parse_args()
    if args.records < 0:
        parser.error("--records must be non-negative")
    generate_temperature_csv(args.output, args.records)


if __name__ == "__main__":
    main()
