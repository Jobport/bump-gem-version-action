#!/bin/sh
set -e

cd "${GITHUB_WORKSPACE}" || exit 1

git config --global --add safe.directory "$GITHUB_WORKSPACE"

# Setup these env variables.
# - LABELS
# - PR_NUMBER
# - PR_TITLE
setup_from_push_event() {
  pull_request="$(list_pulls | jq ".[] | select(.merge_commit_sha==\"${GITHUB_SHA}\")")"
  LABELS=$(echo "${pull_request}" | jq '.labels | .[].name')
  PR_NUMBER=$(echo "${pull_request}" | jq -r .number)
  PR_TITLE=$(echo "${pull_request}" | jq -r .title)
}

list_pulls() {
  pulls_endpoint="https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls?state=closed&sort=updated&direction=desc"
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    curl -s -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "${pulls_endpoint}"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call may fail due to API limit." >&2
    curl -s "${pulls_endpoint}"
  fi
}

setup_git() {
  git config user.name "${GITHUB_ACTOR}"
  git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
}

setup_gem_credentials() {
  mkdir -p ~/.gem
  touch ~/.gem/credentials
  chmod 600 ~/.gem/credentials
  echo ":github: Bearer ${INPUT_GITHUB_TOKEN}" > ~/.gem/credentials
}

setup_env() {
  export GEM_RELEASE_RELEASE_TOKEN="${INPUT_GITHUB_TOKEN}"
  export GEM_RELEASE_RELEASE_HOST=https://rubygems.pkg.github.com/jobport
  export GEM_RELEASE_RELEASE_KEY=github
  export GEM_RELEASE_RELEASE_DESCR="${PR_TITLE}"
  export GEM_RELEASE_RELEASE_GITHUB=true
}

setup_from_push_event

BUMP_LEVEL="${INPUT_DEFAULT_BUMP_LEVEL}"
if echo "${LABELS}" | grep "bump:major" ; then
  BUMP_LEVEL="major"
elif echo "${LABELS}" | grep "bump:minor" ; then
  BUMP_LEVEL="minor"
elif echo "${LABELS}" | grep "bump:patch" ; then
  BUMP_LEVEL="patch"
fi
echo "level=#{BUMP_LEVEL}" >> $GITHUB_OUTPUT

if [ -z "${BUMP_LEVEL}" ]; then
  echo "PR with labels for bump not found. Do nothing."
  echo "skipped=true" >> $GITHUB_OUTPUT
  exit
else
  echo "skipped=false" >> $GITHUB_OUTPUT
fi

echo "Bump ${BUMP_LEVEL} version"
if [ "${INPUT_DRY_RUN}" = "true" ]; then
  exit
fi

setup_git
setup_gem_credentials
setup_env

gem bump --commit --version ${BUMP_LEVEL}
if [ -f Gemfile.lock ]; then
  bundle install
  git add Gemfile.lock
  git commit --amend --no-edit
fi
git push origin
gem tag --push
gem release
