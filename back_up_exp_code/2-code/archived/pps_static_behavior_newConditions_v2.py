"""
Static-obstruction behavior experiment. The prbs thread and logging has been removed.

Notes:
 - Static white-bar obstructions placed on the screen (bottom-left coordinate system)
 - Balls aawn and fall with the scenery; collisions with obstructions remove balls
 - Arduino reward control (optional pyserial)
 - Sync log includes ball slot columns and obstruction slot columns:
     slotN entries format: spawn_id|x_deg|y_cm|is_visible|radius_cm  (is_visible = 0/1 and includes flicker)
     obs_slotN entries format: obs_index|width_cm|xdeg_from_mouse|ycm_from_mouse|is_hit
 - This is the BEHAVIOR version: PRBS/Bpod removed; no TTL thread; no prbs_bit column.
"""

import csv
import random
import threading
import multiprocessing as mp
import time
import os
import traceback
from time import perf_counter
from datetime import datetime
import sys
from dataclasses import dataclass, asdict
import json

import numpy as np
from psychopy import visual, core, event, monitors
from pybpodapi.protocol import Bpod

from util_general import load_json, deep_update, count_reward


from scipy.io import savemat

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


# Prompt for mouse name (blocking console input)
mouse_name  = input("Enter mouse name (short, no spaces): ").strip()
if not mouse_name:
    mouse_name = "mouseUNK"

# RIG_NAME    = input("Enter rig name: ").strip()
# RIG_NAME_LIST = ['PPS_training_Rig_3', 'PPS_training_Rig_2', 'PPS_training_Rig_1', 'PPS_recording_Rig_1']
# if RIG_NAME not in RIG_NAME_LIST:
#     raise ValueError(f"{RIG_NAME} not found in existing rig list")

RIG_NAME_LIST = ['PPS_training_Rig_1', 'PPS_training_Rig_2', 'PPS_training_Rig_3', 'PPS_recording_Rig_1']
print("\nAvailable rigs:")
for i, opt in enumerate(RIG_NAME_LIST, start=1):
    print(f"{i}. {opt}")

try:
    selected_index = int(input("Select rig number: ")) - 1
    selected_option = RIG_NAME_LIST[selected_index]
except Exception:
    print("Invalid rig selection.")
    sys.exit(1)

RIG_NAME = selected_option

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
EXP_CONFIG_PATH = os.path.join(home_path, "3-config-json/exp_default/config_default_pps_static_behavior_newParams.json")
default_exp_config = load_json(EXP_CONFIG_PATH)
config_all = deep_update(hardware_config, default_exp_config)

ANIMAL_CONFIG_PATH = os.path.join(home_path,f"3-config-json/subject_exp/{mouse_name}/config_{mouse_name}_pps_static_behavior_newParams.json")
#if os.path.exists(ANIMAL_CONFIG_PATH):
animal_config = load_json(ANIMAL_CONFIG_PATH)
config_all = deep_update(config_all, animal_config)
print(f"[INFO] Loaded animal-specific parameters from: {ANIMAL_CONFIG_PATH}")
# else:
#     print(f"[WARNING] {ANIMAL_CONFIG_PATH} not found. Using default parameters only.")


rig_conf                    = config_all["hardware"]
exp_conf                    = config_all["experiment"]
reward_conf                 = config_all["reward"]
ball_conf                   = config_all["ball"]
spawn_conf                  = config_all["spawn"]
obstruction_conf            = config_all["obstruction"]
region1_conf                = config_all["region_1"]

