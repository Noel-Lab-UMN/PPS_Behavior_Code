"""
Static-obstruction behavior experiment. The prbs thread and logging has been removed.

Notes:
 - Static white-bar obstructions placed on the screen (bottom-left coordinate system)
 - Balls aawn and fall with the scenery; collisions with obstructions remove balls
 - Arduino reward control (optional pyserial)
 - Sync log includes ball slot columns and obstruction slot columns:
     slotN entries format: spawn_id|x_deg|y_cm|is_visible  (is_visible = 0/1 and includes flicker)
     obs_slotN entries format: obs_index|width_cm|xdeg_from_mouse|ycm_from_mouse|is_hit
 - This is the BEHAVIOR version: PRBS/Bpod removed; no TTL thread; no prbs_bit column.
"""

import csv
import random
import threading
import time
import os
import traceback
from time import perf_counter
from datetime import datetime

from count_reward import count_reward
from dataclasses import dataclass, asdict
import json

import numpy as np
from psychopy import visual, core, event, monitors

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

REWARD_TARGET       = 3.0 
# ============================
# Consolidated parameters
# ============================

# --- Session / timing / logging ---
WARMUP_S = 10.0                 # warmup period (seconds) before experiment proper starts
RUNTIME_TIMEOUT_MINUTES = 70.0  # runtime timeout in minutes (None or <=0 disables)
STARTUP_WAIT_S = 3.0            # max seconds to wait for Arduino during startup

# less frequent log flushing, but still one row per frame
LOG_FLUSH_INTERVAL_FRAMES = 600   # ~10 seconds at 60 Hz

# Prompt for mouse name (blocking console input)
mouse_name  = input("Enter mouse name (short, no spaces): ").strip()
if not mouse_name:
    mouse_name = "mouseUNK"

RIG_NAME    = input("Enter rig name: ").strip()
RIG_NAME_LIST = ['PPS_training_Rig_3', 'PPS_training_Rig_2']
if RIG_NAME not in RIG_NAME_LIST:
    raise ValueError(f"{RIG_NAME} not found in existing rig list")

# session folder uses date only (YYYYMMDD)
meta_root = os.path.join(os.getcwd(), "metadata")
os.makedirs(meta_root, exist_ok=True)
date_str = datetime.now().strftime("%Y%m%d")
session_folder_name = f"{mouse_name}_{date_str}"
session_dir = os.path.join(meta_root, session_folder_name)
os.makedirs(session_dir, exist_ok=True)
print(f"[INFO] Session metadata directory: {session_dir}", flush=True)

# main sync log filename
current_time  = datetime.now().strftime("%H%M")
SYNC_LOG_FILENAME = os.path.join(session_dir, f"sync_log_{mouse_name}_{date_str}_{current_time}.csv")
ERROR_LOG_PATH = os.path.join(session_dir, 'error.txt')

# --- Display / timing / encoder ---
FRAME_RATE = 60
TARGET_DT = 1.0 / FRAME_RATE

# Hardware / encoder
match RIG_NAME:
    case 'PPS_training_Rig_3':
        ENC_SERIAL_PORT = 'COM3' 
    case 'PPS_training_Rig_2':
        ENC_SERIAL_PORT = 'COM3'


#ENC_SERIAL_PORT = 'COM3'            # update as needed
WHEEL_GAIN_CM_PER_TICK = 0.1

# Screen / space geometry
SCREEN_WIDTH_CM = 55.88
SCREEN_HEIGHT_CM = 96.26
SPACE_WIDTH_CM = SCREEN_WIDTH_CM * 2.0
SCREEN_PIX = (1080, 1920)

# Reward / Arduino
match RIG_NAME:
    case 'PPS_training_Rig_3':
        ARDUINO_PORT = 'COM7' 
        match REWARD_TARGET:
            case 3.0:
                REWARD_DURATION_MS = 17.92
            case 5.0:
                REWARD_DURATION_MS = 27.55

    case 'PPS_training_Rig_2':
        ARDUINO_PORT = 'COM4'
        match REWARD_TARGET:
            case 3.0:
                REWARD_DURATION_MS = 10.33
            case 5.0:
                REWARD_DURATION_MS = 21.14


ARDUINO_BAUD = 9600
REWARD_DURATION_MS = 12      # reward valve pulse duration in ms
ARDUINO_OPEN_ON_START = True   # if True, attempt to open serial right away (can cause Arduino reset)
MIN_INTER_REWARD_S = 0.15      # minimum seconds between rewarded pulses

# --- Ball / trial parameters ---
CIRCLE_RADIUS_CM = 3.0
BALL_FALL_SPEED_CM_S = 30.0        # default downward speed (cm / second) used if region.linear_velocity is None
SUCCESS_EDGE_TOLERANCE_MULT = 2.5 # multiplier of circle radius for success tolerance defualt(?) = 1.25 

# ======================================
# Spawning behavior
# ======================================
SPAWN_ON_SCREEN = True
SPAWN_INTERVAL_RANGE = (0.5, 2.0)

# Multi-ball settings
MULTIPLE_BALLS = False
MULTIPLE_BALLS_SPAWN_INTERVAL = (0.5, 1.0)
MAX_NUM_BALLS = 10
_DEFAULT_LOG_MAX_BALLS = 10  # fallback for logging if MAX_NUM_BALLS is None

# NEW: spawn distribution control (screen-centered Gaussian)
SPAWN_DISTRIBUTION = "gaussian"   # "uniform" or "gaussian"
SPAWN_GAUSS_CENTER_LIST = [-12.0, -12.0, -12.0, -12.0, 0, 0, 12.0, 12.0, 12.0, 12.0]
SPAWN_GAUSS_SIGMA_CM = 0      # std dev in cm (0 -> always center)
SPAWN_GAUSS_RESAMPLE_MAX = 50    # safety to avoid infinite loops
SPAWN_GAUSS_CLAMP_TO_SCREEN = True  # if True, clamp instead of resampling

SPAWN_Y_OFFSET =  40.0 # By Shizhao Liu 03/06/2026. Make the ball start closer to the animal

SPAWN_ONLY_STATIONARY   = True # By shizhao liu 02/26/2026. only generate new balls when the wheel is stationary for some time interal. Obviously, this is only good for one-ball-only condition
STATIONARY_INTERVAL     = 500.0 #  in ms
STATIONARY_TOLERANCE    = 4 # A a few tick is okay

# Rendering / flicker
BALL_OPACITY = 1.0                 # 0.0..1.0 (0 transparent, 1 opaque)
BALL_FLICKER_DURATION = None       # seconds ON each interval (None to disable)
BALL_FLICKER_INTERVAL = None       # seconds period (None to disable)

