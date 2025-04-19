#!/usr/bin/env python3
import csv
import sqlite3
import os
import sys
from collections import defaultdict

# --- Configuration ---
JLPT_LEVELS = ["N5", "N4", "N3", "N2", "N1"] # Process easier levels first
# Set DEBUG to True to get detailed output for ambiguous cases and meaning checks
DEBUG = True
# --- End Configuration ---

def build_vocab_map(csv_dir):
    """
    Builds a map from Japanese words (Kanji or Kana) to their JLPT level
    and associated English meanings from the CSV files.

    Args:
        csv_dir (str): Path to the directory containing VocabList.Nx.csv files.

    Returns:
        dict: A map where keys are Japanese words (str) and values are dicts:
              {'level': str, 'english': set(str)}
              'level' is the highest JLPT level found (e.g., N1 > N5).
              'english' is a set of all unique English meanings found for that word.
    """
    # Intermediate structure: { japanese_word -> {'levels': set(str), 'english': set(str)} }
    intermediate_vocab = defaultdict(lambda: {'levels': set(), 'english': set()})
    print("Building vocabulary map...")
    print(f"Processing levels: {', '.join(JLPT_LEVELS)}")

    processed_files = 0
    total_rows_processed = 0
    total_entries_added = 0

    for lvl in JLPT_LEVELS:
        path = os.path.join(csv_dir, f"VocabList.{lvl}.csv")
        print(f"  Processing {path}...")
        rows_in_file = 0
        entries_from_file = 0
        try:
            with open(path, encoding="utf-8") as f:
                reader = csv.reader(f)
                # Optional: Skip header row if present
                # try:
                #     next(reader)
                # except StopIteration:
                #     print(f"    Warning: Empty file or no header in {path}")
                #     continue # Skip empty file

                for i, row in enumerate(reader):
                    rows_in_file += 1
                    if len(row) < 3:
                        if DEBUG: print(f"    [Debug] Skipping malformed row {i+1} in {lvl}: {row}")
                        continue
                    kanji = row[0].strip()
                    kana = row[1].strip()
                    english = row[2].strip()

                    if not (kanji or kana) or not english:
                        if DEBUG: print(f"    [Debug] Skipping row {i+1} in {lvl} due to missing key data (Kanji/Kana or English): {row}")
                        continue # Need at least Kanji or Kana, and English

                    keys = set()
                    if kanji: keys.add(kanji)
                    # Add kana only if it exists and is different from kanji,
                    # OR if kanji is empty (it's a kana-only entry)
                    if kana and (kana != kanji or not kanji):
                        keys.add(kana)

                    if not keys: # Should not happen if previous check passed, but safeguard
                         if DEBUG: print(f"    [Debug] Skipping row {i+1} in {lvl}, no valid key found: {row}")
                         continue

                    added_key = False
                    for key in keys:
                        intermediate_vocab[key]['levels'].add(lvl)
                        intermediate_vocab[key]['english'].add(english)
                        added_key = True

                    if added_key:
                        entries_from_file += 1

            print(f"    Finished {path}. Processed {rows_in_file} rows, added/updated {entries_from_file} unique word forms.")
            processed_files += 1
            total_rows_processed += rows_in_file
            # Note: total_entries_added is complex due to overwrites/merges, calculated later

        except FileNotFoundError:
            print(f"  Warning: CSV file not found at {path}. Skipping.")
        except Exception as e:
            print(f"  Error reading {path}: {e}")

    # --- Resolve Levels and Finalize Map ---
    # Choose the 'highest' level found for each word (N1 > N2 > ... > N5)
    # This assumes N1 is the 'highest' priority. If you want the 'lowest' level tag
    # (e.g., N5 if a word is in both N5 and N3), reverse the sort or adjust logic.
    final_vocab = {}
    level_key_func = lambda level_str: int(level_str[1:]) # N5 -> 5, N1 -> 1
    level_sort_reverse = True # True means N1 comes before N5 (higher level priority)

    for key, data in intermediate_vocab.items():
        if not data['levels']: continue # Should not happen, but safeguard
        sorted_levels = sorted(list(data['levels']), key=level_key_func, reverse=level_sort_reverse)
        final_level = sorted_levels[0] # Pick the highest priority level
        final_vocab[key] = {'level': final_level, 'english': data['english']}
        total_entries_added +=1 # Count unique keys in final map

    print("-" * 20)
    print(f"Vocabulary map build complete.")
    print(f"  Processed {processed_files} CSV files, {total_rows_processed} total rows.")
    print(f"  Created map with {total_entries_added} unique Japanese word entries.")
    print("-" * 20)
    return final_vocab


