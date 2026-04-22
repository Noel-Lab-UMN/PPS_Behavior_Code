""""
This scripts plays past goal-directed trajectories to animals
'"""

import csv
import random
import threading
import time
import os
import traceback
from time import perf_counter
from datetime import datetime


import json

import numpy as np
from psychopy import visual, core, event, monitors


import pandas as pd

RIG_NAME     = 'PPS_training_Rig_2'
SUBJECT_NAME = 'test' 
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

# ================================
## Amount of reward 
# ================================

REWARD_TARGET           = 3.0 
DO_READ_JSON            = False 
INTER_SPAWN_INTERVAL    = 0.5 # in seconds 
# ============================
# Consolidated parameters
# ============================

# --- Session / timing / logging ---
WARMUP_S = 1.0                 # warmup period (seconds) before experiment proper starts
RUNTIME_TIMEOUT_MINUTES = 70.0  # runtime timeout in minutes (None or <=0 disables)
STARTUP_WAIT_S = 3.0            # max seconds to wait for Arduino during startup

# less frequent log flushing, but still one row per frame
LOG_FLUSH_INTERVAL_FRAMES = 100   # ~10 seconds at 60 Hz

### spawn only when the wheel is stationary for some time
STATIONARY_INTERVAL     = 500.0 #  in ms
STATIONARY_TOLERANCE    = 4 # A a few tick is okay


# set wheel gain to 0
WHEEL_GAIN_CM_PER_TICK  = 0
WRAP_DETECT_TICKS       = 800 
### csv file name to load
folder_root         =  os.path.join(os.getcwd(), "test_passive")
csv_file_name       =  os.path.join(folder_root, "example_csv_test_passive.csv")
json_file           =  os.path.join(folder_root, "example_json_test_passive.json")
COLUMN_TO_READ      = 'slot1'
#### scv file name to write
SYNC_LOG_FILENAME   = os.path.join(folder_root, "test_passive_rewrite.csv")
sync_f              = open(SYNC_LOG_FILENAME, 'w', newline='')
sync_writer         = csv.writer(sync_f)

header = [
    'frame_idx', 't_global_s', 'reward_state',
    'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'delta_cm',
    'running_tick_sum','wheel_is_stationary']
header.append(f"slot{1}")

sync_writer.writerow(header)
sync_f.flush()

if DO_READ_JSON: #### read the parameters from json file
    with open(json_file, 'r') as f:
        params = json.load(f)

    SCREEN_WIDTH_CM = params["SCREEN_WIDTH_CM"]
    BALL_OPACITY    = params['BALL_OPACITY']
else:
    # Screen / space geometry
    SCREEN_WIDTH_CM = 55.88
    SCREEN_HEIGHT_CM = 96.26
    SPACE_WIDTH_CM = SCREEN_WIDTH_CM * 2.0
    SCREEN_PIX = (1080, 1920)
    SPACE_DEGREES = 360
    CIRCLE_RADIUS_CM = 3.0
    BALL_OPACITY = 1.0

half_screen_h = SCREEN_HEIGHT_CM / 2.0
# --- Display / timing / encoder ---
FRAME_RATE = 60
TARGET_DT = 1.0 / FRAME_RATE

# Hardware / encoder 
match RIG_NAME:
    case 'PPS_training_Rig_3':
        ENC_SERIAL_PORT = 'COM3' 
    case 'PPS_training_Rig_2':
        ENC_SERIAL_PORT = 'COM3'


# Reward / Arduino
match RIG_NAME:
    case 'PPS_training_Rig_3':
        ARDUINO_PORT = 'COM7' 
        match REWARD_TARGET:
            case 3.0:
                REWARD_DURATION_MS = 15.92
            case 5.0:
                REWARD_DURATION_MS = 28.56

    case 'PPS_training_Rig_2':
        ARDUINO_PORT = 'COM4'
        match REWARD_TARGET:
            case 3.0:
                REWARD_DURATION_MS = 10.29
            case 5.0:
                REWARD_DURATION_MS = 14.62


ARDUINO_BAUD = 9600
ARDUINO_OPEN_ON_START = True   # if True, attempt to open serial right away (can cause Arduino reset)
MIN_INTER_REWARD_S = 0.15      # minimum seconds between rewarded pulses


def parse_sync_log(csv_file_name, column_name='slot_1'):
    """
    Read a csv log and extract spawn_id, x_deg, y_cm, is_visible
    from the column containing 'spawn_id|x_deg|y_cm|is_visible'.
    
    Returns a dataframe with parsed variables.
    """

    df = pd.read_csv(csv_file_name)

    # drop the empty columns
    ball_col = df[column_name].dropna()
    ball_col = ball_col[ball_col.astype(str).str.strip() != '']
    # split the column by "|"
    ball_data = ball_col.str.split('|', expand=True)

    # rename columns
    ball_data.columns = ['spawn_id', 'x_deg', 'y_cm', 'is_visible']

    # convert types
    ball_data['spawn_id']       = ball_data['spawn_id'].astype(int)
    ball_data['x_deg']          = ball_data['x_deg'].astype(float)
    ball_data['y_cm']           = ball_data['y_cm'].astype(float)
    ball_data['is_visible']     = ball_data['is_visible'].astype(bool)

   # ===== NEW LINE =====
    ball_data['reward_state'] = df.loc[ball_data.index, 'reward_state']

    return ball_data

