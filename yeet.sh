#!/usr/bin/env bash
# yeet.sh - Generate funny commit messages and automatically commit all changes

set -o pipefail

# Configuration
MODEL_NAME="qwen:0.5b"
OLLAMA_API="http://localhost:11434/api/generate"
TIMEOUT=10
DEBUG=${DEBUG:-0}  # Set DEBUG=1 in environment to enable debug output

# Debug logging function
debug() {
  if [[ $DEBUG -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Stage all changes and get the diff
stage_and_get_diff() {
  # Add all changes
  git add .
  
  # Get the staged diff (without pager)
  git --no-pager diff --staged
}

# Function to generate a commit message using Ollama
generate_commit_message() {
  local diff="$1"
  
  # Check if dependencies are available
  if ! command -v ollama &>/dev/null || 
     ! command -v curl &>/dev/null || 
     ! command -v jq &>/dev/null; then
    echo "feat: 🛒 Missing dependencies (ollama, curl, or jq)" >&2
    exit 1
  fi
  
  # Create system and user prompts for the Ollama API
  local system_prompt="You are a sarcastic developer who writes technically accurate git commit messages based on the actual code changes in a diff."
  local user_prompt="Generate a snarky but technically accurate git commit message for this diff:
$diff

Analyze the changes and create a commit message with:
- Type: feat, fix, refactor, or perf
- Title: Short description with emoji (✨=feature, 🐛=fix)
- Body: 3 bullet points about specific files that changed

Example format:
feat: ✨ Improved JSON schema handling

- Added proper schema validation in yeet.sh because who needs runtime errors
- Removed hardcoded examples from yeet.sh, we're all professionals here
- Added better error handling in yeet.sh because users make mistakes"

  # Create JSON payload without complex schema
  local json_payload=$(jq -n \
    --arg model "$MODEL_NAME" \
    --arg prompt "$user_prompt" \
    --arg system "$system_prompt" \
    '{
      model: $model,
      prompt: $prompt,
      system: $system,
      stream: false
    }')
  
  # Debug the request
  debug "Sending request to Ollama API with prompt:"
  debug "$user_prompt"

  # Call the Ollama API and get response
  local response=$(timeout $TIMEOUT curl -s -X POST $OLLAMA_API \
    -H "Content-Type: application/json" \
    -d "$json_payload" 2>/dev/null)
    
  # Extract the JSON response
  local result=$(echo "$response" | jq -r '.response // empty')
  
  # Debug the response
  debug "Raw API response:"
  debug "$(echo "$response" | jq .)"
  debug "Parsed result:"
  debug "$result"
  
  # Try to parse as JSON first
  if [[ "$result" == "{"* ]]; then
    debug "Detected JSON response, attempting to parse"
    local type=$(echo "$result" | jq -r '.type // empty')
    local title=$(echo "$result" | jq -r '.title // empty')
    local body=$(echo "$result" | jq -r '.body // empty')
    
    # Debug the extracted components
    debug "Extracted components:"
    debug "Type: '$type'"
    debug "Title: '$title'"
    debug "Body: '$body'"
    
    if [[ -n "$type" && -n "$title" ]]; then
      # Normalize type and trim spaces
      type=$(echo "$type" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      case "$type" in
        "feature") type="feat" ;;
        "bug") type="fix" ;;
      esac
      
      # Ensure title has an emoji
      if [[ "$title" != *"🔥"* && "$title" != *"✨"* && "$title" != *"🛒"* && "$title" != *"🚀"* && "$title" != *"🐛"* ]]; then
        title="✨ $title"
      fi
      
      # Format conventional commit with body
      if [[ -n "$body" ]]; then
        # Remove any leading spaces from the title and type
        title=$(echo "$title" | sed 's/^[[:space:]]*//')
        type=$(echo "$type" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        # Clean up the body to ensure proper spacing
        body=$(echo "$body" | 
               # First trim whitespace from start and end of each line
               sed 's/^[ \t]*//' | sed 's/[ \t]*$//' | 
               # Fix spacing around dashes and remove double spaces
               sed 's/ -/-/g' | sed 's/  / /g' | 
               # Fix other spacing issues
               sed 's/--/ --/g')
        # Ensure we have correct formatting with no extra spaces
        printf "%s: %s\n\n%s" "$type" "$(echo "$title" | cut -c 1-50)" "$body"
        return
      else
        # Fallback if no body
        title=$(echo "$title" | sed 's/^[[:space:]]*//')
        type=$(echo "$type" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        printf "%s: %s" "$type" "$(echo "$title" | cut -c 1-70)"
        return
      fi
    fi
  fi
  
  # If not JSON or JSON parsing failed, try to parse as plain text
  debug "Attempting to parse as plain text"
  
  # Extract type, title and body using regex patterns
  local type="feat"
  local title=""
  local body=""
  
  # Clean up the result by removing quotes and extra characters
  result=$(echo "$result" | sed 's/"//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  
  # Try to find conventional commit format (type: title)
  if [[ "$result" =~ ^(feat|fix|refactor|perf)[[:space:]]*:[[:space:]]*(.*) ]]; then
    type="${BASH_REMATCH[1]}"
    title="${BASH_REMATCH[2]}"
    # Try to extract body (everything after first blank line)
    if [[ "$result" =~ \n[[:space:]]*\n(.*) ]]; then
      body="${BASH_REMATCH[1]}"
    fi
  else
    # If not in conventional format, use first line as title
    title=$(echo "$result" | head -n 1)
    # And rest as body
    body=$(echo "$result" | tail -n +3)
  fi
  
  # Clean up title and body
  title=$(echo "$title" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/"//g')
  body=$(echo "$body" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/"//g')
  
  debug "Extracted from plain text:"
  debug "Type: '$type'"
  debug "Title: '$title'"
  debug "Body: '$body'"
  
  # Check if the title is too generic or contains instruction text
  if [[ "$title" == *"Title"* || "$title" == *"title"* || "$title" == *"Short description"* || \
        "$title" == *"this commit"* || "$title" == *"This commit"* || "$title" == *"indicating"* || \
        "$title" == *"changes to"* || "$title" == *"message is"* || "$title" == *"message for"* ]]; then
    # Extract file names from the diff
    local changed_files=$(echo "$diff" | grep -E "^\+\+\+ b/" | sed 's/^+++ b\///' | sort -u)
    
    # Set a better default title based on the files changed
    if [[ "$changed_files" == *"yeet.sh"* ]]; then
      title="Simplified LLM prompt and improved response handling"
    else
      title="Code improvements and refactoring"
    fi
  fi
  
  # Ensure title has an emoji
  if [[ "$title" != *"🔥"* && "$title" != *"✨"* && "$title" != *"🛒"* && "$title" != *"🚀"* && "$title" != *"🐛"* ]]; then
    title="✨ $title"
  fi
  
  # Clean up the body if it contains instruction text or is empty/generic
  if [[ -z "$body" || "$body" == *"bullet points"* || "$body" == *"referencing"* || "$body" == *"SPECIFIC"* ]]; then
    # Extract file names from the diff for more specific body
    local changed_files=$(echo "$diff" | grep -E "^\+\+\+ b/" | sed 's/^+++ b\///' | sort -u)
    
    if [[ "$changed_files" == *"yeet.sh"* ]]; then
      body="- Simplified the LLM prompt for better commit message generation\n- Removed JSON schema format requirement for more flexible responses\n- Added better error handling for both JSON and plain text responses"
    else
      body="- Made code improvements based on the latest changes\n- Refactored for better readability and maintainability\n- Fixed potential issues in the codebase"
    fi
  fi
  
  # Format the commit message
  if [[ -n "$body" ]]; then
    printf "%s: %s\n\n%s" "$type" "$(echo "$title" | cut -c 1-50)" "$body"
    return
  else
    printf "%s: %s" "$type" "$(echo "$title" | cut -c 1-70)"
    return
  fi
  
  # Fallback message - only reached if all parsing methods fail
  echo -e "feat: ✨ Made some awesome changes!\n\nSomehow things work better now. Magic! 🎩✨"
}

# Create commit with the generated message and push if remote exists
do_commit() {
  local message="$1"
  
  # Check if there are staged changes
  if git --no-pager diff --staged --quiet; then
    echo "Nothing to commit. Make some changes first!"
    exit 1
  fi
  
  # Create a temporary file for the commit message
  local tmp_msg_file=$(mktemp)
  # Use printf to ensure no extra newlines are added
  printf "%s" "$message" > "$tmp_msg_file"
  
  # Commit with the generated message from file to preserve formatting
  git --no-pager commit -F "$tmp_msg_file"
  
  # Clean up
  rm -f "$tmp_msg_file"
  
  echo "🚀 Yeeted your changes to the repo!"
  
  # Check if there's a remote configured for the current branch
  if git --no-pager remote -v | grep -q "^origin"; then
    echo "🌐 Remote detected! Pushing changes..."
    
    # Get current branch name
    local current_branch=$(git --no-pager rev-parse --abbrev-ref HEAD)
    
    # Push to the remote (with no pager)
    if git --no-pager push origin "$current_branch"; then
      echo "🚀 Changes successfully pushed to remote!"
    else
      echo "❌ Failed to push changes. You'll need to push manually."
    fi
  fi
}

# Main execution - the full yeet process
echo "🧙 Summoning the commit genie..."

# Handle dry run mode differently
if [[ "$1" == "--dry-run" || "$1" == "-d" ]]; then
  # In dry run, don't stage changes automatically - just show what would be committed
  echo "🔍 DRY RUN MODE - Showing changes but not committing"
  
  # Show all changes (both staged and unstaged) - use cat to prevent pager
  echo -e "\n📝 Changes that would be committed:"
  git --no-pager diff --color HEAD | cat
  
  # Get the diff for message generation - capture the actual changes with no color
  diff=$(git --no-pager diff HEAD)
  
  # Debug the captured diff
  debug "Dry run diff length: $(echo "$diff" | wc -l) lines"
  debug "First 10 lines of diff:"
  debug "$(echo "$diff" | head -10)"
else
  # Normal mode - stage all changes
  diff=$(stage_and_get_diff)
fi

if [ -z "$diff" ]; then
  echo "No changes detected. Nothing to yeet!"
  exit 0
fi

echo "🔮 Generating a witty commit message..."
message=$(generate_commit_message "$diff")

echo -e "\n💬 Your commit message:\n"
echo "$message"
echo -e "\n"

# Auto-commit unless in dry run mode
if [[ "$1" != "--dry-run" && "$1" != "-d" ]]; then
  do_commit "$message"
else
  echo "🧪 Dry run complete - changes not committed"
fi