def check_meaning_overlap(db_meaning, csv_english_set):
    """
    Checks if any of the English definitions from the CSV appear as substrings
    in the database meaning field. Case-insensitive comparison.
    """
    if not db_meaning or not csv_english_set:
        return False
    db_meaning_lower = db_meaning.lower()
    for csv_eng in csv_english_set:
        if csv_eng.lower() in db_meaning_lower:
            return True # Found an overlapping meaning
    return False


def main():
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
    except NameError:
         # Fallback for interactive environments or execution methods where __file__ is not set
         print("Warning: __file__ not defined, using current working directory as script directory.")
         script_dir = os.getcwd()

    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    # Adjust csv_dir if your CSVs are not in the project root
    csv_dir = project_root
    db_path = os.path.join(project_root, "assets", "V6.db")

    print(f"Script directory: {script_dir}")
    print(f"Project root: {project_root}")
    print(f"CSV directory: {csv_dir}")
    print(f"Database path: {db_path}")
    print(f"Debug mode: {'Enabled' if DEBUG else 'Disabled'}")
    print("-" * 20)

    if not os.path.isdir(csv_dir):
        print(f"Error: CSV directory not found: {csv_dir}")
        sys.exit(1)
    if not os.path.isfile(db_path):
         print(f"Error: Database file not found: {db_path}")
         sys.exit(1)


    vocab_map = build_vocab_map(csv_dir)

    if not vocab_map:
        print("Vocabulary map is empty. Cannot proceed. Check CSV files and paths.")
        sys.exit(1)

    conn = None
    updates = []
    processed_count = 0
    match_kanji_count = 0
    match_kana_only_count = 0
    match_ambiguous_meaning_ok_count = 0
    match_ambiguous_meaning_fail_count = 0
    already_tagged_count = 0
    no_match_count = 0

    print(f"Connecting to database: {db_path}")
    try:
        conn = sqlite3.connect(db_path)
        # Use Row factory for easier column access by name (optional but convenient)
        # conn.row_factory = sqlite3.Row
        c = conn.cursor()

        print("Fetching entries from dict_index (this may take time)...")
        # Select necessary columns, including the 'meaning' field
        c.execute("SELECT rowid, kanji, reading, meaning, tags FROM dict_index")

        print("Processing database entries...")
        # Iterate directly over the cursor for memory efficiency
        for row in c:
            rowid, db_kanji, db_reading, db_meaning, db_tags = row
            processed_count += 1
            if processed_count % 20000 == 0:
                print(f"  Processed {processed_count} entries...")

            lvl = None
            csv_english_set = None
            match_type = "No Match"

            # --- Matching Logic ---

            # Priority 1: Exact Kanji match (High Confidence)
            if db_kanji and db_kanji in vocab_map:
                vocab_entry = vocab_map[db_kanji]
                lvl = vocab_entry['level']
                csv_english_set = vocab_entry['english']
                match_type = "Kanji Match"
                match_kanji_count += 1

            # Priority 2: Reading match for DB entries *without* Kanji (Medium Confidence)
            elif not db_kanji and db_reading and db_reading in vocab_map:
                vocab_entry = vocab_map[db_reading]
                lvl = vocab_entry['level']
                csv_english_set = vocab_entry['english']
                match_type = "Kana-Only DB Entry Match"
                match_kana_only_count += 1

            # Priority 3: Ambiguous case - DB has Kanji, but only Reading matches vocab (Low Confidence)
            # Requires English meaning check.
            elif db_kanji and db_reading and db_reading in vocab_map:
                # This reading exists in vocab, but the DB kanji didn't match.
                # Could be correct (e.g., vocab map only had kana form), or incorrect (different word).
                # Check if the English meanings overlap as a heuristic.
                vocab_entry = vocab_map[db_reading]
                potential_lvl = vocab_entry['level']
                potential_csv_english_set = vocab_entry['english']
                match_type = "Ambiguous (Reading Match on Kanji Entry)"

                if DEBUG:
                    print(f"\n  [Debug] Ambiguous case for rowid={rowid}:")
                    print(f"    DB Entry: Kanji='{db_kanji}', Reading='{db_reading}'")
                    print(f"    Vocab Match Key: '{db_reading}' (Level: {potential_lvl})")
                    print(f"    DB Meaning: '{db_meaning}'")
                    print(f"    CSV English Set: {potential_csv_english_set}")

                # Perform the meaning check
                if check_meaning_overlap(db_meaning, potential_csv_english_set):
                    lvl = potential_lvl
                    csv_english_set = potential_csv_english_set
                    match_type += " -> Meaning OK"
                    match_ambiguous_meaning_ok_count += 1
                    if DEBUG: print("    Meaning Check: PASSED (Overlap found)")
                else:
                    # Meanings don't overlap sufficiently, likely a mismatch. Do not tag.
                     match_type += " -> Meaning FAILED"
                     match_ambiguous_meaning_fail_count += 1
                     if DEBUG: print("    Meaning Check: FAILED (No overlap)")
            else:
                # No match found based on Kanji or Reading
                no_match_count += 1

            # --- Tagging Logic ---
            if lvl: # If any match succeeded
                existing_tags = db_tags or ""
                # Split tags, strip whitespace, filter empty, ensure uniqueness
                tag_items = set(t.strip() for t in existing_tags.split(",") if t.strip())

                jlpt_tag = f"JLPT{lvl}"

                if jlpt_tag in tag_items:
                    already_tagged_count += 1
                    if DEBUG and match_type not in ["No Match", "Ambiguous (Reading Match on Kanji Entry) -> Meaning FAILED"]:
                         print(f"    [Debug] Rowid={rowid} ({db_kanji or db_reading}): Already has tag '{jlpt_tag}'. Skipping update.")
                    continue # Tag already exists, skip update

                tag_items.add(jlpt_tag)
                # Sort tags alphabetically for consistency before joining
                sorted_tags = sorted(list(tag_items))
                new_tags = ",".join(sorted_tags)

                updates.append((new_tags, rowid))
                if DEBUG and match_type not in ["No Match", "Ambiguous (Reading Match on Kanji Entry) -> Meaning FAILED"]:
                    print(f"    [Debug] Rowid={rowid} ({db_kanji or db_reading}): Adding tag '{jlpt_tag}'. Match type: '{match_type}'. New tags: '{new_tags}'")

        print("-" * 20)
        print(f"Finished processing {processed_count} database entries.")
        print("Matching Summary:")
        print(f"  - Kanji Matches (High Confidence): {match_kanji_count}")
        print(f"  - Kana-Only DB Entry Matches (Medium Confidence): {match_kana_only_count}")
        print(f"  - Ambiguous Matches (Meaning Check Passed): {match_ambiguous_meaning_ok_count}")
        print(f"  - Ambiguous Matches (Meaning Check Failed): {match_ambiguous_meaning_fail_count}")
        print(f"  - Entries with No Match Found: {no_match_count}")
        print(f"  - Entries Already Tagged Correctly: {already_tagged_count}")
        print("-" * 20)


        if updates:
            print(f"Applying {len(updates)} updates to the database...")
            c.executemany("UPDATE dict_index SET tags = ? WHERE rowid = ?", updates)
            conn.commit()
            print(f"Successfully committed {len(updates)} updates.")
        else:
            print("No entries required updating.")

    except sqlite3.Error as e:
        print(f"Database error: {e}")
        if conn:
             conn.rollback() # Rollback any partial changes if error occurs during update
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

