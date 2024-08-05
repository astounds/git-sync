#!/bin/sh

set -e

SOURCE_REPO=$1
SOURCE_BRANCH=$2
DESTINATION_REPO=$3
DESTINATION_BRANCH=$4

# Check if SOURCE_REPO and DESTINATION_REPO are complete URLs, otherwise construct the appropriate URL
if ! echo $SOURCE_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
    SOURCE_REPO="git@github.com:${SOURCE_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    SOURCE_REPO="https://github.com/${SOURCE_REPO}.git"
  fi
fi

if ! echo $DESTINATION_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
    DESTINATION_REPO="git@github.com:${DESTINATION_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    DESTINATION_REPO="https://github.com/${DESTINATION_REPO}.git"
  fi
fi

echo "SOURCE=$SOURCE_REPO:$SOURCE_BRANCH"
echo "DESTINATION=$DESTINATION_REPO:$DESTINATION_BRANCH"

# Clone the source repository using SSH key if provided
if [[ -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
  git clone -c core.sshCommand="/usr/bin/ssh -i ~/.ssh/src_rsa" "$SOURCE_REPO" /root/source --origin source && cd /root/source
else
  git clone "$SOURCE_REPO" /root/source --origin source && cd /root/source
fi

git remote add destination "$DESTINATION_REPO"

# Fetch all branch and tag references from the source repository
git fetch source '+refs/heads/*:refs/heads/*' --update-head-ok
git fetch source '+refs/tags/*:refs/tags/*'

# Print all branches and tags
git --no-pager branch -a -vv
git --no-pager tag -l

# Configure SSH key for destination if provided
if [[ -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
  git config --local core.sshCommand "/usr/bin/ssh -i ~/.ssh/dst_rsa"
fi

# Push the specified branch to the destination
git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f

# Sync all tags to the destination
git push destination --tags -f 2> /dev/null || true

# Fetch all branches from destination for cleanup
git fetch destination

# Delete branches in the destination repository that are not in the source repository
for branch in $(git branch -r | grep 'destination/' | grep -v "$DESTINATION_BRANCH" | sed 's#destination/##g' 2>/dev/null); do
  if ! git show-ref --verify --quiet "refs/remotes/source/$branch"; then
    echo "Deleting branch $branch from destination repository"
    git push destination --delete "$branch"
  fi
done
