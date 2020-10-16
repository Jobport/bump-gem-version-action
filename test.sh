#!/bin/sh

curl \
  -f \
  -H "Authorization: token ${jobport_github_token}" \
  -X POST \
  -d @./labels/major.json \
  https://api.github.com/repos/Jobport/jabiru/labels

# curl \
#   -H "Authorization: token ${jobport_github_token}" \
#   https://api.github.com/repos/Jobport/jabiru/labels
