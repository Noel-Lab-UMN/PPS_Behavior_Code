import csv
import time

from time import perf_counter
from datetime import datetime


from dataclasses import dataclass, asdict
import json

import sys
import os
import numpy as np
from psychopy import visual, core, event, monitors

from util_general import load_json, deep_update, count_reward
from util_analysis import analyze_move_wheel, update_config_move_wheel

from pathlib import Path
from zoneinfo import ZoneInfo

from rig_db_client_shizhao import (
    RigDBClient,
    SessionStorageManager,
    SessionManager,
    DataRecordCSV,
    DBClientError,
    SessionAborted,
)

# encoder import (may raise if not installed on dev machine)
try:
    from pybpod_rotaryencoder_module.module_api import RotaryEncoderModule
except Exception:
    RotaryEncoderModule = None

# try to import pyserial for Arduino reward control
try:
    import serial
except Exception:
    serial = None

##
exp_name            = 'move_wheel_habituation' 
home_path           = "Z:/17. Goal-directed-PPS"
EXP_CONFIG_PATH     = os.path.join(home_path, f"3-config-json/exp_default/config_default_database_{exp_name}.json")
default_exp_config  = load_json(EXP_CONFIG_PATH)

db_conf             = default_exp_config["database"]
paths_conf          = default_exp_config["paths"]


# =============================================================================
# 2. INIT DB + STORAGE MANAGERS
# =============================================================================

client = RigDBClient(
    db_conf["base_url"],
    timeout_s=db_conf.get("timeout_s", 10.0),
)

storage = SessionStorageManager(
    local_base_dir = Path.home() / "Desktop",
    nas_base_dir=paths_conf["raw_data_dir"],
    smb_base_unc=paths_conf.get("smb_base_unc", paths_conf["raw_data_dir"]),
)

datarecord = DataRecordCSV(paths_conf["raw_data_dir"])

mgr = SessionManager(
    client,
    storage,
    datarecord=datarecord,
)





# =============================================================================
# 4. LOAD MOUSE AND RIG OPTIONS
# =============================================================================
rig_options = mgr.load_rig_options()
print("\nAvailable rigs:")
for i, opt in enumerate(rig_options, start=1):
    print(f"{i}. {opt}")

try:
    selected_index = int(input("Select rig number: ")) - 1
    selected_option = rig_options[selected_index]
except Exception:
    print("Invalid mouse selection.")
    sys.exit(1)

rig_name = selected_option
rig_id   = selected_index


mouse_options, option_to_mouse_id = mgr.load_mice_options(
    experiment_id=db_conf["experiment_id"],
    fallback_csv_path=paths_conf["mouse_record_csv"],
)

if not mouse_options:
    print("No mice available from DB or CSV fallback.")
    sys.exit(1)

print("\nAvailable mice:")
for i, opt in enumerate(mouse_options, start=1):
    print(f"{i}. {opt}")

try:
    selected_index = int(input("Select mouse number: ")) - 1
    selected_option = mouse_options[selected_index]
except Exception:
    print("Invalid mouse selection.")
    sys.exit(1)

sel = mgr.parse_selected_mouse(selected_option, option_to_mouse_id)
mouse_id = sel.mouse_id
mouse_name = sel.mouse_name

# =============================================================================
#  load rig and animal specifc parameters 
# =============================================================================
RIG_CONFIG_PATH     = os.path.join(home_path,f"3-config-json/rig_hardware/config_{rig_name}.json")
hardware_config     = load_json(RIG_CONFIG_PATH)
config_all          = deep_update(hardware_config, default_exp_config)


ANIMAL_CONFIG_PATH = os.path.join(home_path, f"3-config-json/subject_exp/{mouse_name}/config_{mouse_name}_move_wheel_habituation.json")
if os.path.exists(ANIMAL_CONFIG_PATH):
    animal_config = load_json(ANIMAL_CONFIG_PATH)
    config_all = deep_update(config_all, animal_config)
    print(f"[INFO] Loaded animal-specific parameters from: {ANIMAL_CONFIG_PATH}")
else:
    print(f"[WARNING] {ANIMAL_CONFIG_PATH} not found. Using default parameters only.")
# ====================================================================================
# Get parameter from the database
new_params_database = mgr.get_next_params(mouse_id = mouse_id,  experiment_id=db_conf["experiment_id"],
                                          experiment_name = exp_name, defaults = {}), 