# --- How to Run ---
# 1. Prerequisites:
#    - Python 3 installed.
#    - The script assumes a directory structure like this:
#      YourProjectRoot/
#      ├── assets/
#      │   └── V6.db        (Your SQLite database)
#      ├── scripts/         (Or wherever this script is)
#      │   └── tag_jlpt.py  (This script file)
#      ├── VocabList.N1.csv (Your JLPT vocabulary lists)
#      ├── VocabList.N2.csv
#      ├── ...
#      └── VocabList.N5.csv
#    - If your structure is different, adjust the `project_root`, `csv_dir`,
#      and `db_path` variables near the top of the `main()` function.
#    - Ensure your CSV files are UTF-8 encoded and have at least 3 columns:
#      Kanji (can be empty), Kana, English Definition.
#
# 2. Execution:
#    - Open a terminal or command prompt.
#    - Navigate to the directory containing this script (e.g., `cd YourProjectRoot/scripts`).
#    - Run the script using: python tag_jlpt.py
#
# 3. Debugging:
#    - Set the `DEBUG` variable at the top of the script to `True` to get
#      detailed output about ambiguous matches and meaning checks. Set to `False`
#      for less verbose output during normal runs.
#
# 4. Backup:
#    - **IMPORTANT:** Before running this script for the first time, it is STRONGLY
#      recommended to make a backup copy of your `V6.db` database file in case
#      anything goes wrong or you want to revert the changes.
# ---

if __name__ == "__main__":
    main()