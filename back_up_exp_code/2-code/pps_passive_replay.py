""""
This scripts plays past goal-directed trajectories to animals
'"""

import csv
import random
import threading
import multiprocessing as mp
import time
import os
import glob
import traceback
from time import perf_counter
from datetime import datetime


import json

import numpy as np
from psychopy import visual, core, event, monitors
from pybpodapi.protocol import Bpod

from util_general import load_json, deep_update, count_reward

import pandas as pd


#RUNTIME_TIMEOUT_MINUTES = 20.0  # runtime timeout in minutes (None or <=0 disables)


try:
    from pybpod_rotaryencoder_module.module_api import RotaryEncoderModule
except Exception:
    RotaryEncoderModule = None

# try to import pyserial for Arduino reward control
try:
    import serial
except Exception:
    serial = None

# Prompt for mouse name (blocking console input)
mouse_name  = input("Enter mouse name (short, no spaces): ").strip()
if not mouse_name:
    mouse_name = "mouseUNK"

RIG_NAME    = input("Enter rig name: ").strip()
RIG_NAME_LIST = ['PPS_training_Rig_3', 'PPS_training_Rig_2','PPS_training_Rig_1', 'PPS_recording_Rig_1']
if RIG_NAME not in RIG_NAME_LIST:
    raise ValueError(f"{RIG_NAME} not found in existing rig list")

# prompt for whether we're doring ephys recording and need to sync
while True:
    choice_ephys = input("Are you running ephys recording ([y] or [n]): ").strip().lower()

    if choice_ephys in {"y", "yes"}:
        DO_EPHYS = True
        break
    if choice_ephys in {"n", "no"}:
        DO_EPHYS = False
        break
    print("Please enter 'y or 'n")

#### read rig specifc parameters
home_path           = "Z:/17. Goal-directed-PPS"
RIG_CONFIG_PATH = os.path.join(home_path, f"3-config-json/rig_hardware/config_{RIG_NAME}.json")
hardware_config = load_json(RIG_CONFIG_PATH)
EXP_CONFIG_PATH = os.path.join(home_path, f"3-config-json/exp_default/config_default_pps_passive_replay.json")
default_exp_config = load_json(EXP_CONFIG_PATH)
config_all = deep_update(hardware_config, default_exp_config)

ANIMAL_CONFIG_PATH = os.path.join(home_path, f"3-config-json/subject_exp/{mouse_name}/config_{mouse_name}_pps_passive_replay.json")
#if os.path.exists(ANIMAL_CONFIG_PATH):
animal_config = load_json(ANIMAL_CONFIG_PATH)
config_all = deep_update(config_all, animal_config)
print(f"[INFO] Loaded animal-specific parameters from: {ANIMAL_CONFIG_PATH}")
# else:
#     print(f"[WARNING] {ANIMAL_CONFIG_PATH} not found. Using default parameters only.")


rig_conf                    = config_all["hardware"]
exp_conf                    = config_all["experiment"]
reward_conf                 = config_all["reward"]


ENC_SERIAL_PORT             = rig_conf["ENC_SERIAL_PORT"]
ARDUINO_PORT                = rig_conf["ARDUINO_PORT"]
SCREEN_ID                   = rig_conf["SCREEN_ID"]
SCREEN_WIDTH_CM             = rig_conf["SCREEN_WIDTH_CM"]
SCREEN_HEIGHT_CM            = rig_conf["SCREEN_HEIGHT_CM"]
SCREEN_PIX                  = tuple(rig_conf["SCREEN_PIX"])
ARDUINO_BAUD                = rig_conf["ARDUINO_BAUD"]
ARDUINO_OPEN_ON_START       = rig_conf["ARDUINO_OPEN_ON_START"]
MIN_INTER_REWARD_S          = rig_conf["MIN_INTER_REWARD_S"]
FRAME_RATE                  = rig_conf["FRAME_RATE"]
WRAP_DETECT_TICKS           = rig_conf["WRAP_DETECT_TICKS"]
STARTUP_WAIT_S              = rig_conf["STARTUP_WAIT_S"]
LOG_FLUSH_INTERVAL_FRAMES   = rig_conf["LOG_FLUSH_INTERVAL_FRAMES"]
REWARD_AMOUNT_LIST          = rig_conf["REWARD_AMOUNT_LIST"]
REWARD_DURATION_MS_LIST     = rig_conf["REWARD_DURATION_MS_LIST"] 


