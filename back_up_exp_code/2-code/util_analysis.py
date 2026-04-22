import json
import csv 
import math
import sys
import pandas as pd
import numpy as np
import os
import glob

from util_general import load_json

def analyze_move_wheel(folder_path, prefix="sync_log_wheelmove"):
    """Analyze move-wheel habituation across all matching CSV files in a folder."""
    
    pattern = os.path.join(folder_path, f"{prefix}*.csv")
    csv_files = sorted(glob.glob(pattern))
    
    if len(csv_files) == 0:
        raise FileNotFoundError(f"No CSV files found matching: {pattern}")
    
    all_vel_before_reward = []
    all_vel = []
    total_rewards_count = 0
    total_reward_amount = 0.0
    total_time_sec = 0.0

    for csv_path in csv_files:
        df = pd.read_csv(csv_path)

        if df.empty:
            continue

        # Identify reward events
        reward_rows = df[df["reward_amount"] > 0]
        total_rewards_count += len(reward_rows)
        total_reward_amount += reward_rows["reward_amount"].sum()

        # Velocity right before reward, within this file only
        prev_idx = reward_rows.index - 1
        prev_idx = prev_idx[prev_idx >= 0]

        if len(prev_idx) > 0:
            vel_before_reward = df.loc[prev_idx, "running_velocity"].to_numpy()
            all_vel_before_reward.append(vel_before_reward)

        vel = df["running_velocity"].to_numpy()
        vel = vel[vel != 0]            # exclude zeros
        all_vel.append(vel)

        # Duration of this file
        t = df["t_global_s"].dropna()
        if len(t) >= 2:
            total_time_sec += t.iloc[-1] - t.iloc[0]

    # Pool all velocities across files
    if len(all_vel_before_reward) > 0:
        all_vel_before_reward = np.concatenate(all_vel_before_reward)
        median_vel_before_reward = np.nanmedian(all_vel_before_reward)
    else:
        median_vel_before_reward = np.nan
    
    if len(all_vel) > 0:
        all_vel = np.concatenate(all_vel)
        median_vel_all = np.nanmedian(all_vel)
    else:
        median_vel_all = np.nan

    minute_total = total_time_sec / 60 if total_time_sec > 0 else np.nan
    reward_rate_count = total_rewards_count / minute_total if minute_total > 0 else np.nan
    reward_rate_ul = total_reward_amount / minute_total if minute_total > 0 else np.nan

    performance_results = {
        "median_vel_before_reward": median_vel_before_reward,
        "median_vel_all": median_vel_all,
        "reward_rate_count": reward_rate_count,
        "reward_rate_ul": reward_rate_ul,
        "reward_rate_count": reward_rate_count,
        "total_reward_amount": total_reward_amount,
        "total_time_min": minute_total,
        "n_files": len(csv_files),
        "files": csv_files,
    }

    return performance_results

def update_config_move_wheel(previous_config_path, performance_results):
    "Update configurations based on the most recent performance"
    REWARD_RATE_COUNT_UPPER_THRESHOLD = 6 # 6 times per minute
    REWARD_RATE_COUNT_LOWER_THRESHOLD = 3 # 3 times per minute

    VELOCITY_THRESHOLD_CEILING = 30.0 # 
    VELOCITY_THRESHOLD_FLOOR   = 5.0  
    #### only make it more diffcult when reward_rate_count is larger than a threshold
    if performance_results["reward_rate_count"] > REWARD_RATE_COUNT_UPPER_THRESHOLD:
        ##### increase velocity to the median of velocity before rewards were given, but no higher than a ceiling value
        new_vel_threshold = min(performance_results["median_vel_before_reward"], VELOCITY_THRESHOLD_CEILING)

    ##### make if easier when reward_rate_count is lower than a threshold
    if performance_results["reward_rate_count"] < REWARD_RATE_COUNT_LOWER_THRESHOLD:
        new_vel_threshold = max(performance_results["median_vel_all"], VELOCITY_THRESHOLD_FLOOR)

    ##### If already reached threshold, start to decrease reward target
    prev_config             = load_json(previous_config_path)
    previous_threshold      = prev_config["config"]["experiment"]["VELOCITY_THRESHOLD"]
    previous_reward_target  = prev_config["config"]["reward"]["REWARD_TARGET"] 

    if  previous_reward_target == 3.0:
        new_reward_target = 3.0
    elif previous_reward_target == 4.5 and previous_threshold == REWARD_RATE_COUNT_UPPER_THRESHOLD and new_vel_threshold == REWARD_RATE_COUNT_UPPER_THRESHOLD: 
        new_reward_target = 3.0
    else:
        new_reward_target = 4.5
    
    new_params                  = {}
    new_params["experiment"]    = {}
    new_params["reward"]        = {}
    new_params["experiment"]["VELOCITY_THRESHOLD"]  = new_vel_threshold
    new_params["reward"]["REWARD_TARGET"]           = new_reward_target

    return new_params
    
    