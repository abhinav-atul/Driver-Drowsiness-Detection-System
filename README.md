# 🚗 Driver Drowsiness Detection System

A real-time driver drowsiness detection system that uses a **1D CNN model** trained on facial landmark data to classify alert vs. drowsy states. Combines deep learning inference with Eye Aspect Ratio (EAR) analysis for robust, low-latency detection — with GPU acceleration support and a professional audio alert system.

---

## 📁 Project Structure

```
Driver-Drowsiness-Detection-System/
│
├── drowsiness_detector_v3.py   # Main real-time detection script
├── fineTune.py                 # 4-phase CNN training pipeline
├── preprocess_dataset.py       # Facial landmark extraction & dataset preprocessing
├── split.py                    # Train/test dataset split utility
├── requirements.txt            # Python dependencies
```

---

## 🧠 How It Works

### Detection Pipeline

1. **Webcam Feed** → each frame is flipped (mirrored) for natural interaction
2. **Face Detection** → dlib's frontal face detector runs on a scaled-down (75%) frame for speed
3. **Landmark Extraction** → dlib's 68-point shape predictor extracts facial landmarks at full resolution
4. **Dual Detection Logic**:
   - **CNN Model** (`drowsiness_cnn_final_1_model.h5`): runs every 2 frames on normalized 136-dim landmark vectors → outputs drowsiness probability
   - **Eye Aspect Ratio (EAR)**: monitors eyes independently; triggers if EAR < `0.25` for 12+ consecutive frames
5. **Alert System** → audio alert fires if either CNN confidence > `0.55` or eyes stay closed too long, with a 3-second cooldown between alerts

### Model Architecture (CNN on Landmarks)

The model operates on a `(136, 1)` shaped input — 68 facial landmarks × 2 coordinates (x, y), normalized per face.

```
Input: (136, 1)
→ Conv1D(64)  + ELU + BN + MaxPool + Dropout
→ Conv1D(128) + ELU + BN + MaxPool + Dropout
→ Conv1D(256) + ELU + BN + MaxPool + Dropout
→ Conv1D(512) + ELU + BN + MaxPool + Dropout
→ Flatten
→ Dense(256) + Dense(128)
→ Output: Softmax(2)  [alert, drowsy]
```

L2 regularization (`0.001`) is applied across all conv and dense layers. The model achieves **84.9% accuracy** on the validation set.

---

## 🏋️ Training Pipeline

Training is handled by `fineTune.py` using a **4-phase progressive schedule**:

| Phase | Name               | LR      | Batch | Epochs | Dropout |
|-------|--------------------|---------|-------|--------|---------|
| 1     | Initial Learning   | 0.001   | 64    | 18     | 0.4     |
| 2     | Feature Refinement | 0.0003  | 128   | 12     | 0.3     |
| 3     | Fine Tuning        | 0.0001  | 256   | 8      | 0.2     |
| 4     | Final Optimization | 0.00001 | 512   | 4      | 0.1     |

Between phases, weights are transferred to a newly instantiated model with updated dropout rates. EarlyStopping (patience=7) and ModelCheckpoint are used each phase.

---

## 🗂️ Data Preprocessing

`preprocess_dataset.py` handles the full preprocessing pipeline:

- Reads `train.txt` / `test.txt` (image path + label per line)
- Extracts 68-point facial landmarks using dlib → 136 raw features per sample
- Applies **per-face min-max normalization** on x and y coordinates separately
- Saves output as compressed `.npz` files (`train_data.npz`, `test_data.npz`)
- Logs failed samples and processing statistics as JSON

`split.py` generates `train.txt` and `test.txt` from a dataset folder with two subfolders:
```
train_data/
├── drowsy/
└── notdrowsy/
```
An 80/20 stratified split is used.

---

## ⚡ GPU Acceleration

The detector automatically detects NVIDIA GPUs via TensorFlow:
- Enables memory growth to avoid full VRAM allocation
- Runs CNN inference on `/GPU:0` with explicit device placement
- Falls back to CPU seamlessly if no GPU is found
- Performs 3 GPU warmup passes on startup for stable inference timing

---

## 🔊 Audio Alert System

`AudioManager` (in `drowsiness_detector_v3.py`) generates all sounds **programmatically** using NumPy and pygame — no audio files needed:

| Alert | Sound | Trigger |
|-------|-------|---------|
| Drowsiness | Urgent 3-tone alarm (800→1000→1200 Hz, 1.5s) | CNN prob > threshold or eyes closed |
| Face Lost | Double beep (1500 Hz, 0.6s) | Face missing for 30+ frames |
| Config Done | Pleasant C-E-G chime (0.8s) | Calibration phase complete |

Audio runs in a dedicated daemon thread with a priority queue (max size 5). Drowsy alerts clear the queue to ensure immediate playback.

---

## 🎮 Runtime Controls

| Key | Action |
|-----|--------|
| `D` | Toggle facial landmark overlay |
| `A` | Toggle model accuracy display |
| `P` | Toggle FPS / performance monitor |
| `C` | Start manual calibration phase (8s) |
| `R` | Reset session statistics |
| `T` | Toggle detailed session stats |
| `S` | Save screenshot as JPEG |
| `Q` | Quit |

---

## 🛠️ Installation & Setup

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

> **Note:** `dlib` requires CMake and a C++ compiler. On Windows, install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) before installing dlib.

### 2. Download required model files

Place the following files in your project directory (or update paths in the scripts):

- `shape_predictor_68_face_landmarks.dat` — [dlib model zoo](http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2)
- `drowsiness_cnn_final_1_model.h5` — trained CNN model (train using `fineTune.py`)

### 3. Prepare dataset (for training)

```bash
# Organize images into:
# train_data/drowsy/  and  train_data/notdrowsy/

python split.py                  # Creates train.txt and test.txt
python preprocess_dataset.py     # Extracts landmarks, saves .npz files
python fineTune.py               # Trains 4-phase CNN, saves model
```

### 4. Run the detector

```bash
python drowsiness_detector_v3.py
```

**Optional flags:**

```bash
python drowsiness_detector_v3.py --manual-config   # Start with 8s calibration phase
python drowsiness_detector_v3.py --camera-index 1  # Use a different webcam
python drowsiness_detector_v3.py --no-audio        # Disable audio alerts
python drowsiness_detector_v3.py --force-cpu       # Disable GPU, use CPU only
```

---

## 📦 Dependencies

| Package | Version |
|---------|---------|
| opencv-python | ≥ 4.7.0 |
| dlib | ≥ 19.24.0 |
| tensorflow | ≥ 2.10.0 |
| numpy | ≥ 1.25.0 |
| pygame | latest |
| scikit-learn | ≥ 1.2.0 |
| matplotlib | ≥ 3.6.0 |
| seaborn | ≥ 0.11.0 |
| pandas | ≥ 1.5.0 |

---

## 📊 Detection Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `DROWSINESS_THRESHOLD` | 0.55 | CNN probability above which drowsiness is flagged |
| `EYE_AR_THRESHOLD` | 0.25 | EAR below which eyes are considered closed |
| `EYE_AR_CONSEC_FRAMES` | 12 | Consecutive closed-eye frames before alert |
| `CONSECUTIVE_FRAMES` | 3 | Consecutive drowsy frames to trigger alert |
| `SMOOTHING_WINDOW` | 5 | Rolling average window for prediction smoothing |
| `ALERT_COOLDOWN` | 3s | Minimum time between consecutive alerts |
| `CNN_PREDICTION_INTERVAL` | 2 | Run CNN every N frames |
| `FACE_DETECTION_SCALE` | 0.75 | Scale factor for faster face detection |