DO_READ_JSON                = exp_conf["DO_READ_JSON"] 
REPLAY_TYPE                 = exp_conf["REPLAY_TYPE"] 
# CSV_FILENAME_LIST           = exp_conf["CSV_FILENAME_LIST"] 
# if CSV_FILENAME_LIST == ["synthetic_PPS_trajectory_habituation.csv"]:
#     X_UNIT = "cm"
# else:
#     X_UNIT = "deg"
# #X_UNIT                      = exp_conf["X_UNIT"]
COLUMN_TO_READ              = exp_conf["COLUMN_TO_READ"] 
RUNTIME_TIMEOUT_MINUTES     = exp_conf["RUNTIME_TIMEOUT_MINUTES"]
WHEEL_GAIN_CM_PER_TICK      = exp_conf["WHEEL_GAIN_CM_PER_TICK"]
#BALL_OPACITY                = exp_conf["BALL_OPACITY"]  
INTER_SPAWN_INTERVAL        = exp_conf["INTER_SPAWN_INTERVAL"]
STATIONARY_INTERVAL         = exp_conf["STATIONARY_INTERVAL"]
STATIONARY_TOLERANCE        = exp_conf["STATIONARY_TOLERANCE"] 
WARMUP_S                    = exp_conf["WARMUP_S"]
SPACE_DEGREES               = exp_conf["SPACE_DEGREES"]  

MOVEMENT_THRESHOLD          = exp_conf["MOVEMENT_THRESHOLD"] 


# REWARD_AMOUNT_LIST          = reward_conf["REWARD_AMOUNT_LIST"] 

# ==================================================================
# PRBS parameters, only call when recording is on
if DO_EPHYS:
    prbs_conf = config_all["prbs"]

    PRBS_MIN_INTERVAL           = prbs_conf["PRBS_MIN_INTERVAL"]
    PRBS_MAX_INTERVAL           = prbs_conf["PRBS_MAX_INTERVAL"]
    BPOD_SERIAL_PORT            = prbs_conf["BPOD_SERIAL_PORT"]
    PRBS_CHANNEL                = prbs_conf["PRBS_CHANNEL"]
    TRIAL_CHANNEL               = prbs_conf["TRIAL_CHANNEL"]
    REWARD_CHANNEL              = prbs_conf["REWARD_CHANNEL"]
    TRIAL_START_SIGNAL_DURATION = prbs_conf["TRIAL_START_SIGNAL_DURATION"]
    REWARD_SIGNAL_DURATION      = prbs_conf["REWARD_SIGNAL_DURATION"] 

def find_session_csvs(home_dir, mouse_name, date_str):
    session_dir = os.path.join(home_dir, f"{mouse_name}_{date_str}")
    pattern = f"sync_log_pps_behav_{mouse_name}_{date_str}_*.csv"
    search_path = os.path.join(session_dir, pattern)

    csv_files = glob.glob(search_path)

    # sort by filename (important for chronological order)
    csv_files = sorted(csv_files)

    if len(csv_files) == 0:
        raise ValueError(f"No CSV files found in {session_dir} with pattern {pattern}")

    print(f"[INFO] Found {len(csv_files)} CSV files to replay:")
    for f in csv_files:
        print(f"   {os.path.basename(f)}")

    return csv_files



# session folder uses date only (YYYYMMDD)
meta_root = os.path.join(home_path, "1-data/metadata")
os.makedirs(meta_root, exist_ok=True)
date_str = datetime.now().strftime("%Y%m%d")
session_folder_name = f"{mouse_name}_{date_str}"
session_dir = os.path.join(meta_root, session_folder_name)
os.makedirs(session_dir, exist_ok=True)
print(f"[INFO] Session metadata directory: {session_dir}", flush=True)

match REPLAY_TYPE:
    case "habituation":
        X_UNIT = "cm"
        csv_filename_list = [os.path.join(home_path, "5-other", "synthetic_PPS_trajectory_habituation.csv")]
        MOVEMENT_THRESHOLD = 0.0
    case "real_replay":
        X_UNIT = "deg"
        #### Read .csv file
        csv_filename_list = find_session_csvs(meta_root, mouse_name, date_str)
        RUNTIME_TIMEOUT_MINUTES = 240.0

# main sync log filename
current_time  = datetime.now().strftime("%H%M")
SYNC_LOG_FILENAME = os.path.join(session_dir, f"sync_log_pps_passive_{mouse_name}_{date_str}_{current_time}.csv")
EXP_CONFIG_FILENAME = os.path.join(session_dir, f"exp_config_pps_passive_{mouse_name}_{date_str}_{current_time}.json")
### csv file name to load
folder_root         =  os.path.join(os.getcwd(), "test_passive")
# csv_file_name       =  os.path.join(folder_root, "example_csv_test_passive.csv")
#X_UNIT              = 'cm' #  cm or deg
# csv_file_folder       = os.path.join(home_path, "5-other")

REPLAY_STATE_FILENAME = os.path.join(session_dir, f"replay_state_pps_passive_{mouse_name}_{date_str}.json")

reward_duration_dict   = dict(zip(REWARD_AMOUNT_LIST, REWARD_DURATION_MS_LIST))