# ====================================================================================
while True:
    use_base_config = input("Do you want to use parameters from local file ([L]), or database ([D]):  ").strip().lower()
    if use_base_config in {"l","local"}:
        break
    elif use_base_config in {"d","database"}:
        config_all = deep_update(config_all, new_params_database)
        break


rig_conf                    = config_all["hardware"]
exp_conf                    = config_all["experiment"]
reward_conf                 = config_all["reward"]
db_conf                     = config_all["database"]
paths_conf                  = config_all["paths"]


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
if not reward_conf.get("use_rig_calibration", True):
    REWARD_DURATION_MS_LIST     = rig_conf["REWARD_DURATION_MS_LIST"] 
    

VELOCITY_THRESHOLD          = exp_conf["VELOCITY_THRESHOLD"]
CHECK_BIN                   = exp_conf["CHECK_BIN"]
BREAK_INTERVAL              = exp_conf["BREAK_INTERVAL"]
RUNTIME_TIMEOUT_MINUTES     = exp_conf["RUNTIME_TIMEOUT_MINUTES"]
WHEEL_GAIN_CM_PER_TICK      = exp_conf["WHEEL_GAIN_CM_PER_TICK"]
WARMUP_S                    = exp_conf["WARMUP_S"]
REWARD_TARGET               = reward_conf["REWARD_TARGET"] 

# ===================================================
# Reward set up 
# ===================================================



# session folder uses date only (YYYYMMDD)
meta_root = os.path.join(home_path, "1-data/metadata")
os.makedirs(meta_root, exist_ok=True)
date_str = datetime.now().strftime("%Y%m%d")
session_folder_name = f"{mouse_name}_{date_str}"
session_dir = os.path.join(meta_root, session_folder_name)
os.makedirs(session_dir, exist_ok=True)
print(f"[INFO] Session metadata directory: {session_dir}", flush=True)

# main sync log filename
current_time        = datetime.now().strftime("%H%M")
SYNC_LOG_FILENAME   = os.path.join(session_dir, f"sync_log_wheelmove_{mouse_name}_{date_str}_{current_time}.csv")
ERROR_LOG_PATH      = os.path.join(session_dir, f"error_wheelmove_{mouse_name}_{date_str}_{current_time}.txt")
EXP_CONFIG_FILENAME = os.path.join(session_dir, f"exp_config_wheelmove_{mouse_name}_{date_str}_{current_time}.json")

config_to_save = {
    "metadata": {
        "mouse_name": mouse_name,
        "rig_name": rig_name,
        "experiment_name": exp_name,
        "timestamp": f"{date_str}_{current_time}",
    },
    "config": config_all
}


session_parameters = config_to_save


if reward_conf.get("use_rig_calibration", True):
    try:
        REWARD_DURATION_MS_LIST = []
        for target_reward_ul in REWARD_AMOUNT_LIST:
            policy = mgr.apply_reward_policy(
                session_parameters,
                rig_id = rig_id,
                target_reward_ul_override= target_reward_ul,
                enabled=True,
                put_under_key="reward",
            )

            reward_block = session_parameters.get("reward") or {}
            rod = reward_block.get("reward_open_duration_ms")
            reward_open_duration_ms = float(rod) if rod is not None else None

            REWARD_DURATION_MS_LIST.append(reward_open_duration_ms)
        

        if policy and policy.reward_warning:
            print(f"[reward] WARNING: {policy.reward_warning}")

    except DBClientError as e:
        print(f"[db] WARNING: could not fetch reward policy: {e}")
        REWARD_DURATION_MS_LIST = []


reward_duration_dict   = dict(zip(REWARD_AMOUNT_LIST, REWARD_DURATION_MS_LIST))
config_to_save["config"]["reward"]["REWARD_DURATION_MS_LIST"] = REWARD_DURATION_MS_LIST









with open(EXP_CONFIG_FILENAME, "w") as f:
    json.dump(config_to_save, f, indent=2)

# --- Display / timing / encoder ---

TARGET_DT = 1.0 / FRAME_RATE





# =============================================================================
# 5. OPTIONAL PRIOR-SESSION WARNING
# =============================================================================
# In a post-hoc workflow, you may still want to warn if the last session
# was not analyzed. Whether you use this depends on your lab policy.
# =============================================================================