# ================================================================
# hardware/general parameters
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
# ================================================================
# experimental parameters
RUNTIME_TIMEOUT_MINUTES         = exp_conf["RUNTIME_TIMEOUT_MINUTES"] 
WHEEL_GAIN_DISTRIBUTION         = exp_conf["WHEEL_GAIN_DISTRIBUTION"] # "sample" or "choice"
WHEEL_GAIN_CM_PER_TICK_LIST     = tuple(exp_conf["WHEEL_GAIN_CM_PER_TICK_LIST"]) 
WHEEL_GAIN_CM_PER_TICK_RANGE    = tuple(exp_conf["WHEEL_GAIN_CM_PER_TICK_RANGE"])
#WHEEL_JITTER_COEF_LIST          = exp_conf["WHEEL_JITTER_COEF_LIST"] 
WHEEL_JITTER_COEF               = exp_conf["WHEEL_JITTER_COEF"] 
WHEEL_JITTER_INTERCEPT          = exp_conf["WHEEL_JITTER_INTERCEPT"] 
NO_JITTER_PORTION               = exp_conf["NO_JITTER_PORTION"] 
SUCCESS_EDGE_TOLERANCE_RANGE    = tuple(exp_conf["SUCCESS_EDGE_TOLERANCE_RANGE"])
SPACE_DEGREES                   = exp_conf["SPACE_DEGREES"]
WARMUP_S                        = exp_conf["WARMUP_S"]
# ================================================================
# ball parameters
BALL_FALL_SPEED_DISTRIBUTION            = ball_conf["BALL_FALL_SPEED_DISTRIBUTION"]
BALL_FALL_SPEED_CM_S_RANGE              = tuple(ball_conf["BALL_FALL_SPEED_CM_S_RANGE"]) 
BALL_FALL_SPEED_CM_S_LIST               = tuple(ball_conf["BALL_FALL_SPEED_CM_S_LIST"])
BALL_RANDOM_WALK_DISTRIBUTION           = ball_conf["BALL_RANDOM_WALK_DISTRIBUTION"]
BALL_RANDOM_WALK_VEL_BIAS_LIST          = tuple(ball_conf["BALL_RANDOM_WALK_VEL_BIAS_LIST"])
BALL_RANDOM_WALK_VEL_STD_LIST           = tuple(ball_conf["BALL_RANDOM_WALK_VEL_STD_LIST"])
BALL_RANDOM_WALK_VEL_BIAS_SCALE          = ball_conf["BALL_RANDOM_WALK_VEL_BIAS_SCALE"] 
BALL_RANDOM_WALK_VEL_STD_RANGE           = tuple(ball_conf["BALL_RANDOM_WALK_VEL_STD_RANGE"])
NO_RANDOM_WALK_PORTION                  = ball_conf["NO_RANDOM_WALK_PORTION"]  
CIRCLE_RADIUS_CM_LIST                   = tuple(ball_conf["CIRCLE_RADIUS_CM_LIST"])
BALL_OPACITY_DISTRIBUTION               = ball_conf["BALL_OPACITY_DISTRIBUTION"] 
BALL_OPACITY_LIST                       = ball_conf["BALL_OPACITY_LIST"]
BALL_OPACITY_RANGE                      = ball_conf["BALL_OPACITY_RANGE"]
BALL_OPACITY_LAMBDA                     = ball_conf["BALL_OPACITY_LAMBDA"] 
HIGH_OPACITY_PORTION                    = ball_conf["HIGH_OPACITY_PORTION"] 
BALL_FLICKER_DURATION                   = ball_conf["BALL_FLICKER_DURATION"]
BALL_FLICKER_INTERVAL                   = ball_conf["BALL_FLICKER_INTERVAL"]
#=================================================================
## spawn parameters
#CIRCLE_RADIUS_CM_LIST       = spawn_conf["CIRCLE_RADIUS_CM_LIST"]
SPAWN_DISTRIBUTION          = spawn_conf["SPAWN_DISTRIBUTION"]
SPAWN_GAUSS_CENTER_LIST     = spawn_conf["SPAWN_GAUSS_CENTER_LIST"]
SPAWN_GAUSS_SIGMA_CM        = spawn_conf["SPAWN_GAUSS_SIGMA_CM"]
SPAWN_GAUSS_RESAMPLE_MAX    = spawn_conf["SPAWN_GAUSS_RESAMPLE_MAX"]
SPAWN_GAUSS_CLAMP_TO_SCREEN = spawn_conf["SPAWN_GAUSS_CLAMP_TO_SCREEN"]
SPAWN_UNIFORM_RANGE         = spawn_conf["SPAWN_UNIFORM_RANGE"] 
SPAWN_Y_OFFSET              = spawn_conf["SPAWN_Y_OFFSET"]
SPAWN_ONLY_STATIONARY       = spawn_conf["SPAWN_ONLY_STATIONARY"]
STATIONARY_INTERVAL         = spawn_conf["STATIONARY_INTERVAL"]
STATIONARY_TOLERANCE        = spawn_conf["STATIONARY_TOLERANCE"]
SPAWN_INTERVAL_RANGE        = tuple(spawn_conf["SPAWN_INTERVAL_RANGE"])
#BALL_OPACITY                = spawn_conf["BALL_OPACITY"]
# BALL_OPACITY_LIST           =  spawn_conf(["BALL_OPACITY_LIST"])

MULTIPLE_BALLS              = spawn_conf["MULTIPLE_BALLS"]
MULTIPLE_BALLS_SPAWN_INTERVAL = tuple(spawn_conf["MULTIPLE_BALLS_SPAWN_INTERVAL"])
DEFAULT_LOG_MAX_BALLS       = spawn_conf["DEFAULT_LOG_MAX_BALLS"]
MAX_NUM_BALLS               = spawn_conf["MAX_NUM_BALLS"] 
_DEFAULT_LOG_MAX_BALLS      = 10  # fallback for logging if MAX_NUM_BALLS is None
# ================================================================
## obstruction parameters
SCREEN_EDGE_OBSTRUCTION     = obstruction_conf["SCREEN_EDGE_OBSTRUCTION"]
SPAWN_OBSTRUCTIONS          = obstruction_conf["SPAWN_OBSTRUCTIONS"]
OBSTRUCTION_WIDTH_CM        = obstruction_conf["OBSTRUCTION_WIDTH_CM"]
OBSTRUCTION_HEIGHT_CM       = obstruction_conf["OBSTRUCTION_HEIGHT_CM"] 
OBSTRUCTION_Y_DIST_RANGE    = tuple(obstruction_conf["OBSTRUCTION_Y_DIST_RANGE"])
OBSTRUCTION_Y_BUFFER        = obstruction_conf["OBSTRUCTION_Y_BUFFER"] 
OBSTRUCTION_REGEN_TIME      = obstruction_conf["OBSTRUCTION_REGEN_TIME"]
OBSTRUCTION_NUM             = obstruction_conf["OBSTRUCTION_NUM"]
OBSTRUCTION_MIN_CENTER_DIST_X = obstruction_conf["OBSTRUCTION_MIN_CENTER_DIST_X"]