config_to_save = {
    "metadata": {
        "rig_name": RIG_NAME,
        "experiment_name": "move_wheel_habituation",
        "timestamp": f"{date_str}_{current_time}",
    },
    "config": config_all
}

with open(EXP_CONFIG_FILENAME, "w") as f:
    json.dump(config_to_save, f, indent=2)




json_file           =  os.path.join(folder_root, "example_json_test_passive.json")
#COLUMN_TO_READ      = 'slot1'
#### scv file name to write
sync_f              = open(SYNC_LOG_FILENAME, 'w', newline='')
sync_writer         = csv.writer(sync_f)
if DO_EPHYS:
    header = ['prbs_val',
        'frame_idx', 't_global_s', 'reward_state','reward_amount',
        'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'delta_cm',
        'running_tick_sum','wheel_is_stationary']
else:
    header = [
        'frame_idx', 't_global_s', 'reward_state','reward_amount',
        'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'delta_cm',
        'running_tick_sum','wheel_is_stationary']
header.append(f"slot{1}")

sync_writer.writerow(header)
sync_f.flush()

# if DO_READ_JSON: #### read the parameters from json file
#     with open(json_file, 'r') as f:
#         params = json.load(f)

#     SCREEN_WIDTH_CM = params["SCREEN_WIDTH_CM"]
#     BALL_OPACITY    = params['BALL_OPACITY']
# else:
#     # Screen / space geometry
#     SCREEN_WIDTH_CM = 55.88
#     SCREEN_HEIGHT_CM = 96.26
#     SPACE_WIDTH_CM = SCREEN_WIDTH_CM * 2.0
#     SCREEN_PIX = (1080, 1920)
#     SPACE_DEGREES = 360
#     CIRCLE_RADIUS_CM = 3.0
#     BALL_OPACITY = 1.0

SPACE_WIDTH_CM = SCREEN_WIDTH_CM * 2.0
half_screen_h = SCREEN_HEIGHT_CM / 2.0
# --- Display / timing / encoder ---
#FRAME_RATE = 60
TARGET_DT = 1.0 / FRAME_RATE



def save_replay_state(state_file, spawn_idx, csv_filename_list):
    state = {
        "spawn_idx": int(spawn_idx),
        "csv_file": csv_filename_list,
        "saved_at": datetime.now().isoformat(timespec="seconds")
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)

def load_replay_state(state_file):
    if not os.path.exists(state_file):
        return None
    with open(state_file, "r") as f:
        return json.load(f)
    

# ===================================
# Define PRBS helpers
# ===================================
def send_reward_pulse_hw_nonblocking():
    global bpod
    if bpod is None:
        return
    try:
        bpod.manual_override(Bpod.ChannelTypes.OUTPUT, Bpod.ChannelNames.BNC,
                             channel_number=REWARD_CHANNEL, value=1)
    except Exception as e:
        print("Warning: send_trial_pulse_hw_nonblocking failed to set high:", e)

    t = threading.Timer(REWARD_SIGNAL_DURATION,
                        lambda: bpod.manual_override(Bpod.ChannelTypes.OUTPUT, Bpod.ChannelNames.BNC,
                                                     channel_number=REWARD_CHANNEL, value=0))
    t.daemon = True
    t.start()

def send_prbs_bit_hw(bit):
    """Send PRBS bit to Bpod PRBS BNC channel (safe wrapper)."""
    global bpod
    if bpod is None:
        return
    try:
        bpod.manual_override(Bpod.ChannelTypes.OUTPUT, Bpod.ChannelNames.BNC,
                             channel_number=PRBS_CHANNEL, value=int(bit))
    except Exception as e:
        print("Warning: send_prbs_bit_hw failed:", e)

def send_trial_pulse_hw_nonblocking():
    """Set trial BNC high for TRIAL_START_SIGNAL_DURATION, non-blocking using Timer."""
    global bpod
    if bpod is None:
        return
    try:
        bpod.manual_override(Bpod.ChannelTypes.OUTPUT, Bpod.ChannelNames.BNC,
                             channel_number=TRIAL_CHANNEL, value=1)
    except Exception as e:
        print("Warning: send_trial_pulse_hw_nonblocking failed to set high:", e)

    t = threading.Timer(TRIAL_START_SIGNAL_DURATION,
                        lambda: bpod.manual_override(Bpod.ChannelTypes.OUTPUT, Bpod.ChannelNames.BNC,
                                                     channel_number=TRIAL_CHANNEL, value=0))
    t.daemon = True
    t.start()

# -------------------------
# === PRBS THREAD ===
# -------------------------
def prbs_thread_fn():
    """
    Background PRBS toggler: flips prbs_shared at random intervals and writes to Bpod BNC.
    This runs as a thread and uses prbs_shared.get_lock() to update the shared integer.
    """
    print("[PRBS] thread started.")
    # Immediately write the initial state once (so hardware & recordings have a known starting bit)
    with prbs_shared.get_lock():
        bit = int(prbs_shared.value)
    send_prbs_bit_hw(bit)

    while prbs_running_event.is_set():
        interval = random.uniform(PRBS_MIN_INTERVAL, PRBS_MAX_INTERVAL)
        time.sleep(interval)
        with prbs_shared.get_lock():
            prbs_shared.value ^= 1
            bit = int(prbs_shared.value)
        send_prbs_bit_hw(bit)
    print("[PRBS] thread exiting.")