# if mouse_id is not None:
#     try:
#         if db_conf.get("require_analyzed_last_session", False):
#             mgr.warn_if_unanalyzed_last_session(
#                 mouse_id=mouse_id,
#                 experiment_id=db_conf["experiment_id"],
#                 confirm=confirm_dialog,
#             )
#     except SessionAborted:
#         print("Experiment aborted by user.")
#         sys.exit(0)
#     except DBClientError as e:
#         print(f"[db] WARNING: could not retrieve last-session warning info: {e}")

# =============================================================================
# 6. BUILD session_parameters
# =============================================================================
# In post-hoc workflows, session_parameters are especially important because
# they may be the main metadata source used later by the analysis pipeline.
#
# Include:
# - what task ran
# - key task settings
# - hardware snapshot
# - config_snapshot for provenance
# =============================================================================










# ============================
# Visual / window setup
# ============================


mon = monitors.Monitor('experiment_monitor_portrait')
mon.setWidth(SCREEN_WIDTH_CM)
mon.setSizePix(SCREEN_PIX)

win = visual.Window(size=SCREEN_PIX, fullscr=True, monitor=mon,
                    units='cm', color=(-1.0, -1.0, -1.0), waitBlanking=True, screen=SCREEN_ID)
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
    win.close()
    core.quit()
    raise RuntimeError(f"Failed to open rotary encoder on {ENC_SERIAL_PORT}: {e}")

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

def save_config(config, filename):
    d = asdict(config)
    # convert tuple to list (JSON requirement)
    if isinstance(d["SCREEN_PIX"], tuple):
        d["SCREEN_PIX"] = list(d["SCREEN_PIX"])
    if isinstance(d["SPAWN_GAUSS_CENTER_LIST"], tuple):
        d["SPAWN_GAUSS_CENTER_LIST"] = list(d["SPAWN_GAUSS_CENTER_LIST"])

    with open(filename, "w") as f:
        json.dump(d, f, indent = 2)

    print(f"Saved config to {filename}")
    
def send_reward(duration_ms):
    global last_reward_ts, arduino
    now = perf_counter()
    if (now - last_reward_ts) < MIN_INTER_REWARD_S:
        return False

    if serial is None:
        print(f"[REWARD] (simulated) would deliver {duration_ms} ms (pyserial not available).", flush=True)
        last_reward_ts = now
        return True

    if arduino is None:
        opened = _open_arduino()
        if opened is None:
            return False

    cmd = f"V {int(duration_ms)}\r\n"
    try:
        written = arduino.write(cmd.encode())
        try:
            arduino.flush()
        except Exception:
            pass
        core.wait(0.01)
        if written <= 0:
            return False
        last_reward_ts = now
        return True
    except Exception:
        return False


#### csv file name to write
sync_f              = open(SYNC_LOG_FILENAME, 'w', newline='')
sync_writer         = csv.writer(sync_f)

header = [
    'frame_idx', 't_global_s', 'reward_state','reward_amount',
    'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'delta_cm',
    'running_delta_sum','running_velocity']
sync_writer.writerow(header)
sync_f.flush()


### short pause before the main loop starts
core.wait(WARMUP_S)

# ============================
# Main loop
# ============================
clock               = core.Clock()
frame_idx           = 0
experiment_start_ts = perf_counter()
running_delta_sum   = 0
delta_cm_history    = []
last_reward_ts      = -999.0
stoped_counting     = True 
sync_start_ts       = None

reward_active_until = 0.0
reward_state_pulse_pending = False