# ======================================
# --- Obstruction (static) parameters ---
# ======================================

SREEEN_EDGE_OBSTRUCTION = True
SPAWN_OBSTRUCTIONS = False     # set to False to skip all obstruction logic
OBSTRUCTION_WIDTH_CM = 6.0            # width of each white bar
OBSTRUCTION_HEIGHT_CM = 1.0           # height of each white bar
OBSTRUCTION_Y_DIST_RANGE = (4.0, 9.0) # vertical spacing between obstructions (min,max)
OBSTRUCTION_Y_BUFFER = 5.0            # top/bottom buffer (cm) where obstructions won't be placed
OBSTRUCTION_REGEN_TIME = 10.0         # seconds between regenerations (None to disable)
OBSTRUCTION_NUM = 3                # max obstructions per regen (None -> as many as fit)
OBSTRUCTION_MIN_CENTER_DIST_X = 5.0   # preferred min center-to-center X distance (attempted)

# --- Safety / wrapping / other ---
RESPAWN_DELAY_S = 0.0
WRAP_DETECT_TICKS = 800
MAX_MOVE_PER_FRAME_CM = SCREEN_WIDTH_CM
SPACE_DEGREES = 360.0

# Debug flag
DEBUG = False

# ============================
# End consolidated parameters
# ============================

# Convenience derived params
half_screen_w = SCREEN_WIDTH_CM / 2.0
half_screen_h = SCREEN_HEIGHT_CM / 2.0

# Helper: pixels conversion used in texture prep & drawing
pixels_per_cm = SCREEN_PIX[0] / float(SCREEN_WIDTH_CM)            # horizontal
vertical_pixels_per_cm = SCREEN_PIX[1] / float(SCREEN_HEIGHT_CM)  # vertical

full_world_px = int(round(SPACE_WIDTH_CM * pixels_per_cm))
full_height_px = int(round(SCREEN_HEIGHT_CM * vertical_pixels_per_cm))  # == SCREEN_PIX[1]

# ============================
# REGION DEFINITIONS (default)
# ============================

regions = {
    'region1': {
        'deg_range': (0, 360), 'gain': 1, 'color': 'black', 'prob_spawn': 1,
        'spawn_function': None, 'linear_velocity': None, 'patch_shape': 'square',
        'patch_fraction': 0.15, 'patch_size_cm': 4.0,
        'temporal_visibility': 100.0, 'temporal_stimulus_visible': False,
        'spatial_visibility': False, 'spatial_stimulus_visible': False
    },
}
# ====================================
# Save parameter functions
# ====================================
@dataclass
class ExperimentConfig:
    RIG_NAME: str
    MOUSE_NAME: str
    EXP_DATE: str
    WHEEL_GAIN_CM_PER_TICK: float
    SCREEN_WIDTH_CM: float
    SCREEN_HEIGHT_CM: float
    SPACE_WIDTH_CM: float
    SCREEN_PIX: tuple[int, int]
    SPACE_DEGREES: float
    REWARD_TARGET: float
    REWARD_DURATION_MS: float
    CIRCLE_RADIUS_CM: float
    BALL_FALL_SPEED_CM_S: float
    SUCCESS_EDGE_TOLERANCE_MULT: float
    SPAWN_DISTRIBUTION: str
    SPAWN_GAUSS_CENTER_LIST: tuple[float, float]
    SPAWN_GAUSS_SIGMA_CM: float
    SREEEN_EDGE_OBSTRUCTION: bool
    SPAWN_ONLY_STATIONARY: bool
    STATIONARY_INTERVAL: float
    STATIONARY_TOLERANCE: int


  


exp_config = ExperimentConfig(
    RIG_NAME    = RIG_NAME,
    MOUSE_NAME  = mouse_name,
    EXP_DATE    = date_str,
    WHEEL_GAIN_CM_PER_TICK = WHEEL_GAIN_CM_PER_TICK,
    SCREEN_WIDTH_CM = SCREEN_WIDTH_CM,
    SCREEN_HEIGHT_CM = SCREEN_HEIGHT_CM,
    SPACE_WIDTH_CM = SPACE_WIDTH_CM,
    SCREEN_PIX = SCREEN_PIX,
    SPACE_DEGREES = SPACE_DEGREES,
    REWARD_TARGET = REWARD_TARGET,
    REWARD_DURATION_MS = REWARD_DURATION_MS,
    CIRCLE_RADIUS_CM = CIRCLE_RADIUS_CM,
    BALL_FALL_SPEED_CM_S = BALL_FALL_SPEED_CM_S,
    SUCCESS_EDGE_TOLERANCE_MULT = SUCCESS_EDGE_TOLERANCE_MULT,
    SPAWN_DISTRIBUTION = SPAWN_DISTRIBUTION,
    SPAWN_GAUSS_CENTER_LIST = SPAWN_GAUSS_CENTER_LIST,
    SPAWN_GAUSS_SIGMA_CM = SPAWN_GAUSS_SIGMA_CM,
    SREEEN_EDGE_OBSTRUCTION = SREEEN_EDGE_OBSTRUCTION,
    SPAWN_ONLY_STATIONARY = SPAWN_ONLY_STATIONARY,
    STATIONARY_INTERVAL = STATIONARY_INTERVAL,
    STATIONARY_TOLERANCE = STATIONARY_TOLERANCE
    )

EXP_CONFIG_FILENAME = os.path.join(session_dir, f"exp_config_{mouse_name}_{date_str}_{current_time}.json")


# ======================== 
# Define helper functions
# ======================== 
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
# ---------------------------
# Helper functions & small utilities
# ---------------------------
def cm_to_deg(cm, space_cm=SPACE_WIDTH_CM):
    return (cm % space_cm) * (SPACE_DEGREES / space_cm)

def deg_to_cm(deg, space_cm=SPACE_WIDTH_CM):
    d = deg % SPACE_DEGREES
    return (d / SPACE_DEGREES) * space_cm

def deg_in_range(start_deg, end_deg, deg):
    start = start_deg % 360.0
    end = end_deg % 360.0
    d = deg % 360.0
    if abs(start - end) < 1e-9:
        return True
    if start < end:
        return (start <= d) and (d < end)
    else:
        return (d >= start) or (d < end)

def name_to_color_rgb_minus1_to_1(name):
    lc = name.lower()
    mapping = {
        'black': (0.0, 0.0, 0.0),
        'white': (1.0, 1.0, 1.0),
        'red':   (1.0, 0.0, 0.0),
        'green': (0.0, 1.0, 0.0),
        'blue':  (0.0, 0.0, 1.0),
        'yellow':(1.0, 1.0, 0.0),
        'magenta':(1.0, 0.0, 1.0),
        'cyan':  (0.0, 1.0, 1.0),
    }
    if lc not in mapping:
        raise ValueError(f"Unknown color name '{name}'. Add to mapping or use r,g,b tuple.")
    rgb01 = mapping[lc]
    return tuple([c * 2.0 - 1.0 for c in rgb01])

