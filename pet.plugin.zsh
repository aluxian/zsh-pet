# Buffer standard input to a file. Useful for redirecting output of a pipe chain to the same input file.
#
#  $ grep -v 'a' foo.txt | sponge foo.txt
function pet-sponge() {
  if [ -z "$1" ]; then
    echo "sponge(): No file name given!"
    return 1
  fi

  # Create a temporary file.
  local tmpfile="$(mktemp)"
  # Redirect all stdin in to the temporary file.
  cat > "$tmpfile"
  # Replace the destintation file with the temporary file.
  mv "$tmpfile" "$1"
}

function pet-new() {
  cmnd="$1"
  desc="$2"
  vared -p 'Command: ' -c cmnd
  if [ -z "$cmnd" ]; then echo "missing: command"; return 1; fi
  vared -p 'Description: ' -c desc
  if [ -z "$desc" ]; then echo "missing: description"; return 1; fi
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/pet"
  jq --arg c "$cmnd" --arg d "$desc" -s '.[0] + [{ "command": $c, "description": $d }]' "${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json" | pet-sponge "${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json"
}

function pet-prev() {
	PREV=$(fc -lrn | head -n 1)
	pet-new "$PREV"
}

function pet-select() {
  if ! command -v fzf > /dev/null 2>&1; then
    echo "Error: fzf command not found."
  fi
  [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json" ]] || return 1
	BUFFER=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json" | jq -rc '.[] | "[" + .description + "]" + " " + .command' | fzf --query "$LBUFFER" | sed 's/\[.*\] //')
	CURSOR=$#BUFFER
	zle redisplay
}

function pet-upload() {
  GIST_ID="$1"
  if [[ -z "$GIST_ID" ]]; then
    echo "Error: provide a gist id"
    return 1
  fi
  ACCESS_TOKEN="$(grep -o 'gho_[0-9a-zA-Z]*' "${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml" | head -n 1)"
  if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "Error: access token not found in ${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml"
    return 1
  fi
  FILE_NAME="snippets.json"
  FILE_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json"
  curl -sS -X PATCH -H "Authorization: token $ACCESS_TOKEN" -d "$(jq -n --arg file_name "$FILE_NAME" --arg content "$(cat "$FILE_PATH")" '{"files": {($file_name): {"content": $content}}}' )" "https://api.github.com/gists/$GIST_ID" | jq 'del(.history, .files, .owner, .forks)'
}

function pet-download() {
  GIST_ID="$1"
  if [[ -z "$GIST_ID" ]]; then
    echo "Error: provide a gist id"
    return 1
  fi
  ACCESS_TOKEN="$(grep -o 'gho_[0-9a-zA-Z]*' "${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml" | head -n 1)"
  if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "Error: access token not found in ${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml"
    return 1
  fi
  FILE_NAME="snippets.json"
  FILE_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/pet/${FILE_NAME}"
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/pet"
  curl -sS -H "Authorization: token $ACCESS_TOKEN" "https://api.github.com/gists/$GIST_ID" | jq -r ".files[\"$FILE_NAME\"].content" > "$FILE_PATH"
}

function pet-edit() {
  $EDITOR "${XDG_CONFIG_HOME:-$HOME/.config}/pet/snippets.json"
}

function pet() {
  pet-new "$@"
}

zle -N pet-select
bindkey '^s' pet-select
