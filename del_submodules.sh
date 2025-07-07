#!/bin/bash

# Ensure we're in the root of the Git repository
# If not, exit or handle appropriately
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a Git repository."
    exit 1
fi

# Check if .gitmodules exists
if [ ! -f .gitmodules ]; then
    echo "No .gitmodules file found. No submodules to remove."
    exit 0
fi

# Get a list of all submodule paths
# This extracts the 'path' value from each submodule section
SUBMODULE_PATHS=$(git config -f .gitmodules --get-regexp submodule\..*\.path | awk '{print $2}')

if [ -z "$SUBMODULE_PATHS" ]; then
    echo "No submodules found in .gitmodules."
    exit 0
fi

echo "Removing the following submodules:"
echo "$SUBMODULE_PATHS"
echo "---------------------------------"

for SUBMODULE_PATH in $SUBMODULE_PATHS; do
    echo "Processing submodule: $SUBMODULE_PATH"

    # 1. Deinitialize the submodule
    # -f or --force is used to forcefully deinitialize even if there are local changes
    git submodule deinit -f -- "$SUBMODULE_PATH" || { echo "Failed to deinitialize $SUBMODULE_PATH"; exit 1; }

    # 2. Remove the submodule directory from the superproject's .git/modules directory
    # This cleans up the submodule's internal Git repository data
    rm -rf ".git/modules/$SUBMODULE_PATH" || { echo "Failed to remove .git/modules/$SUBMODULE_PATH"; exit 1; }

    # 3. Remove the submodule entry from the working tree and the Git index
    # Use --cached to remove from index but keep files in working tree if desired,
    # but for full removal, we usually want to remove the files too.
    # The -f flag forces removal even if the files are modified.
    git rm -f "$SUBMODULE_PATH" || { echo "Failed to git rm $SUBMODULE_PATH"; exit 1; }

    # 4. Remove submodule configuration from .git/config
    # This is often cleaned by `git submodule deinit`, but it's good to be explicit
    # and use --remove-section for robustness.
    git config -f .git/config --remove-section "submodule.$SUBMODULE_PATH" 2>/dev/null

    # 5. Remove submodule section from .gitmodules
    # This will be automatically handled by `git rm` but we list it explicitly
    # if you were doing manual editing or just for understanding.
    # The `git rm` command handles the .gitmodules file for you.
done

echo "---------------------------------"
echo "All submodules deinitialized and removed from index and .git/modules."

# 6. Commit the changes
# Git automatically stages changes to .gitmodules when you `git rm` a submodule
git add .gitmodules # Ensure .gitmodules changes are staged
git commit -m "Remove all submodules from this branch" || { echo "No changes to commit or commit failed."; }

echo "Submodule removal committed. Remember to 'git push' to apply changes remotely."
