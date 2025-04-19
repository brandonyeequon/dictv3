#!/usr/bin/env python3
import csv
import sqlite3
import os
import sys
from collections import defaultdict

# --- Configuration ---
JLPT_LEVELS = ["N5", "N4", "N3", "N2", "N1"] # Process easier levels first
# Set DEBUG to True to get detailed output for ambiguous cases, meaning checks, and Kanji mismatches
DEBUG = True
# --- End Configuration ---

def build_vocab_map(csv_dir):
    """
    Builds a map from Japanese words (Kanji or Kana) to their JLPT level,
    associated English meanings, and the original Kanji form from the source CSV
    (if applicable, especially for Kana keys).

    Args:
        csv_dir (str): Path to the directory containing VocabList.Nx.csv files.

    Returns:
        dict: A map where keys are Japanese words (str) and values are dicts:
              {'level': str, 'english': set(str), 'source_kanji': str or None}
              'level' is the highest JLPT level found (e.g., N1 > N5).
              'english' is a set of all unique English meanings found for that word.
              'source_kanji' is the Kanji from the CSV row that provided the
              final 'level' information, primarily useful when the key is Kana.
    """
    # Intermediate structure: { japanese_word -> {'levels': set(str), 'english': set(str), 'sources': list} }
    # 'sources' will store {'level': str, 'kanji': str, 'kana': str} from each contributing row
    intermediate_vocab = defaultdict(lambda: {'levels': set(), 'english': set(), 'sources': []})
    print("Building vocabulary map...")
    print(f"Processing levels: {', '.join(JLPT_LEVELS)}")

    processed_files = 0
    total_rows_processed = 0
    total_entries_added = 0 # Will count unique keys in the final map

    for lvl in JLPT_LEVELS:
        path = os.path.join(csv_dir, f"VocabList.{lvl}.csv")
        print(f"  Processing {path}...")
        rows_in_file = 0
        entries_from_file = 0 # Counts unique word forms added/updated *from this file*
        try:
            with open(path, encoding="utf-8") as f:
                reader = csv.reader(f)
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
                    if kana and (kana != kanji or not kanji):
                        keys.add(kana)

                    if not keys:
                         if DEBUG: print(f"    [Debug] Skipping row {i+1} in {lvl}, no valid key found: {row}")
                         continue

                    source_info = {'level': lvl, 'kanji': kanji, 'kana': kana}
                    added_key_from_row = False
                    for key in keys:
                        intermediate_vocab[key]['levels'].add(lvl)
                        intermediate_vocab[key]['english'].add(english)
                        intermediate_vocab[key]['sources'].append(source_info)
                        added_key_from_row = True

                    if added_key_from_row:
                        entries_from_file += 1

            print(f"    Finished {path}. Processed {rows_in_file} rows, potentially added/updated {entries_from_file} unique word forms.")
            processed_files += 1
            total_rows_processed += rows_in_file

        except FileNotFoundError:
            print(f"  Warning: CSV file not found at {path}. Skipping.")
        except Exception as e:
            print(f"  Error reading {path}: {e}")

    # --- Resolve Levels and Finalize Map ---
    final_vocab = {}
    level_key_func = lambda level_str: int(level_str[1:]) # N5 -> 5, N1 -> 1
    level_sort_reverse = True # True means N1 comes before N5 (higher level priority)

    for key, data in intermediate_vocab.items():
        if not data['levels']: continue

        sorted_levels = sorted(list(data['levels']), key=level_key_func, reverse=level_sort_reverse)
        final_level = sorted_levels[0] # Pick the highest priority level

        final_source_kanji = None
        for src in data['sources']:
            if src['level'] == final_level:
                final_source_kanji = src['kanji'] if src['kanji'] else None
                break

        final_vocab[key] = {
            'level': final_level, # Store the level string like "N5"
            'english': data['english'],
            'source_kanji': final_source_kanji
        }
        total_entries_added +=1

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
            return True
    return False