try:

    ctx = mgr.begin_session(
        mouse_name=mouse_name,
        mouse_id=mouse_id,
        experiment_name = exp_name,
        experiment_id = db_conf["experiment_id"],
        rig_id = rig_id,
        parameters = session_parameters,
        fallback_session_num=1,
        session_at=datetime.now(ZoneInfo("America/Chicago")),
    )

    local_dir = ctx.local_dir
    print(f"[session] Writing local files into: {local_dir}")

    while True:
        if RUNTIME_TIMEOUT_MINUTES and RUNTIME_TIMEOUT_MINUTES > 0:
            if (perf_counter() - experiment_start_ts) > (RUNTIME_TIMEOUT_MINUTES * 60.0):
                print("[INFO] Runtime timeout reached — exiting.", flush=True)
                break

        frame_loop_start  = perf_counter()
        reward_amount = 0.0 # by default
        reward_sent_this_frame = False
        # =================
        # Log wheel movement
        # ==================
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
        reference_ticks = enc_ticks
        ### translate ticks to center meters on the screen
        delta_cm = delta_ticks * WHEEL_GAIN_CM_PER_TICK
        
        

        #### Only tracking velocity/send reward after some time after the last reward
        if perf_counter() - last_reward_ts > BREAK_INTERVAL:
            if stoped_counting: # tracking just stopped
                start_counting_ts   = perf_counter()
                stoped_counting     = False
            ####### tracking wheel velocity
            if (perf_counter() - start_counting_ts) >  CHECK_BIN :
                running_delta_sum -= delta_cm_history[0]
                delta_cm_history.pop(0)
            delta_cm_history.append(abs(delta_cm))
            running_delta_sum   += abs(delta_cm)
            running_velocity     = running_delta_sum / CHECK_BIN

            # ===================
            # Check if average velocity is above threshold and the counting time has passed
            # ==================
            if (running_velocity > VELOCITY_THRESHOLD) & ((perf_counter() - start_counting_ts) >  CHECK_BIN):
                # if yes, give reward
                if not reward_sent_this_frame:
                
                    reward_amount = REWARD_TARGET
                    open_t = reward_duration_dict[reward_amount]
                    if send_reward(open_t):
                        reward_sent_this_frame = True
                        reward_active_until = perf_counter() + (open_t / 1000.0)
                        reward_state_pulse_pending = True
                ### and reset everything
                running_delta_sum   = 0
                running_velocity    = 0
                delta_cm_history    = []
                last_reward_ts      = perf_counter()
                stoped_counting     = True 

            else:
                # if not keep tracking
                pass
        else:
            pass
        
        enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{delta_cm:.4f}", 
                        f"{running_delta_sum:.4f}", f"{running_velocity:.4f}"]

        win.clearBuffer()   
        win.flip()

        # =================
        # logging
        if sync_start_ts is None:
            sync_start_ts = perf_counter()
        t_global = f"{(perf_counter() - sync_start_ts):.6f}" if sync_start_ts is not None else ''

        if reward_state_pulse_pending:
            reward_state_now = 1
            reward_state_pulse_pending = False
        else:
            reward_state_now = 1 if (perf_counter() < reward_active_until) else 0

        # Start with the header
        log_row = [
            frame_idx,
            t_global,
            reward_state_now,
            reward_amount
        ]
        log_row += enc_cols
        
        # write row
        sync_writer.writerow(log_row)
        if frame_idx % LOG_FLUSH_INTERVAL_FRAMES == 0:
            sync_f.flush()

        frame_idx += 1
        # =================
        # Escape
        # =================
        if frame_idx % 10 == 0 and event.getKeys(['escape']):
            print("Escape pressed — exiting.", flush=True)
            break

        elapsed =  perf_counter() - frame_loop_start
        to_wait = TARGET_DT - elapsed
        if to_wait > 0:
            core.wait(to_wait)

except KeyboardInterrupt:
    print("Interrupted — exiting.", flush=True)
finally:
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

    # ==== Count and print how much reward the animal got
    [total_reward, n_rewarded_trials, has_amount] = count_reward(SYNC_LOG_FILENAME)
    if has_amount:
        print(f"Total reward amount: {total_reward}")
        print(f"Number of rewarded trials: {n_rewarded_trials}")
    else:
        print(f"Total reward amount: {n_rewarded_trials} * {REWARD_TARGET} = {n_rewarded_trials * REWARD_TARGET}")
    
    performance_results = analyze_move_wheel(session_dir, prefix="sync_log_wheelmove")
    new_params          = update_config_move_wheel(EXP_CONFIG_FILENAME, performance_results)
    if ctx is not None:
        # mgr.finalize_unanalyzed_session(
        #     ctx,
        #     append_datarecord_row=None,
        #     transfer_to_nas=True,
        #     delete_local=True,
        # )
        mgr.finalize_session(
            ctx,
            performance = performance_results,
            next_session_parameters = new_params,
            append_datarecord_row = None,
            transfer_to_nas = True,
            delete_local = True,
            mark_analyzed = True)
    

    win.close()
    core.quit()
    print("Clean exit.", flush=True)