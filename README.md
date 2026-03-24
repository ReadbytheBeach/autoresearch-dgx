# autoresearch-dgx

🗂️ Directory Structure

  /home/xj/Desktop/xj_code/autoresearch/
  ├── README.md              # Project documentation
  ├── program.md             # Agent instructions for AI experimentation
  ├── train.py               # Original training script (full version)
  ├── train_light.py         # 🚀 Light version for DGX Spark (ARM64)
  ├── prepare.py             # Data preparation (full)
  ├── prepare_light.py       # Data preparation (light mode)
  ├── prepare_pip.sh         # Setup using pip + Tsinghua mirror
  ├── run_light.sh           # Main control script for DGX Spark
  ├── auto_train.sh          # Cron automation script
  ├── pyproject.toml         # Dependencies
  ├── uv.lock                # UV lock file
  ├── uv.toml                # UV config
  ├── results.tsv            # 📊 Experiment results log
  ├── progress.png           # Teaser image
  ├── logs/                  # 📁 Training logs (16 log files, ~2.3MB)
  │   ├── cron.log           # Main cron log with all runs
  │   └── auto_train_*.log   # Individual run logs
  ├── .venv/                 # UV virtual environment
  └── .venv_pip/             # Pip virtual environment (active one)




more light then Andrej Kaparthy's original version, due to he is running on H-100
Parameter          Value               Original
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   MAX_SEQ_LEN        512                 2048
   DEPTH (n_layer)    4                   8
   TOTAL_BATCH_SIZE   65,536              524,288
   WINDOW_PATTERN     L (local)           SSSL
   GPU                DGX Spark (ARM64)   H100





 🚀 How to Restart AutoResearch

  Since there's no crontab currently set, you have a few options:

  Option 1: Setup Crontab (Recommended for automation)

  # Edit crontab
  crontab -e

  # Add this line to run every 30 minutes:
  */30 * * * * /home/xj/Desktop/xj_code/autoresearch/auto_train.sh >> /home/xj/Desktop/xj_code/autoresearch/logs/cron.log 2
  >&1

  Option 2: Manual Run (Right now)

  cd /home/xj/Desktop/xj_code/autoresearch
  ./run_light.sh train

  Option 3: Full Experiment Loop (with AI agent)

  cd /home/xj/Desktop/xj_code/autoresearch
  ./run_light.sh experiment  # Creates branch and sets up for AI experimentation