def compute_spawn_movement(group, X_UNIT='deg'):
    """
    MATLAB equivalent of:
        delta_hori_cm = raw_data.delta_cm(idx)
        sum_abs_delta_hori_cm = sum(abs(delta_hori_cm))
    Return values in cm
    """

    if X_UNIT == 'deg':
        x_cm = group['x_deg'].apply(deg_to_screen_cm).to_numpy(dtype=float)
    else:
        x_cm = group['x_cm'].to_numpy(dtype=float)

    if len(x_cm) <= 1:
        return 0.0

    delta_hori_cm = np.diff(x_cm)
    sum_abs_delta_hori_cm = np.sum(np.abs(delta_hori_cm))

    return float(sum_abs_delta_hori_cm)

def filter_spawns_by_movement(ball_data, movement_threshold = MOVEMENT_THRESHOLD, X_UNIT='deg'):
    keep_groups = []
    skipped_ids = []

    for spawn_id_global, group in ball_data.groupby('spawn_id_global', sort=False):
        movement = compute_spawn_movement(group, X_UNIT=X_UNIT)

        if movement >= movement_threshold:
            keep_groups.append(group)
        else:
            skipped_ids.append((spawn_id_global, group['spawn_id'].iloc[0], movement))

    if len(keep_groups) == 0:
        filtered = ball_data.iloc[0:0].copy()
    else:
        filtered = pd.concat(keep_groups, axis=0)

    print(f"[INFO] Kept {len(keep_groups)} spawns, skipped {len(skipped_ids)} spawns")
    # for spawn_id_global, spawn_id_real, movement in skipped_ids[:10]:
    #     print(f"    skipped global={spawn_id_global}, real={spawn_id_real}, movement={movement:.3f}")

    return filtered

def parse_sync_log(csv_file_name, column_name='slot_1', X_UNIT = X_UNIT, file_id=0, spawn_offset=0):
    """
    Read a csv log and extract spawn_id, x_deg, y_cm, is_visible
    from the column containing 'spawn_id|x_deg|y_cm|is_visible|ball_radius'.
    
    Returns a dataframe with parsed variables.
    """

    df = pd.read_csv(csv_file_name)

    # drop the empty columns
    ball_col = df[column_name].dropna()
    ball_col = ball_col[ball_col.astype(str).str.strip() != '']
   
    # split into up to 7 pieces
    ball_data = ball_col.str.split('|', expand=True, n=6)

    n_cols = ball_data.shape[1]

    if n_cols < 5:
        raise ValueError(
            f"{csv_file_name}: expected at least 5 fields in {column_name}, got {n_cols}"
        )

    # ---------- identify format ----------
    # old: spawn_id|x_deg/x_cm|y_cm|is_visible|ball_radius
    # new: spawn_id|x_deg/x_cm|y_cm|radius|contrast|velocity|...
    if n_cols >= 7:
        file_format = 'new'
    else:
        # if only 5 columns, try to infer from column 4
      
        file_format = 'old'
    ### we don
    ball_data = ball_data.iloc[:, :5]  
    match file_format:
        case 'old':
            
            # rename columns
            match X_UNIT:
                case 'deg':
                    ball_data.columns = ['spawn_id', 'x_deg', 'y_cm', 'is_visible','ball_radius']
                    ball_data['x_deg']          = ball_data['x_deg'].astype(float)
                case 'cm':
                    ball_data.columns = ['spawn_id', 'x_cm', 'y_cm', 'is_visible','ball_radius']
                    ball_data['x_cm']          = ball_data['x_cm'].astype(float)

            # convert types
            ball_data['is_visible']     = ball_data['is_visible'].astype(bool)
            # so that this opacity can be easily used in the same way in the following code.
            # real replay show always have opacity information. If want to generate new habituation trajectories with lower opacity, makes sure to include this in MATLAB code
            ball_data['opacity']        = ball_data['is_visible'] 
        case 'new':
            match X_UNIT:
                case 'deg':
                    ball_data.columns = ['spawn_id', 'x_deg', 'y_cm','ball_radius','opacity']
                    ball_data['x_deg']          = ball_data['x_deg'].astype(float)
                case 'cm':
                    ball_data.columns = ['spawn_id', 'x_cm', 'y_cm', 'ball_radius','opacity']
                    ball_data['x_cm']          = ball_data['x_cm'].astype(float)
             # convert types
            
            ball_data['opacity']        = ball_data['opacity'].astype(float)
    
    ball_data['spawn_id']       = ball_data['spawn_id'].astype(int)
    ball_data['y_cm']           = ball_data['y_cm'].astype(float)
    ball_data['ball_radius']    = ball_data['ball_radius'].astype(float)

    # ===== NEW LINES =====
    ball_data['reward_state'] = df.loc[ball_data.index, 'reward_state']
    ball_data['reward_amount'] = df.loc[ball_data.index, 'reward_amount']

    # new
    ball_data['source_file'] = os.path.basename(csv_file_name)
    ball_data['file_id'] = file_id
    ball_data['spawn_id_global'] = ball_data['spawn_id'] + spawn_offset

    return ball_data

