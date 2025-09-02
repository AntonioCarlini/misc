#!/bin/bash
#
# 'git blame'is useful for tracking down where a line changed but doing that for
# a LibreCalc Drawing file is more difficult. The only way I've found is to
# grab the file from a specific commmit and check manually, then repeat.
#
# This script simply pulls out the Nth to Mth commits of a specific file and
# produces those files with a name that includes N and the commit.
#
# So FILE.xyz from 13th commit 16de3d4 will produce FILE-00130-16de3d4.xyz.
#
# 0001 is the most recent commit, 0002 the one before that and so on.
#
# The script doesn't help with looking for the hoped for change, but it does quickly
# produce an ordered set of files that can hopefully be checked systematically.

# Usage: ./git-extract-versions.sh filename start end
#
# Example: ./git-extract-versions.sh file.ods 1 10

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 filename start-number end-number"
  exit 1
fi

FILE=$1
START=$2
END=$3

# Get commits that modified the file in normal order (newest first)
commits=($(git log --pretty=format:"%h" -- "$FILE"))

total_commits=${#commits[@]}

if [ "$END" -gt "$total_commits" ]; then
  echo "End index ($END) is greater than total commits ($total_commits). Using $total_commits."
  END=$total_commits
fi

idx=$START

for (( i=START-1; i<END; i++ ))
do
  commit_hash=${commits[$i]}
  index_num=$(printf "%04d" ${idx})
  output_file="${FILE%.*}-${index_num}-${commit_hash}.ods"
  echo "Extracting commit ${commit_hash} to ${output_file}"
  git show "${commit_hash}:${FILE}" > "${output_file}" || { echo "Failed to extract commit ${commit_hash}"; exit 1; }
  idx=$((idx+1))
done
