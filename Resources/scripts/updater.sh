#!/bin/bash

set -o pipefail

org='PokeAPI'
data_repo='api-data'
branch_name='testbranch'

prepare() {
  mkdir -p ./repositories
  cd repositories || exit
}

clone() {
  git clone "https://github.com/$org/$data_repo.git" "$data_repo"
  git checkout test
}

configure_git() {
  git config --global user.name "pokeapi-machine-user"
  git config --global user.email pokeapi.co@gmail.com
  # chown "$USER" ~/.ssh/config
  # chmod 644 ~/.ssh/config
}

run_updater() {
  sleep 10 # Wait to be sure PokeAPI/pokeapi:origin/master has been updated on Github with the lastest merged PR content
  cd "${data_repo}/updater" || exit
  docker build -t pokeapi-updater .
  docker run --privileged -v ~/.ssh:/root/.ssh -e COMMIT_EMAIL=pokeapi.co@gmail.com -e COMMIT_NAME="pokeapi-machine-user" -e BRANCH_NAME="$branch_name" -e REPO_POKEAPI="https://github.com/PokeAPI/pokeapi.git" -e REPO_DATA="https://github.com/PokeAPI/api-data.git" pokeapi-updater
  cd .. || exit
}

# push() {
#   git checkout -b "$branch_name"
#   touch .gitkeeptestpr
#   git add .
#   git commit -m "play: add test file"
#   git push -uf origin "$branch_name"
# }

pr_content() {
  cat <<EOF
{
  "title": "API data update",
  "body": "Incoming data generated by https://github.com/PokeAPI/pokeapi CircleCI worker",
  "head": "$branch_name",
  "base": "master",
  "assignees": [
    "Naramsim"
  ],
  "labels": [
    "api-data-update"
  ]
}
EOF
}

assignees_and_labels() {
  cat <<EOF
{
  "assignees": [
    "Naramsim"
  ],
  "labels": [
    "api-data-update"
  ]
}
EOF
}

reviewers() { # TODO: Add core team
  cat <<EOF
{
  "reviewers": [
    "Naramsim"
  ]
}
EOF
}

create_pr() {
  sleep 10 # Wait for Github to update origin/${branch_name}
  pr_number=$(curl -H "Authorization: token $MACHINE_USER_GITHUB_API_TOKEN" -X POST --data "$(pr_content)" "https://api.github.com/repos/$org/$data_repo/pulls" | jq '.number')
  if [[ "$pr_number" = "null" ]]; then
    echo "Couldn't create the Pull Request"
    exit 1
  fi
  echo "$pr_number"
}

customize_pr() {
  sleep 10 # Wait for Github to open the PR
  pr_number=$1
  curl -H "Authorization: token $MACHINE_USER_GITHUB_API_TOKEN" -X PATCH --data "$(assignees_and_labels)" "https://api.github.com/repos/$org/$data_repo/issues/$pr_number"
  if [ $? -ne 0 ]; then
		echo "Couldn't add Assignees and Labes to the Pull Request"
	fi
}

assign_pr() {
  pr_number=$1
  curl -H "Authorization: token $MACHINE_USER_GITHUB_API_TOKEN" -X POST --data "$(reviewers)" "https://api.github.com/repos/$org/$data_repo/pulls/$pr_number/requested_reviewers"
  if [ $? -ne 0 ]; then
    echo "Couldn't add Reviewers to the Pull Request"
  fi
}

prepare
clone
configure_git
run_updater
# push
pr_number=$(create_pr)
customize_pr "$pr_number"
assign_pr "$pr_number"