def load_all_replay_data(csv_file_name_list, column_name='slot1', X_UNIT=X_UNIT):
    all_data = []
    spawn_offset = 0

    for file_id, csv_path in enumerate(csv_file_name_list):
        one = parse_sync_log(
            csv_path,
            column_name=column_name,
            X_UNIT=X_UNIT,
            file_id=file_id,
            spawn_offset=spawn_offset
        )
        all_data.append(one)

        if len(one) > 0:
            spawn_offset = int(one['spawn_id_global'].max())

    if len(all_data) == 0:
        raise ValueError("No replay data loaded.")

    ball_data_all = pd.concat(all_data, axis=0)
    #spawn_groups = list(ball_data_all.groupby('spawn_id_global', sort=False))
    return ball_data_all

def deg_to_screen_cm(deg, space_cm = SPACE_WIDTH_CM):
    d = (deg + 180) % 360 - 180
    d_cm = d / SPACE_DEGREES * space_cm
    return d_cm

# def run_inter_spawn_interval(win, inter_spawn_interval = INTER_SPAWN_INTERVAL):
#     win.flip(clearBuffer=True)
#     time.sleep(inter_spawn_interval)

# def wait_for_stationary_and_log_between_spawns(
#         win, encoder, sync_writer, sync_f, frame_idx, reward_state_pulse_pending,
#         sync_start_ts, LOG_FLUSH_INTERVAL_FRAMES = LOG_FLUSH_INTERVAL_FRAMES, TARGET_DT = TARGET_DT,
#         STATIONARY_TOLERANCE = STATIONARY_TOLERANCE, STATIONARY_INTERVAL = STATIONARY_INTERVAL,  inter_spawn_interval = INTER_SPAWN_INTERVAL):

def wait_for_stationary_and_log_between_spawns():
    global win, encoder,sync_writer, sync_f, frame_idx, reward_state_pulse_pending,sync_start_ts, prbs_shared
    delta_tick_history = []
    running_tick_sum = 0.0
    interval_start_ts = perf_counter()
    reference_ticks = int(encoder.current_position())
    while True:
        frame_loop_start = perf_counter()

        win.flip(clearBuffer=True)

        [enc_ticks, delta_ticks_raw, delta_ticks, delta_cm] = detect_wheel(encoder, reference_ticks)
        reference_ticks = enc_ticks
        

        

        wheel_is_stationary = False # reset to false unless the below condition is met
        if (perf_counter() - interval_start_ts) >  (STATIONARY_INTERVAL / 1000):
            running_tick_sum -= delta_tick_history[0]
            delta_tick_history.pop(0)
        delta_tick_history.append(abs(delta_ticks))
        running_tick_sum += abs(delta_ticks)

        if running_tick_sum < STATIONARY_TOLERANCE: ### stationary enough in the last time window
            wheel_is_stationary = True

        enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{delta_cm:.4f}", running_tick_sum, wheel_is_stationary]
      

        if reward_state_pulse_pending:
            reward_state_now = 1
            reward_state_pulse_pending = False
        else:
            reward_state_now = 1 if (perf_counter() < reward_active_until) else 0
            
        if sync_start_ts is None:
            sync_start_ts = perf_counter()
        t_global = f"{(perf_counter() - sync_start_ts):.6f}"

        reward_amount = 0   
        if DO_EPHYS:
            with prbs_shared.get_lock():
                prbs_val = int(prbs_shared.value)
            log_row = [
                prbs_val,
                frame_idx,
                t_global,
                reward_state_now,
                reward_amount
            ]
        else:
        # Start with the header
            log_row = [
                frame_idx,
                t_global,
                reward_state_now,
                reward_amount
            ]

        log_row += enc_cols
        log_row += ['']   # blank slot cell between spawns

        sync_writer.writerow(log_row)
        if frame_idx % LOG_FLUSH_INTERVAL_FRAMES == 0:
            sync_f.flush()

        frame_idx += 1

        check_escape()



        elapsed = perf_counter() - frame_loop_start
        to_wait = TARGET_DT - elapsed
        if to_wait > 0:
            core.wait(to_wait)
        
        if perf_counter() - interval_start_ts > INTER_SPAWN_INTERVAL and wheel_is_stationary:
            if DO_EPHYS:
                #### send pulse when this ball apprears on the screen
                win.callOnFlip(send_trial_pulse_hw_nonblocking)
            break

    return frame_idx, reward_state_pulse_pending

