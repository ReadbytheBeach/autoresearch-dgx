#!/bin/bash
# AutoResearch Light Mode for DGX Spark (GB10)
# Usage: ./run_light.sh [prepare|train|experiment|init|status|push]

set -e

LIGHT_MODE=1
REPO_URL="https://github.com/ReadbytheBeach/autoresearch-dgx.git"

case "${1:-}" in
  prepare)
    echo "=== AutoResearch Light: Data Preparation ==="
    echo "MAX_SEQ_LEN: 512, Using light config..."
    uv run prepare_light.py --num-shards 5
    ;;
  
  prepare-pip)
    echo "=== AutoResearch Light: Data Preparation (using pip + mirror) ==="
    echo "Using Tsinghua mirror for faster download on ARM64..."
    ./prepare_pip.sh
    ;;
  
  train)
    echo "=== AutoResearch Light: Single Training Run ==="
    echo "Config: DEPTH=4, SEQ_LEN=512, BATCH_SIZE=2^16"
    uv run train_light.py
    ;;
  
  experiment)
    echo "=== AutoResearch Light: Start Experiment Loop ==="
    echo "Create branch: autoresearch/light-$(date +%m%d)"
    git checkout -b "autoresearch/light-$(date +%m%d)" 2>/dev/null || git checkout "autoresearch/light-$(date +%m%d)"
    
    # Initialize results.tsv
    if [ ! -f results.tsv ]; then
      echo -e "commit\tval_bpb\tmemory_gb\tstatus\tdescription" > results.tsv
    fi
    
    echo ""
    echo "Setup complete! Now start your AI Agent with:"
    echo "  'Read program.md and start experimenting with train_light.py'"
    echo ""
    echo "To run manually: uv run train_light.py"
    echo ""
    echo "Current branch: $(git branch --show-current)"
    ;;
  
  init)
    echo "=== Initialize Git Repository for GitHub ==="
    echo "Target: $REPO_URL"
    echo ""
    
    # Check if git is initialized
    if [ ! -d .git ]; then
      echo "[1/4] Initializing git repository..."
      git init
    else
      echo "[1/4] Git repository already initialized"
    fi
    
    # Configure git (if not already set)
    if ! git config user.name >/dev/null 2>&1; then
      echo "[2/4] Configuring git user..."
      git config user.name "DGX Spark User"
      git config user.email "user@dgx-spark.local"
    else
      echo "[2/4] Git user already configured: $(git config user.name)"
    fi
    
    # Add all files
    echo "[3/4] Adding files to git..."
    git add run_light.sh train_light.py prepare_light.py \
            DGX_SPARK_GUIDE.md RUN_LIGHT_COMMANDS_GUIDE.md \
            pyproject.toml README.md program.md 2>/dev/null || true
    
    # Create initial commit
    if git diff --cached --quiet; then
      echo "[4/4] No changes to commit"
    else
      echo "[4/4] Creating initial commit..."
      git commit -m "Initial commit: AutoResearch light mode for DGX Spark (GB10)"
      echo ""
      echo "✅ Local repository initialized!"
    fi
    
    echo ""
    echo "Next steps to push to GitHub:"
    echo ""
    echo "  1. Create a new repository on GitHub:"
    echo "     https://github.com/new"
    echo "     Repository name: autoresearch-dgx"
    echo "     (Make it Public or Private as you prefer)"
    echo ""
    echo "  2. Set up GitHub access using ONE of these methods:"
    echo ""
    echo "     Method A - Personal Access Token (Recommended):"
    echo "     a) Go to https://github.com/settings/tokens"
    echo "     b) Generate new token (classic)"
    echo "     c) Select 'repo' scope"
    echo "     d) Copy the token (ghp_xxxxxxxx)"
    echo "     e) Run: git remote add origin https://<TOKEN>@github.com/ReadbytheBeach/autoresearch-dgx.git"
    echo ""
    echo "     Method B - SSH Key (More secure):"
    echo "     a) Generate key: ssh-keygen -t ed25519 -C 'your_email@example.com'"
    echo "     b) Add to GitHub: https://github.com/settings/keys"
    echo "     c) Run: git remote add origin git@github.com:ReadbytheBeach/autoresearch-dgx.git"
    echo ""
    echo "  3. Push to GitHub:"
    echo "     git push -u origin master"
    echo ""
    ;;
  
  status)
    echo "=== Git Repository Status ==="
    echo ""
    
    if [ ! -d .git ]; then
      echo "❌ Not a git repository yet"
      echo "Run: ./run_light.sh init"
      exit 1
    fi
    
    echo "Current branch: $(git branch --show-current)"
    echo ""
    
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null || echo "  No commits yet"
    echo ""
    
    echo "Experiment branches:"
    git branch -a | grep "autoresearch" 2>/dev/null || echo "  No experiment branches"
    echo ""
    
    if [ -f results.tsv ]; then
      echo "Experiment results:"
      wc -l results.tsv | awk '{print "  Total experiments: " $1-1}'
      echo "  Last 3 experiments:"
      tail -3 results.tsv | head -2 | nl
    else
      echo "No results.tsv found"
    fi
    echo ""
    
    echo "Git remotes:"
    git remote -v 2>/dev/null || echo "  No remotes configured"
    ;;
  
  push)
    echo "=== Push Experiment Branch to GitHub ==="
    echo ""
    
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    echo ""
    
    # Check if remote exists
    if ! git remote >/dev/null 2>&1 || [ -z "$(git remote)" ]; then
      echo "❌ No remote configured"
      echo "Run: ./run_light.sh init"
      exit 1
    fi
    
    echo "Pushing branch '$CURRENT_BRANCH' to GitHub..."
    git push -u origin "$CURRENT_BRANCH"
    
    echo ""
    echo "✅ Pushed to: https://github.com/ReadbytheBeach/autoresearch-dgx/tree/$CURRENT_BRANCH"
    ;;
  
  backup)
    echo "=== Backup All Experiment Branches ==="
    echo ""
    
    # Push all local branches
    for branch in $(git branch | grep "autoresearch" | sed 's/*//'); do
      echo "Pushing branch: $branch"
      git push -u origin "$branch" 2>/dev/null || echo "  (skipped)"
    done
    
    echo ""
    echo "✅ All experiment branches backed up!"
    ;;
  
  *)
    echo "AutoResearch Light Mode for DGX Spark"
    echo ""
    echo "Usage: ./run_light.sh [command]"
    echo ""
    echo "Main Commands:"
    echo "  prepare    - Download data and train tokenizer (light mode, use uv)"
    echo "  prepare-pip- Download data using pip + mirror (if uv fails)"
    echo "  train      - Run single training experiment (~5 min)"
    echo "  experiment - Setup git branch for autonomous research"
    echo ""
    echo "Git Commands:"
    echo "  init       - Initialize git repository for GitHub"
    echo "  status     - Show git status and experiment summary"
    echo "  push       - Push current experiment branch to GitHub"
    echo "  backup     - Push all experiment branches to GitHub"
    echo ""
    echo "Light Mode Config:"
    echo "  MAX_SEQ_LEN:     512  (was 2048)"
    echo "  DEPTH:           4    (was 8)"
    echo "  TOTAL_BATCH:     65K  (was 524K)"
    echo "  WINDOW_PATTERN:  L    (was SSSL)"
    echo ""
    echo "GitHub: $REPO_URL"
    echo ""
    ;;
esac