REWARD_FUNCTION             = reward_conf["REWARD_FUNCTION"]
REWARD_TARGET               = reward_conf["REWARD_TARGET"] 
REWARD_UNIT                 = reward_conf["REWARD_UNIT"]
REWARD_TARGET_COEF_LIST     = reward_conf["REWARD_TARGET_COEF_LIST"] 

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

# ===================================================================
# Regions. 
regions = {
    'region1': {
        'deg_range': tuple(region1_conf["DEG_RANGE"]), 'gain': region1_conf["GAIN"], 
        'color': region1_conf["COLOR"], 'prob_spawn': region1_conf["PROB_SPAWN"],
        'spawn_function': region1_conf["SPAWN_FUNCTION"], 'linear_velocity': region1_conf["LINEAR_VELOCITY"],
        'patch_shape': region1_conf["PATCH_SHAPE"],'patch_fraction': region1_conf["PATCH_FRACTION"],
        'patch_size_cm': region1_conf["PATCH_SIZE_CM"], 'temporal_visibility': region1_conf["TEMPORAL_VISIBILITY"],
        'temporal_stimulus_visible': region1_conf["TEMPORAL_STIMULUS_VISIBLE"],
        'spatial_visibility': region1_conf["SPATIAL_VISIBILITY"], 'spatial_stimulus_visible': region1_conf["SPATIAL_STIMULUS_VISIBLE"]
    },
}

# ===================================================================
# Convenience derived params
SPACE_WIDTH_CM = SCREEN_WIDTH_CM * 2.0
TARGET_DT = 1.0 / FRAME_RATE
MAX_MOVE_PER_FRAME_CM = SCREEN_WIDTH_CM

half_screen_w = SCREEN_WIDTH_CM / 2.0
half_screen_h = SCREEN_HEIGHT_CM / 2.0

# Helper: pixels conversion used in texture prep & drawing
pixels_per_cm = SCREEN_PIX[0] / float(SCREEN_WIDTH_CM)            # horizontal
vertical_pixels_per_cm = SCREEN_PIX[1] / float(SCREEN_HEIGHT_CM)  # vertical

full_world_px = int(round(SPACE_WIDTH_CM * pixels_per_cm))
full_height_px = int(round(SCREEN_HEIGHT_CM * vertical_pixels_per_cm))  # == SCREEN_PIX[1]

# session folder uses date only (YYYYMMDD)
meta_root = os.path.join(home_path, "1-data/metadata")
os.makedirs(meta_root, exist_ok=True)
date_str = datetime.now().strftime("%Y%m%d")
session_folder_name = f"{mouse_name}_{date_str}"
session_dir = os.path.join(meta_root, session_folder_name)
os.makedirs(session_dir, exist_ok=True)
print(f"[INFO] Session metadata directory: {session_dir}", flush=True)

# # main sync log filename
current_time  = datetime.now().strftime("%H%M")
SYNC_LOG_FILENAME = os.path.join(session_dir, f"sync_log_pps_behav_{mouse_name}_{date_str}_{current_time}.csv")
ERROR_LOG_PATH = os.path.join(session_dir, 'error.txt')
EXP_CONFIG_FILENAME = os.path.join(session_dir, f"exp_config_pps_behav_{mouse_name}_{date_str}_{current_time}.json")
PARAMS_FILENAME = os.path.join(session_dir, f"exp_params_behav_{mouse_name}_{date_str}_{current_time}.mat")



reward_duration_dict   = dict(zip(REWARD_AMOUNT_LIST, REWARD_DURATION_MS_LIST))
REWARD_TARGET_LIST     = [i * REWARD_UNIT for i in REWARD_TARGET_COEF_LIST]
reward_target_dict     = dict(zip(SPAWN_GAUSS_CENTER_LIST, REWARD_TARGET_LIST))

config_to_save = {
    "metadata": {
        "mouse_name": mouse_name,
        "rig_name": RIG_NAME,
        "experiment_name": "pps_static_behavior",
        "timestamp": f"{date_str}_{current_time}",
    },
    "config": config_all
}

with open(EXP_CONFIG_FILENAME, "w") as f:
    json.dump(config_to_save, f, indent=2)

# =============================
# Define reward mapping function
# def reward_mapping(REWARD_FUNCTION):
#     match REWARD_FUNCTION:
#         case "single":
#             reward_openning_time = REWARD_TARGET
#         case "list":
#             reward_duration_dict   = dict(zip(REWARD_AMOUNT_LIST, REWARD_DURATION_MS_LIST))
#             REWARD_TARGET_LIST     = [i * REWARD_UNIT for i in REWARD_TARGET_COEF_LIST]
#             reward_target_dict     = dict(zip(SPAWN_GAUSS_CENTER_LIST, REWARD_TARGET_LIST))

