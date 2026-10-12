import csv
import os
from datetime import datetime

import pytest

from scripts.generate_sample_data import generate_temperature_csv


@pytest.fixture
def temp_csv_file(tmp_path):
    return str(tmp_path / "test_temperature_data.csv")


def test_generate_temperature_csv_creates_file(temp_csv_file):
    generate_temperature_csv(temp_csv_file, num_records=10)
    assert os.path.isfile(temp_csv_file)


def test_generate_temperature_csv_header(temp_csv_file):
    generate_temperature_csv(temp_csv_file, num_records=1)

    with open(temp_csv_file, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)

    assert header == ["City", "Temperature", "timestamp"]


def test_generate_temperature_csv_content(temp_csv_file):
    num_records = 5
    generate_temperature_csv(temp_csv_file, num_records=num_records)

    with open(temp_csv_file, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)
        rows = list(reader)

    assert len(rows) == num_records

    valid_cities = {"New York", "London", "Tokyo", "Paris", "Sydney"}

    for row in rows:
        assert len(row) == 3
        assert row[0] in valid_cities

        temp = float(row[1])
        assert 10 <= temp <= 35

        datetime.fromisoformat(row[2])


@pytest.mark.parametrize("size", [0, 1, 10, 100])
def test_generate_temperature_csv_different_sizes(temp_csv_file, size):
    generate_temperature_csv(temp_csv_file, num_records=size)

    with open(temp_csv_file, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)
        rows = list(reader)

    assert len(rows) == size


def test_generate_temperature_csv_invalid_input(temp_csv_file):
    with pytest.raises(ValueError):
        generate_temperature_csv(temp_csv_file, num_records=-1)


def test_generate_temperature_csv_directory_as_filename(tmp_path):
    dir_path = tmp_path / "test_dir.csv"
    dir_path.mkdir()

    with pytest.raises(IsADirectoryError):
        generate_temperature_csv(str(dir_path), num_records=1)

def test_generate_temperature_csv_nested_directory(tmp_path):
    destination = tmp_path / "nested" / "data.csv"
    generate_temperature_csv(destination, 2)
    with destination.open(newline="", encoding="utf-8") as stream:
        assert len(list(csv.DictReader(stream))) == 2


@pytest.mark.parametrize("invalid", [1.5, "10", None, True])
def test_invalid_record_type_does_not_overwrite(tmp_path, invalid):
    destination = tmp_path / "existing.csv"
    destination.write_text("preserve me", encoding="utf-8")
    with pytest.raises(TypeError):
        generate_temperature_csv(destination, invalid)
    assert destination.read_text(encoding="utf-8") == "preserve me"


def test_timestamps_are_utc_and_within_last_year(temp_csv_file):
    from datetime import timedelta, timezone

    before = datetime.now(timezone.utc)
    generate_temperature_csv(temp_csv_file, 100)
    after = datetime.now(timezone.utc)
    with open(temp_csv_file, newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            timestamp = datetime.fromisoformat(row["timestamp"])
            assert timestamp.utcoffset() == timedelta(0)
            assert before - timedelta(days=365) <= timestamp <= after


def test_cli_runs_from_another_directory(tmp_path):
    import subprocess
    import sys
    from pathlib import Path

    script = Path(__file__).resolve().parents[1] / "scripts/generate_sample_data.py"
    destination = tmp_path / "cli.csv"
    subprocess.run(
        [sys.executable, str(script), "--output", str(destination), "--records", "3"],
        cwd=tmp_path,
        check=True,
    )
    with destination.open(newline="", encoding="utf-8") as stream:
        assert len(list(csv.DictReader(stream))) == 3


def test_cli_rejects_negative_count_without_creating_file(tmp_path):
    import subprocess
    import sys
    from pathlib import Path

    script = Path(__file__).resolve().parents[1] / "scripts/generate_sample_data.py"
    destination = tmp_path / "invalid.csv"
    result = subprocess.run(
        [sys.executable, str(script), "--output", str(destination), "--records", "-1"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 2
    assert "must be non-negative" in result.stderr
    assert not destination.exists()



def test_cli_default_output_is_relative_to_script(tmp_path):
    import shutil
    import subprocess
    import sys
    from pathlib import Path

    source = Path(__file__).resolve().parents[1] / "scripts/generate_sample_data.py"
    isolated_scripts = tmp_path / "project" / "scripts"
    isolated_scripts.mkdir(parents=True)
    copied_script = isolated_scripts / source.name
    shutil.copyfile(source, copied_script)
    subprocess.run(
        [sys.executable, str(copied_script), "--records", "1"],
        cwd=tmp_path,
        check=True,
    )
    assert (tmp_path / "project/data/temperature_data.csv").is_file()
    assert not (tmp_path / "data").exists()