def check_escape(win=None):
    if 'escape' in event.getKeys():
        if win is not None:
            win.close()
        core.quit()

def detect_wheel(encoder, reference_ticks, gain_applied = WHEEL_GAIN_CM_PER_TICK):
    # ==============================================
    # Wheels!
    # ==============================================
    ##### Read wheel position from the encoder
    try:
        enc_ticks = int(encoder.current_position())
    except Exception:
        enc_ticks = reference_ticks

    delta_ticks_raw = enc_ticks - reference_ticks    
    
    #### correction of the raw value
    delta_ticks = delta_ticks_raw
    if abs(delta_ticks_raw) > WRAP_DETECT_TICKS:
        candidate_wrap = abs(reference_ticks - enc_ticks)
        if candidate_wrap > 0:
            estimated_wrap_ticks = candidate_wrap
        if estimated_wrap_ticks is not None and estimated_wrap_ticks > 0:
            while abs(delta_ticks) > WRAP_DETECT_TICKS and estimated_wrap_ticks > 0:
                if delta_ticks > 0:
                    delta_ticks -= estimated_wrap_ticks
                else:
                    delta_ticks += estimated_wrap_ticks
            if abs(delta_ticks) > WRAP_DETECT_TICKS:
                delta_ticks = 0
        else:
            delta_ticks = 0
    delta_cm = gain_applied * delta_ticks
    return enc_ticks, delta_ticks_raw, delta_ticks, delta_cm   

# def timing_print(label, dt_s, extra=''):
#     if dt_s >= TIMING_WARN_S:
#         suffix = f' | {extra}' if extra else ''
#         print(f"[TIMING] {label}: {dt_s:.4f}s{suffix}", flush=True)

### === send reward 
def send_reward(duration_ms):
    global last_reward_ts, arduino
    t_fn_start = perf_counter()
    now = t_fn_start
    if (now - last_reward_ts) < MIN_INTER_REWARD_S:
        return False

    if serial is None:
        print(f"[REWARD] (simulated) would deliver {duration_ms} ms (pyserial not available).", flush=True)
        last_reward_ts = now
        return True

    if arduino is None:
        t_open_start = perf_counter()
        opened = _open_arduino()
       # timing_print("_open_arduino from send_reward", perf_counter() - t_open_start)
        if opened is None:
            print(f"[REWARD ERROR] Failed to open Arduino on {ARDUINO_PORT}", flush=True)
            return False

    cmd = f"V {int(duration_ms)}\r\n".encode()
    try:
        t_write_start = perf_counter()
        written = arduino.write(cmd)
        #timing_print("arduino.write", perf_counter() - t_write_start, extra=f"bytes={written}")

        t_wait_start = perf_counter()
        core.wait(0.001)
        #timing_print("core.wait after reward write", perf_counter() - t_wait_start)

        if written <= 0:
            print("[REWARD ERROR] Serial write returned 0 bytes", flush=True)
            return False

        last_reward_ts = now
        return True
    except Exception as e:
        print(f"[REWARD ERROR] {e}", flush=True)
        return False
# ==============================
# Read csv files to replay
# ===============================

    
ball_data = load_all_replay_data(
    csv_filename_list,
    column_name=COLUMN_TO_READ,
    X_UNIT=X_UNIT
)

ball_data = filter_spawns_by_movement(
    ball_data,
    movement_threshold=MOVEMENT_THRESHOLD,
    X_UNIT=X_UNIT
)

spawn_groups = list(ball_data.groupby('spawn_id_global', sort=False))
# ============================
# Visual / window setup
# ============================
mon = monitors.Monitor('experiment_monitor_portrait')
mon.setWidth(SCREEN_WIDTH_CM)
mon.setSizePix(SCREEN_PIX)

win = visual.Window(size=SCREEN_PIX, fullscr=True, monitor=mon,
                    units='cm', color=(-1.0, -1.0, -1.0), waitBlanking=True, screen=SCREEN_ID)

#### Define ball
CIRCLE_RADIUS_CM_DEFAULT = 3.0
circle = visual.Circle(win, radius = CIRCLE_RADIUS_CM_DEFAULT, fillColor=(1.0, 1.0, 1.0),
                    lineColor=None, edges=64, pos=(0.0, 0.0), units = 'cm')

####  hide mouse
win.mouseVisible = False
mouse = event.Mouse()
mouse.setPos((0,0))


# ============================
# Encoder & devices
# ============================
try:
    if RotaryEncoderModule is None:
        raise RuntimeError("RotaryEncoderModule not available")
    encoder = RotaryEncoderModule(serialport=ENC_SERIAL_PORT)