def main():
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
    except NameError:
         print("Warning: __file__ not defined, using current working directory as script directory.")
         script_dir = os.getcwd()

    project_root = os.path.abspath(os.path.join(script_dir, ".."))
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
    updates = [] # List of tuples: (jlpt_level_value, rowid)
    processed_count = 0
    match_kanji_count = 0
    match_kana_only_count = 0
    match_reading_kanji_mismatch_count = 0
    match_ambiguous_meaning_ok_count = 0
    match_ambiguous_meaning_fail_count = 0
    already_tagged_correctly_count = 0 # Renamed for clarity
    no_match_count = 0

    print(f"Connecting to database: {db_path}")
    try:
        conn = sqlite3.connect(db_path)
        c = conn.cursor()

        print("Fetching entries from dict_index (this may take time)...")
        # *** Select the new jlpt_level column ***
        c.execute("SELECT rowid, kanji, reading, meaning, tags, jlpt_level FROM dict_index") # Added jlpt_level

        print("Processing database entries...")
        for row in c:
            # *** Unpack the new jlpt_level column ***
            rowid, db_kanji, db_reading, db_meaning, db_tags, db_jlpt_level = row # Added db_jlpt_level
            processed_count += 1
            if processed_count % 20000 == 0:
                print(f"  Processed {processed_count} entries...")

            lvl = None # This will store the determined level like "N5", "N4" etc.
            csv_english_set = None
            match_type = "No Match"
            vocab_entry = None

            # --- Matching Logic --- (Same as before)
            if db_kanji and db_kanji in vocab_map:
                vocab_entry = vocab_map[db_kanji]
                lvl = vocab_entry['level']
                csv_english_set = vocab_entry['english']
                match_type = "Kanji Match"
                match_kanji_count += 1

            elif not db_kanji and db_reading and db_reading in vocab_map:
                vocab_entry = vocab_map[db_reading]
                lvl = vocab_entry['level']
                csv_english_set = vocab_entry['english']
                match_type = "Kana-Only DB Entry Match"
                match_kana_only_count += 1

            elif db_kanji and db_reading and db_reading in vocab_map:
                potential_vocab_entry = vocab_map[db_reading]
                potential_lvl = potential_vocab_entry['level']
                potential_csv_english_set = potential_vocab_entry['english']
                vocab_source_kanji = potential_vocab_entry.get('source_kanji')

                if db_kanji and vocab_source_kanji and db_kanji != vocab_source_kanji:
                    match_type = "Mismatch (Reading Match, Different Kanji)"
                    match_reading_kanji_mismatch_count += 1
                    if DEBUG:
                        print(f"\n  [Debug] Kanji Mismatch on Reading Match for rowid={rowid}: DB='{db_kanji}', CSV Source='{vocab_source_kanji}'. No JLPT level set.")
                else:
                    match_type = "Ambiguous (Reading Match on Kanji Entry)"
                    if DEBUG:
                         # Shortened debug output slightly
                         print(f"\n  [Debug] Ambiguous case rowid={rowid}: DB='{db_kanji}' Reading='{db_reading}'. Vocab Key='{db_reading}' Level='{potential_lvl}' SourceKanji='{vocab_source_kanji}'")

                    if check_meaning_overlap(db_meaning, potential_csv_english_set):
                        vocab_entry = potential_vocab_entry
                        lvl = potential_lvl # Set level on successful meaning check
                        csv_english_set = potential_csv_english_set
                        match_type += " -> Meaning OK"
                        match_ambiguous_meaning_ok_count += 1
                        if DEBUG: print("    Meaning Check: PASSED")
                    else:
                        match_type += " -> Meaning FAILED"
                        match_ambiguous_meaning_fail_count += 1
                        if DEBUG: print("    Meaning Check: FAILED")
            else:
                no_match_count += 1
                match_type = "No Match"

            # --- Tagging Logic (Simplified for dedicated column) ---
            if lvl: # If a level was determined by any successful match
                # Check if the jlpt_level column already has the correct value
                if db_jlpt_level == lvl:
                    already_tagged_correctly_count += 1
                    if DEBUG and match_type not in ["No Match", "Mismatch (Reading Match, Different Kanji)", "Ambiguous (Reading Match on Kanji Entry) -> Meaning FAILED"]:
                         print(f"    [Debug] Rowid={rowid} ({db_kanji or db_reading}): Already has correct jlpt_level '{lvl}'. Skipping update.")
                else:
                    # Add update job: (level_value, rowid)
                    updates.append((lvl, rowid))
                    if DEBUG:
                        matched_word = db_kanji if match_type == "Kanji Match" else db_reading
                        action = "Setting" if not db_jlpt_level else f"Updating (from '{db_jlpt_level}')"
                        print(f"    [Debug] Rowid={rowid} ({matched_word}): {action} jlpt_level to '{lvl}'. Match type: '{match_type}'.")

        print("-" * 20)
        print(f"Finished processing {processed_count} database entries.")
        print("Matching Summary:")
        print(f"  - Kanji Matches (High Confidence): {match_kanji_count}")
        print(f"  - Kana-Only DB Entry Matches (Medium Confidence): {match_kana_only_count}")
        print(f"  - Reading Matches w/ Kanji: Skipped (Kanji Mismatch): {match_reading_kanji_mismatch_count}")
        print(f"  - Reading Matches w/ Kanji: Processed (Meaning Check Passed): {match_ambiguous_meaning_ok_count}")
        print(f"  - Reading Matches w/ Kanji: Processed (Meaning Check Failed): {match_ambiguous_meaning_fail_count}")
        print(f"  - Entries with No Match Found: {no_match_count}")
        print(f"  - Entries Already Correctly Tagged in jlpt_level: {already_tagged_correctly_count}")
        print("-" * 20)
        total_updates_pending = len(updates)
        print(f"Total entries needing jlpt_level added/updated: {total_updates_pending}")
        # Sanity check (approximate)
        potential_updates = match_kanji_count + match_kana_only_count + match_ambiguous_meaning_ok_count
        print(f"  (For reference: Kanji + KanaOnly + AmbiguousOK = {potential_updates})")
        print("-" * 20)


        if updates:
            print(f"Applying {len(updates)} updates to the database (setting jlpt_level)...")
            # *** Update the new jlpt_level column ***
            c.executemany("UPDATE dict_index SET jlpt_level = ? WHERE rowid = ?", updates)
            conn.commit()
            print(f"Successfully committed {len(updates)} updates.")
        else:
            print("No entries required updating.")

    except sqlite3.Error as e:
        # Check if the error is due to the missing column
        if "no such column: jlpt_level" in str(e):
             print("\n*** Database Error: Column 'jlpt_level' not found! ***")
             print("Please ensure you have added the column using:")
             print("ALTER TABLE dict_index ADD COLUMN jlpt_level TEXT;")
             print("before running this script again.\n")
        else:
            print(f"Database error: {e}")
        if conn:
             conn.rollback()
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
    finally:
        if conn:
            conn.close()
            print("Database connection closed.")

# --- How to Run ---
# 1. **Add the column:** Run `ALTER TABLE dict_index ADD COLUMN jlpt_level TEXT;`
#    in your SQLite database *before* running this script.
# 2. Prerequisites: (Same as before)
# 3. Execution: (Same as before - `python tag_jlpt.py`)
# 4. Debugging: (Same as before)
# 5. Backup: (Still recommended!)
# ---

if __name__ == "__main__":
    main()