#             reward_amount = reward_target_dict[ball['spawn_x']]
#             open_t = reward_duration_dict[reward_amount]
            
#             reward_openning_time    = reward_target_dict[""]
#     return reward_openning_time
# ==============================
# =========================
# Define sampler of conditions
# =========================
def sample_from_list(nTrial, condition_list):
    samples = np.random.choice(condition_list, size=nTrial)
    return samples
def sample_mixture_uniform(nTrial, low_high_bound, p_outlier, val_outlier):
    low_bound = low_high_bound[0]
    high_bound  = low_high_bound[1]

    is_outlier = np.random.rand(nTrial) <= p_outlier
    n_sample = (~is_outlier).sum()

    uni_samples = np.random.uniform(low_bound, high_bound, size = n_sample)

    samples = np.empty(nTrial)
    samples[is_outlier] = val_outlier
    samples[~is_outlier] = uni_samples

    return samples

def sample_mixture_exponential(nTrial, low_high_bound, lam, p_outlier, val_outlier):
    low_bound = low_high_bound[0]
    high_bound  = low_high_bound[1]

    is_outlier = np.random.rand(nTrial) <= p_outlier
    n_sample = (~is_outlier).sum()

    cdf_low = 1 - np.exp(-low_bound / lam)
    cdf_high = 1 - np.exp(-high_bound / lam)
    u = np.random.uniform(cdf_low, cdf_high, size=n_sample)
    exp_samples = -lam * np.log(1 - u)

    samples = np.empty(nTrial)
    samples[is_outlier] = val_outlier
    samples[~is_outlier] = exp_samples

    return samples

def sample_mixed_gaussion_clamped(nTrials, gaussian_center_list, gaussian_sigma):
    samples = np.empty(nTrials)

    return samples