except Exception as e:
    raise RuntimeError(f"Failed to open rotary encoder on {ENC_SERIAL_PORT}: {e}")
    win.close()
    core.quit()
    

try:
    reference_ticks = int(encoder.current_position())
except Exception:
    reference_ticks = 0

estimated_wrap_ticks = None

arduino = None
last_reward_ts = -9999.0

def _open_arduino(timeout_s=STARTUP_WAIT_S):
    global arduino
    if serial is None:
        return None
    if arduino is not None:
        return arduino
    start_t = time.time()
    while True:
        try:
            arduino = serial.Serial(ARDUINO_PORT, ARDUINO_BAUD, timeout=0.1, rtscts=False, dsrdtr=False)
            try:
                arduino.setDTR(False)
            except Exception:
                pass
            core.wait(0.02)
            print(f"[INFO] Arduino opened on {ARDUINO_PORT}@{ARDUINO_BAUD}", flush=True)
            return arduino
        except Exception as e:
            arduino = None
            if (time.time() - start_t) >= timeout_s:
                print(f"[WARN] Failed to open Arduino serial on {ARDUINO_PORT} within {timeout_s}s: {e}", flush=True)
                return None
            time.sleep(0.25)

if ARDUINO_OPEN_ON_START and serial is not None:
    _open_arduino()




success_text = visual.TextStim(win, text='SUCCESS!', height=2.5, bold=True, pos=(0.0, 0.0))




### short pause before the main loop starts
core.wait(WARMUP_S)

# ============================
# main 
# =============================
clock           = core.Clock()
#### initialization
frame_idx       = 0
sync_start_ts   = None

resume_state = load_replay_state(REPLAY_STATE_FILENAME)

if resume_state is not None:
    choice_continue = input("Do you want to continue replay ([y] or [n]): ").strip().lower()
    if choice_continue in {"y", "yes"}:
        continue_replay = True
    elif choice_continue in {"n", "no"}:
        continue_replay = False
else:
    continue_replay = False

if continue_replay:
    spawn_idx = int(resume_state["spawn_idx"]) - 1
    print(f"[INFO] Resuming from spawn_idx={spawn_idx}")
else:
    spawn_idx = -1

    print(f"[INFO] Starting from spawn_idx={spawn_idx}")

row_ptr = 0
spawn_id, spawn_rows = spawn_groups[spawn_idx]
spawn_rows = list(spawn_rows.itertuples(index=False))

new_spawn_flag = True

reward_active_until = 0.0
reward_state_pulse_pending = False
experiment_start_ts = perf_counter()



if DO_EPHYS:
    #bpod = None           # Bpod instance (set in main_session)
    # Initialize Bpod now (inside main) so child processes don't create/initialize Bpod on import
    bpod = Bpod(serial_port = BPOD_SERIAL_PORT)
    prbs_thread = None    # thread handle for PRBS

    # Multiprocessing-shared PRBS bit (logger process reads this)
    prbs_shared = mp.Value('i', 0)
    prbs_running_event = threading.Event()
    prbs_running_event.clear()

    print("Starting PRBS thread and global clock now (will persist for entire session).")
    prbs_running_event.set()

    # reset experimental timebase
    global_clock = core.Clock()
    global_clock.reset()
    # initialize prbs_shared to 0 and send a first bit
    with prbs_shared.get_lock():
        prbs_shared.value = 0
    send_prbs_bit_hw(0)
    prbs_thread = threading.Thread(target=prbs_thread_fn, daemon=True)
    prbs_thread.start()

