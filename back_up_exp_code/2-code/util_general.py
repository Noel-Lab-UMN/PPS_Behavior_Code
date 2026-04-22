import json
import csv 
import math
import sys
def load_json(config_path):
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Failed to load config from {config_path}: {e}")
        sys.exit(1)

def deep_update(base, override):
    """
    Recursively update dict `base` with values from `override`.
    Only overwrites keys that exist in override.
    """
    for key, value in override.items():
        if isinstance(value, dict) and key in base and isinstance(base[key], dict):
            deep_update(base[key], value)
        else:
            base[key] = value
    return base


def count_reward(file_path):
    total_reward = 0
    n_rewarded_trials = 0
    previous_value = None
    has_reward_amount = False

    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)

        # Normalize headers
        reader.fieldnames = [name.strip() for name in reader.fieldnames]

        has_reward_amount = 'reward_amount' in reader.fieldnames

        for row in reader:
            # -------- Case 1: reward_amount exists --------
            if has_reward_amount:
                try:
                    val = float(row['reward_amount'])
                except (ValueError, TypeError):
                    continue

                total_reward += val

                if val > 0:
                    n_rewarded_trials += 1

            # -------- Case 2: fallback to reward_state --------
            else:
                if 'reward_state' not in row:
                    raise ValueError("Column 'reward_state' not found in CSV.")

                try:
                    current_value = int(row['reward_state'].strip())
                except (ValueError, AttributeError):
                    continue

                # count only onset (avoid consecutive 1s)
                if current_value == 1 and previous_value != 1:
                    n_rewarded_trials += 1

                previous_value = current_value
    
    if not has_reward_amount:
        total_reward = math.nan



    return total_reward, n_rewarded_trials, has_reward_amount