class TrialConditionSampler:
    def __init__(self, chunk_size = 1500):
        self.chunk_size = chunk_size
        ##### 1. initial x
        self.spawn_distribution          = SPAWN_DISTRIBUTION
        self.spawn_gauss_center_list     = SPAWN_GAUSS_CENTER_LIST
        self.spawn_gauss_sigma_cm        = SPAWN_GAUSS_SIGMA_CM
        self.spawn_gauss_clamp_to_screen = SPAWN_GAUSS_CLAMP_TO_SCREEN
        self.spawn_uniform_range         = SPAWN_UNIFORM_RANGE
        self.spawn_x_chunk               = np.array([], dtype = float) 

        ##### 2. radius of ball
        self.ball_radius_cm_list         = CIRCLE_RADIUS_CM_LIST
        self.ball_radius_chunk           = np.array([], dtype=float)

        ##### 3. opacity (contrast) of ball
        self.ball_opacity_distibution    = BALL_OPACITY_DISTRIBUTION
        self.ball_opacity_list           = BALL_OPACITY_LIST
        self.ball_opacity_range          = BALL_OPACITY_RANGE
        self.ball_opacity_lambda         = BALL_OPACITY_LAMBDA
        self.high_opacity_portion        = HIGH_OPACITY_PORTION
        self.ball_opacity_chunk          = np.array([], dtype=float)

        ##### 4. falling speed of ball
        self.ball_speed_distribution     = BALL_FALL_SPEED_DISTRIBUTION
        self.ball_y_speed_list           = BALL_FALL_SPEED_CM_S_LIST
        self.ball_y_speed_range          = BALL_FALL_SPEED_CM_S_RANGE
        self.ball_y_speed_chunk          = np.array([], dtype=float)

        #### 5.  random walk of the ball
        self.ball_random_walk_distribution  = BALL_RANDOM_WALK_DISTRIBUTION
        self.ball_random_walk_bias_list     = BALL_RANDOM_WALK_VEL_BIAS_LIST
        self.ball_random_walk_std_list      = BALL_RANDOM_WALK_VEL_STD_LIST
        self.ball_random_walk_bias_scale    = BALL_RANDOM_WALK_VEL_BIAS_SCALE
        self.ball_random_walk_std_range           = BALL_RANDOM_WALK_VEL_STD_RANGE
        self.no_random_walk_portion         = NO_RANDOM_WALK_PORTION
        self.ball_random_walk_bias_chunk = np.array([], dtype=float)
        self.ball_random_walk_std_chunk  = np.array([], dtype=float)

        ##### 6. gain/jitter of the wheel
        self.wheel_gain_distribution     = WHEEL_GAIN_DISTRIBUTION
        self.wheel_gain_list             = WHEEL_GAIN_CM_PER_TICK_LIST
        self.wheel_gain_range            = WHEEL_GAIN_CM_PER_TICK_RANGE
        self.no_wheel_jitter_portion     = NO_JITTER_PORTION
        self.wheel_jitter_coef           = WHEEL_JITTER_COEF
        self.wheel_jitter_intercept      = WHEEL_JITTER_INTERCEPT

        self.wheel_gain_chunk   = np.array([], dtype=float)
        self.wheel_jitter_chunk = np.array([], dtype=float)
        
        
       
        self.idx = 0
        self._append_chunk()

    def _append_chunk(self):
    ##### 1. initial x
        match self.spawn_distribution:
            case "uniform":
                new_init_x = sample_mixture_uniform(self.chunk_size, self.spawn_uniform_range , 0, 0)
            case "gaussian":
                new_init_x = sample_mixed_gaussion_clamped(self.chunk_size, self.spawn_gauss_center_list, self.spawn_gauss_sigma_cm)
            case "choice":
                new_init_x = sample_from_list(self.chunk_size,  self.spawn_gauss_center_list )
        
        
        ##### 2. radius of ball 
        new_ball_radius   = sample_from_list(self.chunk_size, self.ball_radius_cm_list)
    
        
        ##### 3. opacity (contrast) of ball
        match self.ball_opacity_distibution:
            case "choice":
                new_ball_opacity = sample_from_list(self.chunk_size, self.ball_opacity_list)
            case "sample":
                new_ball_opacity = sample_mixture_exponential(self.chunk_size, self.ball_opacity_range,
                                    self.ball_opacity_lambda, self.high_opacity_portion, 1)
        

        ##### 4. falling speed of ball
        match self.ball_speed_distribution:
            case "choice":
                new_ball_y_speed = sample_from_list(self.chunk_size, self.ball_y_speed_list)
            case "sample":
                new_ball_y_speed = sample_mixture_uniform(self.chunk_size, self.ball_y_speed_range,
                                                0, 0)
        

        #### 5.  random walk of the ball
        match self.ball_random_walk_distribution:
            case "choice":
                new_random_walk_bias    = sample_from_list(self.chunk_size, self.ball_random_walk_bias_list)
                new_random_walk_std     = sample_from_list(self.chunk_size, self.ball_random_walk_std_list)
            case "sample":
                new_random_walk_bias = np.random.normal(loc = 0.0, scale = self.ball_random_walk_bias_scale, size = self.chunk_size)

                new_random_walk_std  = sample_mixture_uniform(self.chunk_size, self.ball_random_walk_std_range,
                                                    0, 0)
                
        is_no_random_walk = np.random.rand(self.chunk_size) <= self.no_random_walk_portion

        new_random_walk_bias[is_no_random_walk] = 0.0
        new_random_walk_std[is_no_random_walk]  = 0.0

    

        ##### 6. gain/jitter of the wheel
        match self.wheel_gain_distribution:
            case "choice":
                new_wheel_gain = sample_from_list(self.chunk_size, self.wheel_gain_list)
            case "sample":
                new_wheel_gain = sample_mixture_uniform(self.chunk_size, self.wheel_gain_range,
                                                0, 0)
        new_wheel_jitter = new_wheel_gain * self.wheel_jitter_coef + self.wheel_jitter_intercept
        is_no_jitter = np.random.rand(self.chunk_size) <= self.no_wheel_jitter_portion
        
        new_wheel_jitter[is_no_jitter] = 0.0

        

    
        ##### 7. make the random walk bias only away from the reward zone 
        new_random_walk_bias_new = np.abs(new_random_walk_bias) * np.sign(new_init_x)



        self.spawn_x_chunk      = np.concatenate([self.spawn_x_chunk, new_init_x])
        self.ball_radius_chunk  = np.concatenate([self.ball_radius_chunk, new_ball_radius]) 
        self.ball_opacity_chunk = np.concatenate([self.ball_opacity_chunk, new_ball_opacity])
        self.ball_y_speed_chunk = np.concatenate([self.ball_y_speed_chunk, new_ball_y_speed])
        self.ball_random_walk_bias_chunk    = np.concatenate([self.ball_random_walk_bias_chunk, new_random_walk_bias_new])
        self.ball_random_walk_std_chunk     = np.concatenate([self.ball_random_walk_std_chunk , new_random_walk_std]) 
        self.wheel_gain_chunk = np.concatenate([self.wheel_gain_chunk, new_wheel_gain])
        self.wheel_jitter_chunk = np.concatenate([self.wheel_jitter_chunk, new_wheel_jitter]) 

       

    def next(self):
        if self.idx >= len(self.spawn_x_chunk):
            self._append_chunk()

        out_params = {
            "spawn_x": self.spawn_x_chunk[self.idx],
            "ball_radius": self.ball_radius_chunk[self.idx],
            "ball_opacity": self.ball_opacity_chunk[self.idx],
            "ball_speed": self.ball_y_speed_chunk[self.idx],
            "ball_random_walk_bias": self.ball_random_walk_bias_chunk[self.idx],
            "ball_random_walk_std": self.ball_random_walk_std_chunk[self.idx],
            "wheel_gain": self.wheel_gain_chunk[self.idx],
            "wheel_jitter": self.wheel_jitter_chunk[self.idx],
            "trial_idx": self.idx,
        }
        self.idx += 1
        return out_params