def intersect_intervals(a_start, a_end, b_start, b_end):
    start = max(a_start, b_start)
    end = min(a_end, b_end)
    if end <= start:
        return None
    return (start, end)

def region_deg_ranges_to_world_intervals(regions_dict, space_cm=SPACE_WIDTH_CM):
    out = {}
    for rname, rconf in regions_dict.items():
        sdeg, edeg = rconf['deg_range']
        sdeg = sdeg % 360.0
        edeg = edeg % 360.0
        if abs(sdeg - edeg) < 1e-9:
            out[rname] = [(0.0, space_cm)]
            continue
        s_cm = deg_to_cm(sdeg, space_cm)
        e_cm = deg_to_cm(edeg, space_cm)
        if s_cm < e_cm:
            out[rname] = [(s_cm, e_cm)]
        elif s_cm > e_cm:
            out[rname] = [(s_cm, space_cm), (0.0, e_cm)]
        else:
            out[rname] = []
    return out

def make_uniform_region_spawn(region_name, region_intervals, space_cm=SPACE_WIDTH_CM):
    segs = region_intervals.get(region_name, [])
    lengths = [e - s for (s, e) in segs]
    total_len = sum(lengths)
    if total_len <= 0:
        def fallback(_win_start=None, _window_intervals=None, _screen_w=None, _space_w=None):
            return 0.5 * space_cm
        return fallback

    def uniform_sampler(win_start=None, window_intervals=None, screen_w=None, space_w=None):
        r = random.uniform(0.0, total_len)
        cum = 0.0
        for (s, e), L in zip(segs, lengths):
            if cum + L >= r:
                return s + (r - cum)
            cum += L
        return segs[-1][1] - 1e-6

    return uniform_sampler

def general_spawn_uniform_on_screen(win_start, window_intervals, screen_w, space_w):
    intervals = list(window_intervals)
    lengths = [e - s for s, e in intervals]
    total = sum(lengths)
    if total <= 0:
        return wrap_pos(win_start + screen_w / 2.0, space_w)
    r = random.uniform(0.0, total)
    cum = 0.0
    for (s, e), L in zip(intervals, lengths):
        if cum + L >= r:
            return s + (r - cum)
        cum += L
    return intervals[-1][1] - 1e-6

def general_spawn_gaussian_on_screen_center(win_start, screen_w, space_w,
                                            spawn_center_cm,
                                            sigma_cm,
                                            clamp_to_screen=True,
                                            max_resamples=50):
    """
    Gaussian spawn in *screen coordinates* centered at screen center (reward zone).

    Returns a world_x_cm in [0, space_w) such that:
      - mean is exactly screen center
      - sigma controls spread in cm
      - sigma=0 -> always center

    If clamp_to_screen is True, we clamp to the visible screen window.
    Otherwise we resample until in bounds (up to max_resamples).
    """
    # exact center in world coords
    center_world = wrap_pos(win_start + (screen_w / 2.0), space_w)

    sigma = float(max(0.0, sigma_cm))
    # if sigma == 0.0:
    #     return center_world

    #spawn_center = 15.0
    if clamp_to_screen:
        #offset = random.gauss(0.0, sigma)
        offset = random.gauss(spawn_center_cm, sigma)
        # clamp offset so spawn is within visible window
        offset = max(-(screen_w / 2.0), min((screen_w / 2.0), offset))
       # print(offset)
        return wrap_pos(center_world + offset, space_w)

    # resample mode (keeps a true truncated normal rather than clamped tails)
    for _ in range(int(max_resamples)):
        #offset = random.gauss(0.0, sigma)
        offset = random.gauss(spawn_center_cm, sigma)
        if -(screen_w / 2.0) <= offset <= (screen_w / 2.0):
            return wrap_pos(center_world + offset, space_w)

    # fallback if we fail repeatedly
    return center_world

def region_for_world_x(world_x_cm):
    if world_x_cm is None:
        return None
    w = float(world_x_cm) % SPACE_WIDTH_CM
    for rname, segs in region_intervals.items():
        for (s_cm, e_cm) in segs:
            if s_cm <= w < e_cm:
                return rname
    return None

def _clamp(v, a, b):
    return max(a, min(b, v))

def _point_in_triangle(px, py, A, B, C):
    v0x = C[0] - A[0]; v0y = C[1] - A[1]
    v1x = B[0] - A[0]; v1y = B[1] - A[1]
    v2x = px - A[0];   v2y = py - A[1]
    dot00 = v0x*v0x + v0y*v0y
    dot01 = v0x*v1x + v0y*v1y
    dot02 = v0x*v2x + v0y*v2y
    dot11 = v1x*v1x + v1y*v1y
    dot12 = v1x*v2x + v1y*v2y
    denom = (dot00 * dot11 - dot01 * dot01)
    denom = np.where(denom == 0, 1e-12, denom)
    u = (dot11 * dot02 - dot01 * dot12) / denom
    v = (dot00 * dot12 - dot01 * dot02) / denom
    return (u >= 0) & (v >= 0) & (u + v <= 1)

# ============================
# Validation & spawn setup
# ============================
AUTO_NORMALIZE_SPAWN_PROBS = True
PROB_SUM_TOL = 1e-6

def validate_regions(regions_dict, step_deg=1.0, tol_prob=1e-6):
    if 360.0 % step_deg != 0:
        raise ValueError("step_deg should divide 360 evenly for sampling.")
    N = int(360.0 / step_deg)
    uncovered = set()
    overlaps = {}
    for i in range(N):
        deg = (i * step_deg) % 360.0
        matches = []
        for rname, rconf in regions_dict.items():
            s, e = rconf['deg_range']
            if deg_in_range(s, e, deg):
                matches.append(rname)
        if len(matches) == 0:
            uncovered.add(deg)
        elif len(matches) > 1:
            overlaps[deg] = matches
    msgs = []
    if uncovered:
        msgs.append(f"Uncovered degrees (sampled at {step_deg}°): {sorted(list(uncovered))[:10]}{'...' if len(uncovered)>10 else ''}")
    if overlaps:
        msgs.append(f"Overlapping assignments at degrees (sampled): {list(overlaps.items())[:6]}{'...' if len(overlaps)>6 else ''}")
    probs = []
    for rname, rconf in regions_dict.items():
        if 'prob_spawn' not in rconf:
            raise ValueError(f"Region '{rname}' must include 'prob_spawn'.")
        p = float(rconf['prob_spawn'])
        if p < 0:
            raise ValueError(f"Region '{rname}' has negative prob_spawn.")
        probs.append(p)
    total_p = sum(probs)
    if total_p <= 0.0:
        msgs.append("Sum of region 'prob_spawn' values must be > 0 (not all zero).")
    if msgs:
        raise ValueError("Region validation failed:\n" + "\n".join(msgs))

