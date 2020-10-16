#!/bin/sh
set -e

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

curl_get() {
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    curl -s -f -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "$1"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call may fail due to API limit." >&2
    curl -s -f "$1"
  fi
}

create_or_update_label() {
  label_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/labels/$1"
  if [ curl_get $label_url ]; then # update
    curl -s \
      -H "Authorization: token ${INPUT_GITHUB_TOKEN}" \
      -X PATCH
      -d @/labels/$1.json \
      $label_url
  else # create
    curl -s \
      -H "Authorization: token ${INPUT_GITHUB_TOKEN}" \
      -X POST
      -d @/labels/$1.json \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/labels
  fi
}

create_labels() {
  create_or_update_label major
  create_or_update_label minor
  create_or_update_label patch
}

setup_git() {
  git config user.name "${GITHUB_ACTOR}"
  git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
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
echo "::set-output name=level::#{BUMP_LEVEL}"

if [ -z "${BUMP_LEVEL}" ]; then
  echo "PR with labels for bump not found. Do nothing."
  echo "::set-output name=skipped::true"
  exit
else
  echo "::set-output name=skipped::false"
fi

echo "Bump ${BUMP_LEVEL} version"
if [ "${INPUT_DRY_RUN}" = "true" ]; then
  exit
fi

create_labels
setup_git
gem bump --commit --push --version ${BUMP_LEVEL}