def save_trial_sampler_to_mat(sampler, filename):
    def to_numpy(x):
        """Convert Python objects to MATLAB-friendly format"""
        if isinstance(x, np.ndarray):
            return x
        elif isinstance(x, (list, tuple)):
            try:
                return np.array(x)
            except:
                return np.array(x, dtype=object)
        elif isinstance(x, (int, float, bool)):
            return np.array([[x]])  # MATLAB likes 2D scalars
        elif isinstance(x, str):
            return x
        else:
            return str(x)  # fallback (for safety)

    data = {}

    # Loop through all attributes of the sampler
    for key, value in sampler.__dict__.items():
        try:
            data[key] = to_numpy(value)
        except Exception as e:
            print(f"[WARNING] Could not convert {key}: {e}")
            data[key] = str(value)

    # Save to .mat
    savemat(filename, data)
    print(f"[INFO] Saved sampler to {filename}")
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
                    units='cm', color=(-1.0, -1.0, -1.0), waitBlanking=True, screen=SCREEN_ID)

#### By Shizhao Liu": hide mouse
win.mouseVisible = False
mouse = event.Mouse()
mouse.setPos((0,0))

# circle = visual.Circle(win, radius=CIRCLE_RADIUS_CM, fillColor=(1.0, 1.0, 1.0),
#                        lineColor=None, edges=64, pos=(0.0, 0.0))