validate_regions(regions, step_deg=1.0)
region_intervals = region_deg_ranges_to_world_intervals(regions, space_cm=SCREEN_WIDTH_CM * 2.0)
for rname, rconf in regions.items():
    if rconf.get('spawn_function') is None:
        rconf['spawn_function'] = make_uniform_region_spawn(rname, region_intervals, space_cm=SCREEN_WIDTH_CM)

region_names = list(regions.keys())
raw_weights = [float(regions[r]['prob_spawn']) for r in region_names]
weight_sum = sum(raw_weights)
if weight_sum <= 0.0:
    raise ValueError("Sum of region spawn weights must be > 0.")
if AUTO_NORMALIZE_SPAWN_PROBS:
    region_spawn_weights = [w / weight_sum for w in raw_weights]
    if abs(weight_sum - 1.0) > PROB_SUM_TOL:
        print(f"[INFO] region 'prob_spawn' values summed to {weight_sum:.6f}; auto-normalized to probabilities.", flush=True)
else:
    region_spawn_weights = raw_weights

prev_applied_delta_by_region = {r: 0.0 for r in region_names}
DEFAULT_SLIP_ALPHA = 0.12

# ============================
# NEW: compute max possible obstructions (when OBSTRUCTION_NUM is None)
#      and use it for BOTH:
#      - max_num_obstructions (generation cap)
#      - _log_max_obstructions (log columns)
#      This is intentionally decoupled from drawing.
# ============================
def compute_max_possible_obstructions():
    """
    Upper bound on how many obstructions *could* be generated given the current
    screen geometry and OBSTRUCTION_Y_DIST_RANGE.

    We assume:
      - earliest first y is ymin + min_dist
      - subsequent steps are min_dist
    This yields the maximum count that could fit.
    """
    ymin = float(OBSTRUCTION_Y_BUFFER)
    ymax = float(SCREEN_HEIGHT_CM) - float(OBSTRUCTION_Y_BUFFER)
    if ymax <= ymin:
        return 0

    try:
        min_dist = float(OBSTRUCTION_Y_DIST_RANGE[0])
    except Exception:
        min_dist = 4.0

    if min_dist <= 0:
        # avoid infinite counts
        return 0

    first_y = ymin + min_dist
    if first_y > ymax:
        return 0

    available = ymax - first_y
    # count = 1 (first) + number of additional min_dist steps that still fit
    n_additional = int(available // min_dist)
    return 1 + n_additional

# Determine max_num_obstructions and _log_max_obstructions
if OBSTRUCTION_NUM is None:
    max_num_obstructions = compute_max_possible_obstructions()
else:
    max_num_obstructions = int(OBSTRUCTION_NUM)

# If you want a safety floor, keep it >= 0
max_num_obstructions = max(0, max_num_obstructions)

# This is what defines how many obstruction columns exist in the log:
_log_max_obstructions = max_num_obstructions

# ============================
# Visual / window setup
# ============================
mon = monitors.Monitor('experiment_monitor_portrait')
mon.setWidth(SCREEN_WIDTH_CM)
mon.setSizePix(SCREEN_PIX)

win = visual.Window(size=SCREEN_PIX, fullscr=True, monitor=mon,
                    units='cm', color=(-1.0, -1.0, -1.0), waitBlanking=True, screen=1)

#### By Shizhao Liu": hide mouse
win.mouseVisible = False
mouse = event.Mouse()
mouse.setPos((0,0))

circle = visual.Circle(win, radius=CIRCLE_RADIUS_CM, fillColor=(1.0, 1.0, 1.0),
                       lineColor=None, edges=64, pos=(0.0, 0.0))

success_text = visual.TextStim(win, text='SUCCESS!', height=2.5, bold=True, pos=(0.0, 0.0))

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
# Warmup: textures & prep
# ============================
print(f"[INFO] Warmup for {WARMUP_S:.1f}s starting (textures will be generated now)...", flush=True)
warmup_start_ts = perf_counter()

PATCH_SQUARE_SIZE_CM = 5.0
PATCH_COLOR_OPACITY = 1.0
PATCH_COLOR_FRACTION = 0.2
region_textures_full = {}

for rname, rconf in regions.items():
    cname = rconf.get('color', 'black').lower()
    if cname == 'black':
        continue
    patch_size_cm = float(rconf.get('patch_size_cm', PATCH_SQUARE_SIZE_CM))
    patch_opacity = float(rconf.get('patch_opacity', PATCH_COLOR_OPACITY))
    patch_fraction = float(rconf.get('patch_fraction', PATCH_COLOR_FRACTION))
    patch_shape = str(rconf.get('patch_shape', 'square')).lower()
    if patch_shape not in ('square', 'triangle', 'circle'):
        patch_shape = 'square'
    color01 = np.array(((np.array(name_to_color_rgb_minus1_to_1(cname)) + 1.0) / 2.0), dtype=np.float32)
    square_px = max(1, int(round(patch_size_cm * pixels_per_cm)))
    tex = np.full((full_height_px, full_world_px, 3), -1.0, dtype=np.float32)
    blended01 = color01 * patch_opacity
    blended_minus1 = (blended01 * 2.0) - 1.0
    region_segs = region_intervals.get(rname, [])
    ppcc = pixels_per_cm
    for x0 in range(0, full_world_px, square_px):
        world_x_cm = (x0 + 0.5 * square_px) / ppcc
        inside_column = any((s_cm <= world_x_cm) and (world_x_cm < e_cm) for (s_cm, e_cm) in region_segs)
        if not inside_column:
            continue
        x1 = x0
        x2 = min(full_world_px, x0 + square_px)
        cell_w = x2 - x1
        if cell_w <= 0:
            continue
        for y0 in range(0, full_height_px, square_px):
            if random.random() >= patch_fraction:
                continue
            y1 = y0
            y2 = min(full_height_px, y0 + square_px)
            cell_h = y2 - y1
            if cell_h <= 0:
                continue
            xs = (np.arange(cell_w) + 0.5) / float(cell_w)
            ys = (np.arange(cell_h) + 0.5) / float(cell_h)
            xv, yv = np.meshgrid(xs, ys)
            if patch_shape == 'square':
                mask = np.ones((cell_h, cell_w), dtype=bool)
            elif patch_shape == 'circle':
                cx = 0.5; cy = 0.5; r = 0.45
                mask = ((xv - cx)**2 + (yv - cy)**2) <= (r*r)
            elif patch_shape == 'triangle':
                A = (0.5, 0.12); B = (0.12, 0.88); C = (0.88, 0.88)
                mask = _point_in_triangle(xv, yv, A, B, C)
            else:
                mask = np.ones((cell_h, cell_w), dtype=bool)
            if not np.any(mask):
                continue
            for ch in range(3):
                channel = tex[y1:y2, x1:x2, ch]
                channel[mask] = blended_minus1[ch]
                tex[y1:y2, x1:x2, ch] = channel
    tex_tiled = np.vstack([tex, tex]).astype(np.float32)
    region_textures_full[rname] = tex_tiled

warmup_elapsed = perf_counter() - warmup_start_ts
if warmup_elapsed < WARMUP_S:
    remaining = WARMUP_S - warmup_elapsed
    print(f"[INFO] Warmup continuing: waiting additional {remaining:.2f}s", flush=True)
    core.wait(remaining)
print("[INFO] Warmup complete — starting experiment proper and opening logs.", flush=True)

# ============================
# Obstructions: generation & storage (static bars)
# ============================
obstructions = []  # list of dicts: {'x': bottom-left x in cm, 'y': bottom-left y in cm, 'w': cm, 'h': cm, 'hit':0}

def circle_rect_collides(circle_cx_bl, circle_cy_bl, circle_r, rect_x, rect_y, rect_w, rect_h):
    closest_x = _clamp(circle_cx_bl, rect_x, rect_x + rect_w)
    closest_y = _clamp(circle_cy_bl, rect_y, rect_y + rect_h)
    dx = circle_cx_bl - closest_x
    dy = circle_cy_bl - closest_y
    return (dx*dx + dy*dy) <= (circle_r * circle_r)

def generate_obstructions():
    """
    Generate obstructions positions for the current screen (bottom-left coordinates).
    """
    global obstructions
    obstructions = []
    if not SPAWN_OBSTRUCTIONS:
        return

    ymin = OBSTRUCTION_Y_BUFFER
    ymax = SCREEN_HEIGHT_CM - OBSTRUCTION_Y_BUFFER
    if ymax <= ymin:
        return

    try:
        ymin_dist, ymax_dist = float(OBSTRUCTION_Y_DIST_RANGE[0]), float(OBSTRUCTION_Y_DIST_RANGE[1])
    except Exception:
        ymin_dist, ymax_dist = 4.0, 8.0

    # If max_num_obstructions == 0, we still might want none
    if max_num_obstructions <= 0:
        return

    y = ymin + random.uniform(ymin_dist, ymax_dist)
    count = 0
    centers_x = []
    while y <= ymax and count < max_num_obstructions:
        chosen_x = None
        attempts = 0
        while attempts < 20:
            cand_x = random.uniform(0.0, SCREEN_WIDTH_CM)
            cand_center_x = cand_x + (OBSTRUCTION_WIDTH_CM / 2.0)
            ok = True
            for cx in centers_x:
                if abs(cx - cand_center_x) < OBSTRUCTION_MIN_CENTER_DIST_X:
                    ok = False
                    break
            if ok:
                chosen_x = cand_x
                break
            attempts += 1
        if chosen_x is None:
            chosen_x = cand_x
        obstructions.append({
            'x': float(chosen_x),
            'y': float(y),
            'w': float(OBSTRUCTION_WIDTH_CM),
            'h': float(OBSTRUCTION_HEIGHT_CM),
            'hit': 0
        })
        centers_x.append(chosen_x + (OBSTRUCTION_WIDTH_CM / 2.0))
        count += 1
        y += random.uniform(ymin_dist, ymax_dist)

# ============================
# State & spawn helpers
# ============================
mouse_center_cm = SPACE_WIDTH_CM / 2.0
balls = []
next_spawn_time = None
last_spawn_ts = None
respawn_time = None
show_success_until = None
last_spawn_region = None

frame_idx = 0
clock = core.Clock()
last_time = clock.getTime()
scenery_offset_cm = 0.0

global_spawn_id = 0
sync_start_ts = None
reward_active_until = 0.0
reward_state_pulse_pending = False

def wrap_pos(pos, width):
    return pos % width

def window_start_end(center, screen_w, space_w):
    start = wrap_pos(center - (screen_w / 2.0), space_w)
    end = wrap_pos(start + screen_w, space_w)
    return start, end

def is_in_window(val, start, end, space_w, eps=1e-9):
    if start <= end:
        return (start - eps) <= val <= (end + eps)
    else:
        return (val >= (start - eps)) or (val <= (end + eps))

def world_to_screen_x(world_x_cm, start, screen_w, space_w, clamp=True):
    if start + screen_w <= space_w:
        rel = world_x_cm - start
    else:
        if world_x_cm >= start:
            rel = world_x_cm - start
        else:
            rel = (space_w - start) + world_x_cm
    if clamp:
        rel = max(0.0, min(rel, screen_w))
    screen_x = rel - (screen_w / 2.0)
    return screen_x

def spawn_ball_ts(now_ts, win_start, window_intervals):
    global last_spawn_ts, next_spawn_time, global_spawn_id, sync_start_ts, last_spawn_region

    spawn_interval_s = random.uniform(*SPAWN_INTERVAL_RANGE)
    if SPAWN_DISTRIBUTION == "gaussian":
        spawn_center_cm = random.choice(SPAWN_GAUSS_CENTER_LIST)
        spawn_world = general_spawn_gaussian_on_screen_center(
            win_start=win_start,
            screen_w=SCREEN_WIDTH_CM,
            space_w = SPACE_WIDTH_CM,
            spawn_center_cm = spawn_center_cm,
            sigma_cm=SPAWN_GAUSS_SIGMA_CM,
            clamp_to_screen=SPAWN_GAUSS_CLAMP_TO_SCREEN,
            max_resamples=SPAWN_GAUSS_RESAMPLE_MAX
        )
    else:
        spawn_world = general_spawn_uniform_on_screen(win_start, window_intervals, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)


    # spawn_world = general_spawn_uniform_on_screen(win_start, window_intervals, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
    chosen_region = None
    for r in region_names:
        for (s, e) in region_intervals[r]:
            if s <= spawn_world < e:
                chosen_region = r
                break
        if chosen_region:
            break
    last_spawn_region = chosen_region

    global_spawn_id += 1
    ball = {
        'world_x_cm': float(spawn_world) % SPACE_WIDTH_CM,
        'y_cm': half_screen_h - CIRCLE_RADIUS_CM - SPAWN_Y_OFFSET, # By Shizhao Liu 03/06/2026. Add an offset so that the ball can start closer to the animal
        'spawn_ts': now_ts,
        'spawn_region': last_spawn_region,
        'spawn_id': global_spawn_id
    }
    balls.append(ball)

    if sync_start_ts is None:
        sync_start_ts = perf_counter()

    last_spawn_ts = now_ts
    next_spawn_time = None
    return ball

def initial_spawn():
    win_start, win_end = window_start_end(mouse_center_cm, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
    window_intervals = [(win_start, win_start + SCREEN_WIDTH_CM)] if (win_start + SCREEN_WIDTH_CM <= SPACE_WIDTH_CM) else [(win_start, SPACE_WIDTH_CM), (0.0, (win_start + SCREEN_WIDTH_CM) - SPACE_WIDTH_CM)]
    spawn_ball_ts(perf_counter(), win_start, window_intervals)

def apply_gain_function_for_region(region_name, raw_target_delta, dt, region_conf):
    global prev_applied_delta_by_region
    if region_name is None or region_conf is None:
        return raw_target_delta
    prev = float(prev_applied_delta_by_region.get(region_name, 0.0))
    applied = raw_target_delta
    prev_applied_delta_by_region[region_name] = float(applied)
    return applied

# ============================
# Sync log header & open file (behavior: no prbs_bit)
# ============================
sync_f = open(SYNC_LOG_FILENAME, 'w', newline='')
sync_writer = csv.writer(sync_f)

_log_max_balls = MAX_NUM_BALLS if (MAX_NUM_BALLS is not None) else _DEFAULT_LOG_MAX_BALLS
# IMPORTANT: _log_max_obstructions was computed above and is NOT used for drawing.

header = [
    'frame_idx', 't_global_s', 'window_deg_range', 'mouse_center_deg',
    'current_region', 'linear_velocity_cm_s', 'reward_state', 
    'running_tick_sum','wheel_is_stationary', # Shizhao Liu 0206: added a varible to indicate whether the wheel is stationary
    'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'base_delta_cm', 'delta_cm', 'gain_applied'
]
for i in range(1, _log_max_balls + 1):
    header.append(f"slot{i}")
for i in range(1, _log_max_obstructions + 1):
    header.append(f"obs_slot{i}")
sync_writer.writerow(header)
sync_f.flush()

next_spawn_time = None
print("Starting loop with spawn modes — press ESC to quit.", flush=True)
event.clearEvents()

# ============================
# Stimulus pools for efficient drawing
# ============================

BLACK_COLOR = name_to_color_rgb_minus1_to_1('black')
MAX_REGION_SEGMENTS = 32

region_rect_pool = [
    visual.Rect(win, width=1.0, height=SCREEN_HEIGHT_CM, pos=(0.0, 0.0),
                fillColor=BLACK_COLOR, lineColor=None)
    for _ in range(MAX_REGION_SEGMENTS)
]
cover_rect_pool = [
    visual.Rect(win, width=1.0, height=1.0, pos=(0.0, 0.0),
                fillColor=BLACK_COLOR, lineColor=None)
    for _ in range(MAX_REGION_SEGMENTS)
]
region_image_pool = [
    visual.ImageStim(win, image=np.zeros((10, 10, 3), dtype=np.float32),
                     size=(1.0, SCREEN_HEIGHT_CM), pos=(0.0, 0.0),
                     interpolate=False)
    for _ in range(MAX_REGION_SEGMENTS)
]

# ============================
# CHANGED: draw pool size is based on max_num_obstructions,
#          NOT on _log_max_obstructions.
# ============================
obstruction_rects = [
    visual.Rect(win,
                width=OBSTRUCTION_WIDTH_CM,
                height=OBSTRUCTION_HEIGHT_CM,
                pos=(0.0, 0.0),
                fillColor=(1.0, 1.0, 1.0),
                lineColor=None)
    for _ in range(max(1, max_num_obstructions))
]

# ============================
# Main loop
# ============================
experiment_start_ts = perf_counter()
last_obstruction_regen_ts = None
#### These two variables are for detecting stationary intervals
delta_tick_history = []
running_tick_sum = 0.0

try:
    flicker_start_ts = perf_counter() 

    last_obstruction_regen_ts = experiment_start_ts if SPAWN_OBSTRUCTIONS else None
    if SPAWN_OBSTRUCTIONS:
        generate_obstructions()

    initial_spawn()

    while True:
        #### Record current time
        if RUNTIME_TIMEOUT_MINUTES and RUNTIME_TIMEOUT_MINUTES > 0:
            if (perf_counter() - experiment_start_ts) > (RUNTIME_TIMEOUT_MINUTES * 60.0):
                print("[INFO] Runtime timeout reached — exiting.", flush=True)
                break

        now = clock.getTime()
        dt = now - last_time
        last_time = now
        frame_loop_start = now
        ts = perf_counter()

        if SPAWN_OBSTRUCTIONS and OBSTRUCTION_REGEN_TIME is not None and OBSTRUCTION_REGEN_TIME > 0.0:
            if (ts - (last_obstruction_regen_ts or 0.0)) >= OBSTRUCTION_REGEN_TIME:
                generate_obstructions()
                last_obstruction_regen_ts = ts

        dt_clamped = min(dt, 0.1)

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

        ### translate ticks to center meters on the screen
        base_delta_cm = delta_ticks * WHEEL_GAIN_CM_PER_TICK

        center_deg = cm_to_deg(mouse_center_cm)
        current_region_name = None
        for rname, rconf in regions.items():
            sdeg, edeg = rconf['deg_range']
            if deg_in_range(sdeg, edeg, center_deg):
                current_region_name = rname
                break
        gain_applied = regions[current_region_name]['gain'] if current_region_name is not None else 1.0

        raw_target_delta = base_delta_cm * gain_applied
        delta_cm = apply_gain_function_for_region(current_region_name, raw_target_delta, dt_clamped, regions.get(current_region_name, {}))

        if abs(delta_cm) > MAX_MOVE_PER_FRAME_CM:
            delta_cm = 0.0
            delta_ticks = 0

        if delta_ticks != 0:
            mouse_center_cm = wrap_pos(mouse_center_cm - delta_cm, SPACE_WIDTH_CM)
            reference_ticks = enc_ticks
        else:
            reference_ticks = enc_ticks

        win_start, win_end = window_start_end(mouse_center_cm, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
        if win_start + SCREEN_WIDTH_CM <= SPACE_WIDTH_CM:
            window_intervals = [(win_start, win_start + SCREEN_WIDTH_CM)]
        else:
            window_intervals = [(win_start, SPACE_WIDTH_CM), (0.0, (win_start + SCREEN_WIDTH_CM) - SPACE_WIDTH_CM)]

        region_rects = []
        for rname, segs in region_intervals.items():
            for seg_s, seg_e in segs:
                for w_s, w_e in window_intervals:
                    inter = intersect_intervals(seg_s, seg_e, w_s, w_e)
                    if inter is not None:
                        inter_s, inter_e = inter
                        length = inter_e - inter_s
                        if inter_s >= win_start:
                            rel_left = inter_s - win_start
                        else:
                            rel_left = (SPACE_WIDTH_CM - win_start) + inter_s
                        screen_left = rel_left - (SCREEN_WIDTH_CM / 2.0)
                        rect_width = length
                        rect_center_x = screen_left + (rect_width / 2.0)
                        color_minus1 = name_to_color_rgb_minus1_to_1(regions[rname]['color'])
                        region_rects.append({
                            'region': rname,
                            'left_cm': inter_s,
                            'right_cm': inter_e,
                            'length_cm': length,
                            'center_x': rect_center_x,
                            'width': rect_width,
                            'color': color_minus1
                        })

        v_center = regions.get(current_region_name, {}).get('linear_velocity')
        scenery_speed_cm_s = float(v_center) if (v_center is not None) else BALL_FALL_SPEED_CM_S

        scenery_offset_cm = (scenery_offset_cm + scenery_speed_cm_s * dt_clamped) % SCREEN_HEIGHT_CM


        ##### By Shizhao Liu 02/26/26
        ### Detect if wheel is stationary. O
        ### If SPAWN_ONLY_STATIONARY is true, only generate balls when the wheel is relatively stationary
        wheel_is_stationary = False # reset to false unless the below condition is met
        if (perf_counter() - sync_start_ts) >  (STATIONARY_INTERVAL / 1000):
            running_tick_sum -= delta_tick_history[0]
            delta_tick_history.pop(0)
        delta_tick_history.append(abs(delta_ticks))
        running_tick_sum += abs(delta_ticks)

        if running_tick_sum < STATIONARY_TOLERANCE and (perf_counter() - sync_start_ts) > (STATIONARY_INTERVAL / 1000): ### stationary enough in the last time window
            wheel_is_stationary = True

        if next_spawn_time is not None and ts >= next_spawn_time:
            # spawn_ball_ts(ts, win_start, window_intervals)
            if (not SPAWN_ONLY_STATIONARY) | (SPAWN_ONLY_STATIONARY and wheel_is_stationary):
                spawn_ball_ts(ts, win_start, window_intervals)
            


        for obs in obstructions:
            obs['hit'] = 0

        remove_indices = []
        reward_sent_this_frame = False
        visible_ball_flags = []

        # ===========================================
        # Detect if balls hit the bottom of the screen edge
        # Is so, take appropriate actions
        # ===========================================
        for bi, ball in enumerate(balls):
            ball['y_cm'] -= scenery_speed_cm_s * dt_clamped
            bottom_threshold = -half_screen_h + CIRCLE_RADIUS_CM

            horiz_in = is_in_window(ball['world_x_cm'], win_start, win_end, SPACE_WIDTH_CM)

            collided_with_obstruction = False
            if SPAWN_OBSTRUCTIONS and horiz_in and obstructions:
                drawn_x = world_to_screen_x(ball['world_x_cm'], win_start, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
                ball_bl_x = drawn_x + half_screen_w
                ball_bl_y = ball['y_cm'] + half_screen_h

                for oi, obs in enumerate(obstructions):
                    if circle_rect_collides(ball_bl_x, ball_bl_y, CIRCLE_RADIUS_CM,
                                            obs['x'], obs['y'], obs['w'], obs['h']):
                        obs['hit'] = 1
                        collided_with_obstruction = True
                        break
            #   Added by Shizhao Liu: make balls disappear if they hit the edge of screen
            collided_with_screen_edge = False
            if SREEEN_EDGE_OBSTRUCTION:
                drawn_x = world_to_screen_x(ball['world_x_cm'], win_start, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
                if abs(drawn_x) >= half_screen_w:
                    collided_with_screen_edge = True

            #if collided_with_obstruction:
            if collided_with_obstruction or collided_with_screen_edge:
                remove_indices.append(bi)
                if not MULTIPLE_BALLS:
                    next_spawn_time = ts + random.uniform(*SPAWN_INTERVAL_RANGE)
                continue
            
            
                 
            reach_bottom = 0
            if ball['y_cm'] <= bottom_threshold:
                reach_bottom = 1
                if horiz_in:
                    drawn_x = world_to_screen_x(ball['world_x_cm'], win_start, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
                    tolerance = SUCCESS_EDGE_TOLERANCE_MULT * CIRCLE_RADIUS_CM
                    if abs(drawn_x) <= tolerance and (not reward_sent_this_frame):
                        if send_reward(REWARD_DURATION_MS):
                            reward_sent_this_frame = True
                            reward_active_until = perf_counter() + (REWARD_DURATION_MS / 1000.0)
                            reward_state_pulse_pending = True

                remove_indices.append(bi)
                if not MULTIPLE_BALLS:
                    next_spawn_time = ts + random.uniform(*SPAWN_INTERVAL_RANGE)

            visible_ball_flags.append(int(horiz_in))

        ##### By Shizhao Liu 02/26/26: I want to move this "pop" after logging so that the last state of a ball is saved
        # for bi in sorted(remove_indices, reverse=True):
        #     balls.pop(bi)

        # draw
        win.clearBuffer()
        offset_px = int(round(scenery_offset_cm * vertical_pixels_per_cm)) % full_height_px
        flicker_on_now = True

        rect_idx = 0
        img_idx = 0
        cover_idx = 0

        for rseg in region_rects:
            rname = rseg['region']
            rcfg = regions[rname]

            show_region_texture = bool(rcfg.get('spatial_visibility', True)) or (current_region_name == rname)

            if show_region_texture and (rname in region_textures_full):
                if img_idx >= len(region_image_pool):
                    continue
                full_tex = region_textures_full[rname]
                left_px = int(round((rseg['left_cm'] / SPACE_WIDTH_CM) * full_world_px))
                seg_px = int(round((rseg['length_cm'] / SPACE_WIDTH_CM) * full_world_px))
                if seg_px <= 0:
                    continue
                crop = full_tex[offset_px:offset_px + full_height_px, left_px:left_px + seg_px, :]
                if crop.shape[1] <= 0 or crop.shape[0] <= 0:
                    continue
                img_stim = region_image_pool[img_idx]
                img_stim.image = crop
                img_stim.size = (rseg['width'], SCREEN_HEIGHT_CM)
                img_stim.pos = (rseg['center_x'], 0.0)
                img_stim.draw()
                img_idx += 1
            else:
                if rect_idx >= len(region_rect_pool):
                    continue
                rect = region_rect_pool[rect_idx]
                rect.width = rseg['width']
                rect.height = SCREEN_HEIGHT_CM
                rect.pos = (rseg['center_x'], 0.0)
                rect.fillColor = rseg['color'] if show_region_texture else BLACK_COLOR
                rect.draw()
                rect_idx += 1

            temp_vis_pct = float(rcfg.get('temporal_visibility', 100.0))
            if temp_vis_pct < 100.0:
                visible_height_cm = SCREEN_HEIGHT_CM * (temp_vis_pct / 100.0)
                top_cover_height = SCREEN_HEIGHT_CM - visible_height_cm
                if top_cover_height > 0.0 and cover_idx < len(cover_rect_pool):
                    cover_center_y = half_screen_h - (top_cover_height / 2.0)
                    cover_rect = cover_rect_pool[cover_idx]
                    cover_rect.width = rseg['width']
                    cover_rect.height = top_cover_height
                    cover_rect.pos = (rseg['center_x'], cover_center_y)
                    cover_rect.fillColor = BLACK_COLOR
                    cover_rect.draw()
                    cover_idx += 1

        # ============================
        # CHANGED: draw up to max_num_obstructions (and thus up to pool size),
        #          independent of how many columns you log.
        # ============================
        if SPAWN_OBSTRUCTIONS:
            n_obs = len(obstructions)
            if n_obs > len(obstruction_rects) and (frame_idx % 120 == 0):
                print(f"[WARN] {n_obs} obstructions generated but only {len(obstruction_rects)} drawable. Increase computed max.", flush=True)

            for i in range(min(n_obs, len(obstruction_rects))):
                obs = obstructions[i]
                center_x = (obs['x'] + obs['w']/2.0) - half_screen_w
                center_y = (obs['y'] + obs['h']/2.0) - half_screen_h
                rect = obstruction_rects[i]
                rect.width = obs['w']
                rect.height = obs['h']
                rect.pos = (center_x, center_y)
                rect.draw()

        for idx, ball in enumerate(balls):
            if idx < len(visible_ball_flags) and visible_ball_flags[idx] and flicker_on_now:
                drawn_x = world_to_screen_x(ball['world_x_cm'], win_start, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
                circle.pos = (drawn_x, ball['y_cm'])
                circle.opacity = float(max(0.0, min(1.0, BALL_OPACITY)))
                circle.draw()

        win.flip()
        # ==================================
        # Logging
        # ===================================
        win_start_deg = cm_to_deg(win_start)
        screen_span_deg = (SCREEN_WIDTH_CM / SPACE_WIDTH_CM) * SPACE_DEGREES
        win_end_deg = (win_start_deg + screen_span_deg) % SPACE_DEGREES
        window_deg_range = f"({win_start_deg:.1f},{win_end_deg:.1f})"

        if sync_start_ts is None and len(balls) > 0:
            sync_start_ts = perf_counter()

        t_global = f"{(perf_counter() - sync_start_ts):.6f}" if sync_start_ts is not None else ''

        if reward_state_pulse_pending:
            reward_state_now = 1
            reward_state_pulse_pending = False
        else:
            reward_state_now = 1 if (perf_counter() < reward_active_until) else 0

        enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{base_delta_cm:.4f}", f"{delta_cm:.4f}"]
        gain_col = f"{gain_applied:.4f}"

        slot_cells = [''] * _log_max_balls
        if len(balls) > 0:
            b = balls[-1]
            sid = int(b.get('spawn_id', 0))
            ball_deg = cm_to_deg(b['world_x_cm'])
            rel_deg = (ball_deg - cm_to_deg(mouse_center_cm)) % 360.0
            ball_bl_y = b['y_cm'] + half_screen_h
            slot_cells[0] = f"{sid}|{rel_deg:.1f}|{ball_bl_y:.3f}|1"

        # IMPORTANT: log columns match max_num_obstructions
        obs_slots = []
        for oi in range(_log_max_obstructions):
            if oi < len(obstructions):
                obs = obstructions[oi]
                obs_index = oi + 1
                width = obs['w']
                obs_center_screen_x = obs['x'] + (obs['w'] / 2.0)
                obs_world_x = wrap_pos(win_start + obs_center_screen_x, SPACE_WIDTH_CM)
                xdeg_from_mouse = cm_to_deg((obs_world_x - mouse_center_cm) % SPACE_WIDTH_CM)
                ycm_from_mouse = obs['y'] + (obs['h'] / 2.0)
                is_hit = int(obs.get('hit', 0))
                obs_slots.append(f"{obs_index}|{width:.2f}|{xdeg_from_mouse:.1f}|{ycm_from_mouse:.3f}|{is_hit}")
            else:
                obs_slots.append("")

        # Start with the header
        row = [
            frame_idx,
            t_global,
            window_deg_range,
            f"{cm_to_deg(mouse_center_cm):.2f}",
            (current_region_name if current_region_name is not None else ''),
            f"{scenery_speed_cm_s:.3f}",
            reward_state_now,
            running_tick_sum,
            wheel_is_stationary
        ]
        row += enc_cols
        row.append(gain_col)
        row += slot_cells
        row += obs_slots

        sync_writer.writerow(row)
        if frame_idx % LOG_FLUSH_INTERVAL_FRAMES == 0:
            sync_f.flush()

        frame_idx += 1

        #### Remove finished balls (reached bottom or touched the screen edge)
        #### By Shizhao Liu 02/26/26: moved this after logging so that the last state of a ball is saved
        for bi in sorted(remove_indices, reverse=True):
            balls.pop(bi)

        
        # =================
        # Escape
        # =================
        if frame_idx % 10 == 0 and event.getKeys(['escape']):
            print("Escape pressed — exiting.", flush=True)
            break

        elapsed = clock.getTime() - frame_loop_start
        to_wait = TARGET_DT - elapsed
        if to_wait > 0:
            core.wait(to_wait)

except KeyboardInterrupt:
    print("Interrupted — exiting.", flush=True)
except Exception:
    tb = traceback.format_exc()
    print("[ERROR] Unhandled exception in main loop:\n" + tb, flush=True)
    try:
        with open(ERROR_LOG_PATH, 'w') as ef:
            ef.write(tb)
    except Exception:
        pass
    raise
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
    reward_num = count_reward(SYNC_LOG_FILENAME)
    print("Number of reward:", reward_num)
    print("Amount of reward:", reward_num * REWARD_TARGET)

    # ====== Save the configuration file
    save_config(exp_config, EXP_CONFIG_FILENAME)
    win.close()
    core.quit()
    print("Clean exit.", flush=True)
