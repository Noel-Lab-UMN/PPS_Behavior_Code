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
DO_READ_JSON            = True 
INTER_SPAWN_INTERVAL    = 0.3 # in seconds 
# ============================
# Consolidated parameters
# ============================

# --- Session / timing / logging ---
WARMUP_S = 10.0                 # warmup period (seconds) before experiment proper starts
RUNTIME_TIMEOUT_MINUTES = 70.0  # runtime timeout in minutes (None or <=0 disables)
STARTUP_WAIT_S = 3.0            # max seconds to wait for Arduino during startup

# less frequent log flushing, but still one row per frame
LOG_FLUSH_INTERVAL_FRAMES = 600   # ~10 seconds at 60 Hz

# set wheel gain to 0
WHEEL_GAIN_CM_PER_TICK  = 0
WRAP_DETECT_TICKS       = 800 
### csv file name
folder_root         = os.path.join(os.getcwd(), "test_passive")
csv_file_name       =  os.path.join(folder_root, "example_csv_test_passive.csv")
json_file           =  os.path.join(folder_root, "example_json_test_passive")
COLUMN_TO_READ      = 'N'

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

    CIRCLE_RADIUS_CM = 3.0
    BALL_OPACITY = 1.0

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


def parse_sync_log(csv_file_name, column_name='N'):
    """
    Read a csv log and extract spawn_id, x_deg, y_cm, is_visible
    from the column containing 'spawn_id|x_deg|y_cm|is_visible'.
    
    Returns a dataframe with parsed variables.
    """

    df = pd.read_csv(csv_file)

    # split the column by "|"
    ball_data = df[column_name].str.split('|', expand=True)

    # rename columns
    ball_data.columns = ['spawn_id', 'x_deg', 'y_cm', 'is_visible']

    # convert types
    ball_data['spawn_id'] = parsed['spawn_id'].astype(int)
    ball_data['x_deg'] = parsed['x_deg'].astype(float)
    ball_data['y_cm'] = parsed['y_cm'].astype(float)
    ball_data['is_visible'] = parsed['is_visible'].astype(bool)

    return ball_data

def deg_to_cm(deg, space_cm = SPACE_WIDTH_CM):
    d = deg % SPACE_DEGREES
    return (d / SPACE_DEGREES) * space_cm

def create_inter_spawn_interval(inter_spawn_interval = INTER_SPAWN_INTERVAL):
    clear_screen()
    win.flip()
    time.sleep(inter_spawn_interval)

def check_escape(win=None):
    if 'escape' in event.getKeys():
        if win is not None:
            win.close()
        core.quit()

def detect_wheel(encoder, gain_applied = WHEEL_GAIN_CM_PER_TICK):
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
                       lineColor=None, edges=64, pos=(0.0, 0.0))

success_text = visual.TextStim(win, text='SUCCESS!', height=2.5, bold=True, pos=(0.0, 0.0))


#### Read .csv file

ball_data = parse_sync_log(csv_file_name, column_name = COLUMN_TO_READ)

# ============================
# main 
# =============================
frame_idx = 0
sync_start_ts = None
try: 
    for spawn_id, group in parsed.groupby('spawn_id', sort=False):
        inter_spawn_interval()
        for row in group.itertuples(index = False):
            # get x, y position
            x_deg = row.x_deg
            y_cm = row.y_cm
            is_visible = row.is_visible
            # draw
            win.clearBuffer()
            drawn_x         = deg_to_cm(x_deg)
            circle.pos      = (drawn_x, y_cm)
            circle.opacity  = float(max(0.0, min(1.0, BALL_OPACITY)))
            circle.draw()
            win.flip()

            # ====== save another log ======
            if sync_start_ts is None:
                sync_start_ts = perf_counter()
            t_global = f"{(perf_counter() - sync_start_ts):.6f}" if sync_start_ts is not None else ''
            # Start with the header
            row = [
                frame_idx,
                t_global,
                reward_state_now
            ]

            # wheel movement and gain
            [enc_ticks, delta_ticks_raw, delta_ticks, delta_cm] = detect_wheel(encoder)
            enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{base_delta_cm:.4f}", f"{delta_cm:.4f}"]
            
            # append to rows
            slot_cells[0] = f"{spawn_id}|{drawn_x:.3f}|{y_cm:.3f}|1"
            row += enc_cols
            row += slot_cells
           
            # write row
            sync_writer.writerow(row)
            if frame_idx % LOG_FLUSH_INTERVAL_FRAMES == 0:
                sync_f.flush()

            frame_idx += 1

            # ====== check escape key press
            check_escape()
except KeyboardInterrupt:
    print("Interrupted — exiting.", flush=True)
finally:
    win.close()
    core.quit()
    print("Clean exit.", flush=True)