circle = visual.Circle(win, fillColor=(1.0, 1.0, 1.0),
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

# ============================
# Warmup: textures & prep
# ============================
print(f"[INFO] Warmup for {WARMUP_S:.1f}s starting (parameters and textures will be generated now)...", flush=True)
warmup_start_ts = perf_counter()

trial_param_sampler = TrialConditionSampler()
save_trial_sampler_to_mat(trial_param_sampler, PARAMS_FILENAME)


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

def spawn_ball_ts(now_ts, win_start, window_intervals, trial_params):
    global last_spawn_ts, next_spawn_time, global_spawn_id, sync_start_ts, last_spawn_region, win

    spawn_interval_s = random.uniform(*SPAWN_INTERVAL_RANGE)
    # if SPAWN_DISTRIBUTION == "gaussian":
    #     spawn_center_cm = random.choice(SPAWN_GAUSS_CENTER_LIST)
    #     spawn_world = general_spawn_gaussian_on_screen_center(
    #         win_start=win_start,
    #         screen_w=SCREEN_WIDTH_CM,
    #         space_w = SPACE_WIDTH_CM,
    #         spawn_center_cm = spawn_center_cm,
    #         sigma_cm=SPAWN_GAUSS_SIGMA_CM,
    #         clamp_to_screen=SPAWN_GAUSS_CLAMP_TO_SCREEN,
    #         max_resamples=SPAWN_GAUSS_RESAMPLE_MAX
    #     )
    # else:
    #     spawn_world = general_spawn_uniform_on_screen(win_start, window_intervals, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)

    spawn_center_cm     = trial_params["spawn_x"]
    screen_w            = SCREEN_WIDTH_CM
    space_w             = SPACE_WIDTH_CM
    center_world        = wrap_pos(win_start + (screen_w / 2.0), space_w)

    spawn_world         = wrap_pos(center_world + spawn_center_cm, space_w)
    

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
    # By shizhao liu 03/30/2026, randomly choose a radius from a list
    ball_radius = trial_params["ball_radius"]
    ball_opacity = trial_params["ball_opacity"]
    ball_y_speed = trial_params["ball_speed"]
    ball_random_walk_mean   = trial_params["ball_random_walk_bias"]
    ball_random_walk_std    = trial_params["ball_random_walk_std"]
    ball = {
        'world_x_cm': float(spawn_world) % SPACE_WIDTH_CM,
        'y_cm': half_screen_h - ball_radius - SPAWN_Y_OFFSET, # By Shizhao Liu 03/06/2026. Add an offset so that the ball can start closer to the animal
        'spawn_ts': now_ts,
        'spawn_region': last_spawn_region,
        'spawn_id': global_spawn_id,
        'radius': ball_radius,
        'init_x': spawn_center_cm,
        'opacity': ball_opacity,
        'y_speed': ball_y_speed,
        'rand_walk_mean': ball_random_walk_mean,
        'rand_walk_std': ball_random_walk_std
    }
    balls.append(ball)

    if sync_start_ts is None:
        sync_start_ts = perf_counter()

    last_spawn_ts = now_ts
    next_spawn_time = None
    if DO_EPHYS:
        #### send pulse when this ball apprears on the screen
        win.callOnFlip(send_trial_pulse_hw_nonblocking)
    return ball

def initial_spawn(mouse_center_cm, trial_params):
    win_start, win_end = window_start_end(mouse_center_cm, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
    window_intervals = [(win_start, win_start + SCREEN_WIDTH_CM)] if (win_start + SCREEN_WIDTH_CM <= SPACE_WIDTH_CM) else [(win_start, SPACE_WIDTH_CM), (0.0, (win_start + SCREEN_WIDTH_CM) - SPACE_WIDTH_CM)]
    spawn_ball_ts(perf_counter(), win_start, window_intervals, trial_params)

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
if DO_EPHYS:
    header = ['prbs_val',
        'frame_idx', 't_global_s', 'window_deg_range', 'mouse_center_deg',
        'current_region', 'linear_velocity_cm_s', 'reward_state', 'reward_amount',
        'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'base_delta_cm', 'delta_cm', 'gain_applied',
    ]
else:
    header = [
        'frame_idx', 't_global_s', 'window_deg_range', 'mouse_center_deg',
        'current_region', 'linear_velocity_cm_s', 'reward_state', 'reward_amount',
        'enc_ticks', 'delta_ticks_raw', 'delta_ticks_corrected', 'base_delta_cm', 'delta_cm', 'gain_applied',
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
mouse_center_cm = SPACE_WIDTH_CM / 2.0
mouse_center_cm = wrap_pos(mouse_center_cm, SPACE_WIDTH_CM)
balls = []
next_spawn_time = 0.0
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


last_obstruction_regen_ts = None
#### These two variables are for detecting stationary intervals
delta_tick_history = []
running_tick_sum = 0.0

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
    flicker_start_ts = perf_counter() 
    sync_start_ts = perf_counter()
    last_obstruction_regen_ts = experiment_start_ts if SPAWN_OBSTRUCTIONS else None
    if SPAWN_OBSTRUCTIONS:
        generate_obstructions()

    trial_params = trial_param_sampler.next()
 

    new_ball = True
    #initial_spawn(mouse_center_cm, trial_params)

    while True:
        if new_ball == True:
            trial_params = trial_param_sampler.next()
            new_ball = False
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
      
        wheel_gain = trial_params["wheel_gain"]
        wheel_jitter = trial_params["wheel_jitter"]
        base_delta_cm = delta_ticks * random.gauss(wheel_gain, wheel_jitter)

        #base_delta_cm += 

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
        scenery_speed_cm_s = float(v_center) if (v_center is not None) else BALL_FALL_SPEED_CM_S_LIST[0]

        scenery_offset_cm = (scenery_offset_cm + scenery_speed_cm_s * dt_clamped) % SCREEN_HEIGHT_CM


        ##### By Shizhao Liu 02/26/26
        ### Detect if wheel is stationary. O
        ### If SPAWN_ONLY_STATIONARY is true, only generate balls when the wheel is relatively stationary
        wheel_is_stationary = False # reset to false unless the below condition is met
        if (perf_counter() - experiment_start_ts) >  (STATIONARY_INTERVAL / 1000):
            running_tick_sum -= delta_tick_history[0]
            delta_tick_history.pop(0)
        delta_tick_history.append(abs(delta_ticks))
        running_tick_sum += abs(delta_ticks)

        if running_tick_sum < STATIONARY_TOLERANCE and (perf_counter() - experiment_start_ts) > (STATIONARY_INTERVAL / 1000): ### stationary enough in the last time window
            wheel_is_stationary = True

        if next_spawn_time is not None and ts >= next_spawn_time:
            # spawn_ball_ts(ts, win_start, window_intervals)
            if (not SPAWN_ONLY_STATIONARY) | (SPAWN_ONLY_STATIONARY and wheel_is_stationary):
                spawn_ball_ts(ts, win_start, window_intervals, trial_params)
                #new_ball = True
            

 
        for obs in obstructions:
            obs['hit'] = 0

        remove_indices = []
        reward_sent_this_frame = False
        reward_amount = 0.0
        visible_ball_flags = []

        # ===========================================
        # Detect if balls hit the bottom of the screen edge
        # Is so, take appropriate actions
        # ===========================================
        for bi, ball in enumerate(balls):
            #ball['y_cm'] -= scenery_speed_cm_s * dt_clamped
            ball['y_cm'] -= ball['y_speed'] * dt_clamped
            #### random walk of the ball
            random_walk_vel = random.gauss(ball['rand_walk_mean'],ball['rand_walk_std'] )
            ball['world_x_cm'] += random_walk_vel * dt_clamped
           # bottom_threshold = -half_screen_h + CIRCLE_RADIUS_CM
            bottom_threshold = -half_screen_h + ball['radius']

            horiz_in = is_in_window(ball['world_x_cm'], win_start, win_end, SPACE_WIDTH_CM)

            collided_with_obstruction = False
            if SPAWN_OBSTRUCTIONS and horiz_in and obstructions:
                drawn_x = world_to_screen_x(ball['world_x_cm'], win_start, SCREEN_WIDTH_CM, SPACE_WIDTH_CM)
                ball_bl_x = drawn_x + half_screen_w
                ball_bl_y = ball['y_cm'] + half_screen_h

                for oi, obs in enumerate(obstructions):
                    # if circle_rect_collides(ball_bl_x, ball_bl_y, CIRCLE_RADIUS_CM,
                    #                         obs['x'], obs['y'], obs['w'], obs['h']):
                    if circle_rect_collides(ball_bl_x, ball_bl_y, ball['radius'],
                                             obs['x'], obs['y'], obs['w'], obs['h']):
                        obs['hit'] = 1
                        collided_with_obstruction = True
                        break
            #   Added by Shizhao Liu: make balls disappear if they hit the edge of screen
            collided_with_screen_edge = False
            if SCREEN_EDGE_OBSTRUCTION:
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
                    #tolerance = SUCCESS_EDGE_TOLERANCE_MULT * CIRCLE_RADIUS_CM
                    ### By shizhao liu 03/30/2026, change the way to decide whether balls are in reward zone
                    #if 'SUCCESS_EDGE_TOLERANCE_RANGE' in globals():
                    is_in_zone = drawn_x >= SUCCESS_EDGE_TOLERANCE_RANGE[0] and drawn_x <= SUCCESS_EDGE_TOLERANCE_RANGE[1]
                    # elif 'SUCCESS_EDGE_TOLERANCE_MULT' in globals():
                    #     tolerance = SUCCESS_EDGE_TOLERANCE_MULT * ball['radius']
                    #     is_in_zone  = abs(drawn_x) <= tolerance
                    # else:
                    #     raise ValueError("Reward zone not specified")

                    if is_in_zone and (not reward_sent_this_frame):
                        match REWARD_FUNCTION:
                            case "list":
                                reward_amount = reward_target_dict[ball['init_x']]
                              
                            case "single":
                                reward_amount = REWARD_TARGET
                            
                        open_t = reward_duration_dict[reward_amount]

                        
                        if send_reward(open_t):
                            
                            reward_sent_this_frame = True
                            reward_active_until = perf_counter() + (open_t / 1000.0)
                            reward_state_pulse_pending = True
                            # if DO_EPHYS:
                            #     send_reward_pulse_hw_nonblocking()

                remove_indices.append(bi)
                if not MULTIPLE_BALLS:
                    next_spawn_time = ts + random.uniform(*SPAWN_INTERVAL_RANGE)

            visible_ball_flags.append(int(horiz_in))

        ##### By Shizhao Liu 02/26/26: I want to move this "pop" after logging so that the last state of a ball is saved
        # for bi in sorted(remove_indices, reverse=True):
        #     balls.pop(bi)

        # =====================================
        # Draw
        # ========================================
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
                #circle.opacity = float(max(0.0, min(1.0, BALL_OPACITY)))
                circle.opacity = float(max(0.0, min(1.0, ball['opacity'])))
                # By Shizhao Liu 03/30/2026, adjustable radius
                circle.radius = ball['radius']
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

        

        if reward_state_pulse_pending:
            reward_state_now = 1
            reward_state_pulse_pending = False
        else:
            reward_state_now = 1 if (perf_counter() < reward_active_until) else 0

        enc_cols = [enc_ticks, delta_ticks_raw, delta_ticks, f"{base_delta_cm:.4f}", f"{delta_cm:.4f}"]
        gain_col = [f"{gain_applied:.4f}", f"{wheel_gain:.4f}", f"{wheel_jitter:.4f}"]

        slot_cells = [''] * _log_max_balls
        if len(balls) > 0:
            b = balls[-1]
            sid = int(b.get('spawn_id', 0))
            ball_deg = cm_to_deg(b['world_x_cm'])
            rel_deg = (ball_deg - cm_to_deg(mouse_center_cm)) % 360.0
            ball_bl_y = b['y_cm'] + half_screen_h
            ball_radius = b['radius']
            ball_opacity = b['opacity']
            ball_y_speed = b['y_speed']
            ball_walk_mean = b['rand_walk_mean']
            ball_walk_std   = b['rand_walk_std']
            slot_cells[0] = f"{sid}|{rel_deg:.1f}|{ball_bl_y:.3f}|{ball_radius:.3f}|{ball_opacity:.3f}|{ball_y_speed:.3f}|{ball_walk_mean:.3f}|{ball_walk_std:.3f}"

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
        t_global = f"{(perf_counter() - sync_start_ts):.6f}" if sync_start_ts is not None else ''
        if DO_EPHYS:
            with prbs_shared.get_lock():
                prbs_val = int(prbs_shared.value)
                row = [
                    prbs_val,
                    frame_idx,
                    t_global,
                    window_deg_range,
                    f"{cm_to_deg(mouse_center_cm):.2f}",
                    (current_region_name if current_region_name is not None else ''),
                    f"{scenery_speed_cm_s:.3f}",
                    reward_state_now,
                    reward_amount
                ]
        else:
            row = [
                frame_idx,
                t_global,
                window_deg_range,
                f"{cm_to_deg(mouse_center_cm):.2f}",
                (current_region_name if current_region_name is not None else ''),
                f"{scenery_speed_cm_s:.3f}",
                reward_state_now,
                reward_amount
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
            new_ball = True

        
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
    #if has_amount:
    print(f"Total reward amount: {total_reward}")
    print(f"Number of rewarded trials: {n_rewarded_trials}")
    # elseif len()
    #     print(f"Total reward amount: {n_rewarded_trials} * {REWARD_TARGET} = {n_rewarded_trials * REWARD_TARGET}")

    # ====== Save the configuration file
   # save_config(exp_config, EXP_CONFIG_FILENAME)
    win.close()
    core.quit()
    print("Clean exit.", flush=True)