def deg_to_screen_cm(deg, space_cm = SPACE_WIDTH_CM):
    d = (deg + 180) % 360 - 180
    d_cm = d / SPACE_DEGREES * space_cm
    return d_cm

def run_inter_spawn_interval(win, inter_spawn_interval = INTER_SPAWN_INTERVAL):
    win.flip(clearBuffer=True)
    time.sleep(inter_spawn_interval)

def wait_for_stationary_and_log_between_spawns(
        win, encoder, sync_writer, sync_f, frame_idx,
        sync_start_ts, LOG_FLUSH_INTERVAL_FRAMES = LOG_FLUSH_INTERVAL_FRAMES, TARGET_DT = TARGET_DT,
        STATIONARY_TOLERANCE = STATIONARY_TOLERANCE, STATIONARY_INTERVAL = STATIONARY_INTERVAL,  inter_spawn_interval = INTER_SPAWN_INTERVAL):

    
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
      


        t_global = f"{(perf_counter() - sync_start_ts):.6f}"

        log_row = [frame_idx, t_global, reward_state_now]
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
        
        if perf_counter() - interval_start_ts > inter_spawn_interval and wheel_is_stationary:
            break

    return frame_idx

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

### === send reward 
def send_reward(duration_ms=REWARD_DURATION_MS):
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
    
# ============================
# Visual / window setup
# ============================
mon = monitors.Monitor('experiment_monitor_portrait')
mon.setWidth(SCREEN_WIDTH_CM)
mon.setSizePix(SCREEN_PIX)

win = visual.Window(size=SCREEN_PIX, fullscr=True, monitor=mon,
                    units='cm', color=(-1.0, -1.0, -1.0), waitBlanking=True, screen=1)

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


#### Define ball
circle = visual.Circle(win, radius=CIRCLE_RADIUS_CM, fillColor=(1.0, 1.0, 1.0),
                       lineColor=None, edges=64, pos=(0.0, 0.0), units = 'cm')

success_text = visual.TextStim(win, text='SUCCESS!', height=2.5, bold=True, pos=(0.0, 0.0))


#### Read .csv file

ball_data       = parse_sync_log(csv_file_name, column_name = COLUMN_TO_READ)
spawn_groups    = list(ball_data.groupby('spawn_id', sort=False))
# ============================
# main 
# =============================
clock           = core.Clock()
#### initialization
frame_idx       = 0
sync_start_ts   = None

spawn_idx       = 0
spawn_id, spawn_rows = spawn_groups[spawn_idx]
spawn_rows = list(spawn_rows.itertuples(index=False))
row_ptr = 0
new_spawn_flag = False

reward_active_until = 0.0
reward_state_pulse_pending = False

# try: 
reference_ticks = int(encoder.current_position())
while True:
    reward_sent_this_frame = False
    frame_loop_start  = perf_counter()

     
    # get x, y position
    row = spawn_rows[row_ptr]
    x_deg = row.x_deg
    y_cm  = row.y_cm
    is_visible = row.is_visible
    # is_rewarded
    is_rewarded = row.reward_state
    # draw
    win.clearBuffer()
    drawn_x         = deg_to_screen_cm(x_deg)
    drawn_y         = y_cm -  half_screen_h
    circle.pos      = (drawn_x, drawn_y)
    circle.opacity  = float(max(0.0, min(1.0, BALL_OPACITY)))
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
    frame_idx   += 1
    ### check if this spawn is finished
    if row_ptr >= len(spawn_rows):
        # Whether to give reward
        # this spawn was rewarded in the original experiment
        if is_rewarded and (not reward_sent_this_frame):
            if send_reward(REWARD_DURATION_MS):
                reward_sent_this_frame = True
                reward_active_until = perf_counter() + (REWARD_DURATION_MS / 1000.0)
                reward_state_pulse_pending = True

        #     reward_state = 1

        # pause between spawns
    
  
       
        new_spawn_flag = True

       
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

    # Start with the header
    log_row = [
        frame_idx,
        t_global,
        reward_state_now
    ]

    # append to rows
    slot_cells = ['']
    slot_cells[0] = f"{spawn_id}|{drawn_x:.3f}|{y_cm:.3f}|1"
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
    
    if new_spawn_flag:
        frame_idx = wait_for_stationary_and_log_between_spawns(win, encoder, sync_writer, sync_f, frame_idx, sync_start_ts) 
         
        spawn_idx += 1
        if spawn_idx >= len(spawn_groups):
            break   # experiment finished

        spawn_id, spawn_rows = spawn_groups[spawn_idx]
        spawn_rows = list(spawn_rows.itertuples(index=False))
        row_ptr = 0
        new_spawn_flag = False
    


# except KeyboardInterrupt:
#     print("Interrupted — exiting.", flush=True)
# finally:
#     try:
#         sync_f.flush()
#         sync_f.close()
#     except Exception:
#         pass

#     try:
#         encoder.close()
#     except Exception:
#         pass

#     if arduino is not None:
#         try:
#             arduino.close()
#             print(f"[INFO] Closed Arduino serial on {ARDUINO_PORT}", flush=True)
#         except Exception:
#             pass

#     win.close()
#     core.quit()
#     print("Clean exit.", flush=True)