try: 
    reference_ticks = int(encoder.current_position())
    while True:
        if new_spawn_flag:
            #frame_idx, reward_state_pulse_pending = wait_for_stationary_and_log_between_spawns(win, encoder, sync_writer, sync_f, frame_idx,reward_state_pulse_pending, sync_start_ts) 
            wait_for_stationary_and_log_between_spawns()
            spawn_idx += 1
            ### save replay state each time we finish replaying a ball
            save_replay_state(
                REPLAY_STATE_FILENAME,
                spawn_idx,
                csv_filename_list
            )
            
            if spawn_idx > len(spawn_groups):
                break   # experiment finished

            spawn_id, spawn_rows = spawn_groups[spawn_idx]
            spawn_rows = list(spawn_rows.itertuples(index=False))
            row_ptr = 0
            new_spawn_flag = False

            if RUNTIME_TIMEOUT_MINUTES and RUNTIME_TIMEOUT_MINUTES > 0:
                if (perf_counter() - experiment_start_ts) > (RUNTIME_TIMEOUT_MINUTES * 60.0):
                    print("[INFO] Runtime timeout reached — exiting.", flush=True)
                    break

        #### Record current time
      
            
        reward_sent_this_frame = False
        frame_loop_start  = perf_counter()

        
        # get x, y position
        row = spawn_rows[row_ptr]
        match X_UNIT:
            case 'deg':
                x_deg = row.x_deg
                drawn_x         = deg_to_screen_cm(x_deg)
            case 'cm':
                drawn_x = row.x_cm

        y_cm  = row.y_cm
        drawn_y         = y_cm -  half_screen_h
        ball_radius = row.ball_radius
        #is_visible = row.is_visible
        ball_opacity = row.opacity
        # is_rewarded
        is_rewarded = row.reward_state
        reward_amount = row.reward_amount

        
        # draw
        win.clearBuffer()
        
    
        circle.pos      = (drawn_x, drawn_y)
        circle.radius   = ball_radius
        circle.opacity  = float(max(0.0, min(1.0, ball_opacity)))
        circle.draw()
        win.flip()

        # wheel movement and gain
        [enc_ticks, delta_ticks_raw, delta_ticks, delta_cm] = detect_wheel(encoder, reference_ticks)
        reference_ticks = enc_ticks

        running_tick_sum = float("nan")
        wheel_is_stationary = float("nan")
        enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{delta_cm:.4f}", running_tick_sum, wheel_is_stationary]

    


        ### advace frame pointer
        row_ptr     += 1
       
        ### check if this spawn is finished
        if row_ptr >= len(spawn_rows):

            # Whether to give reward
            # this spawn was rewarded in the original experiment
            if is_rewarded and (not reward_sent_this_frame):
                open_t = reward_duration_dict[reward_amount]
                if send_reward(open_t):
                    reward_sent_this_frame = True
                    reward_active_until = perf_counter() + (open_t / 1000.0)
                    reward_state_pulse_pending = True
                    # if DO_EPHYS:
                    #     send_reward_pulse_hw_nonblocking()

            #     reward_state = 1

            # pause between spawns
        
            new_spawn_flag = True
            # if DO_EPHYS:
            #     #### send pulse when this ball apprears on the screen
            #     win.callOnFlip(send_trial_pulse_hw_nonblocking)
            

        
            # only continue when wheel is stationary

        # ====== save another log ======
        if sync_start_ts is None:
            sync_start_ts = perf_counter()
        t_global = f"{(perf_counter() - sync_start_ts):.6f}" if sync_start_ts is not None else ''

        if reward_state_pulse_pending:
            reward_state_now = 1
            reward_state_pulse_pending = False
        else:
            reward_state_now = 1 if (perf_counter() < reward_active_until) else 0

        if DO_EPHYS:
            with prbs_shared.get_lock():
                prbs_val = int(prbs_shared.value)
            log_row = [
                prbs_val,
                frame_idx,
                t_global,
                reward_state_now,
                reward_amount
            ]
        else:
        # Start with the header
            log_row = [
                frame_idx,
                t_global,
                reward_state_now,
                reward_amount
            ]

        # append to rows
        slot_cells = ['']
        slot_cells[0] = f"{spawn_id}|{drawn_x:.3f}|{y_cm:.3f}|{ball_opacity:.3f}|{ball_radius:.1f}"
        log_row += enc_cols
        log_row += slot_cells
                   
        # write row
        sync_writer.writerow(log_row)
        if frame_idx % LOG_FLUSH_INTERVAL_FRAMES == 0:
            sync_f.flush()
            
        frame_idx += 1


        # ====== check escape key press
        check_escape()

        # make sure it is one frame time
        elapsed = perf_counter() - frame_loop_start
        to_wait = TARGET_DT - elapsed
        if to_wait > 0:
            core.wait(to_wait)
        
        
        


except KeyboardInterrupt:
    print("Interrupted — exiting.", flush=True)
finally:
    # if os.path.exists(REPLAY_STATE_FILENAME):
    #     os.remove(REPLAY_STATE_FILENAME)

    try:
        sync_f.flush()
        sync_f.close()
    except Exception:
        pass

    try:
        encoder.close()
    except Exception:
        pass

    if arduino is not None:
        try:
            arduino.close()
            print(f"[INFO] Closed Arduino serial on {ARDUINO_PORT}", flush=True)
        except Exception:
            pass
    if DO_EPHYS:
        print("Session complete. Performing cleanup.")
        prbs_running_event.clear()
        if prbs_thread is not None:
            prbs_thread.join(timeout=1.0)
        try:
            bpod.close()
        except Exception:
            pass
        
    # ==== Count and print how much reward the animal got
    [total_reward, n_rewarded_trials, has_amount] = count_reward(SYNC_LOG_FILENAME)
    if has_amount:
        print(f"Total reward amount: {total_reward}")
        print(f"Number of rewarded trials: {n_rewarded_trials}")
    else:
        print(f"Total reward amount: {n_rewarded_trials} * {REWARD_TARGET} = {n_rewarded_trials * REWARD_TARGET}")

    
    win.close()
    core.quit()
    print("Clean exit.", flush=True)


