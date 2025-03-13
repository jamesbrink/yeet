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
  local system_prompt="You are a sarcastic developer who writes technically accurate git commit messages based on the actual code changes in a diff. First analyze what actually changed in the code, then create an accurate but snarky commit message."
  local user_prompt="Generate a snarky but technically accurate git commit message for this diff:
$diff

CRITICAL INSTRUCTIONS:
1. FIRST, carefully analyze what files were changed and what specific code was added/removed
2. EXTRACT a list of important file names that were modified in the diff
3. Based on the ACTUAL changes shown above, generate a commit message with:
   - Type: One of: feat, fix, refactor, or perf
   - Title: Under 50 chars, starting with emoji, describing the main change
   - Body: EXACTLY 3 bullet points referring to SPECIFIC file changes

FORMAT REQUIREMENTS:
1. Follow Conventional Commits format with a title AND body
2. Type MUST be one of: feat, fix, refactor, perf (no spaces, lowercase)
3. Title MUST be under 50 chars and reference SPECIFIC code that changed
4. Title MUST start with emoji matching the change (✨=feature, 🐛=fix, etc)
5. The body MUST be EXACTLY 3 bullet points (-) referencing SPECIFIC files/code
6. Each bullet point MUST mention specific file names (like main.js, db.py, etc)
7. Each bullet point MUST be sarcastic but technically correct
8. DO NOT use placeholder text - reference ACTUAL files and changes!

Here is an example of the JSON format to use:
{
\"type\": \"feat\",
\"title\": \"✨ Add debug mode and improve git integration\",
\"body\": \"- Added DEBUG environment variable because printing everything is fun\\n- Fixed those stupid git commands with --no-pager flags\\n- Documented the dry-run mode in README.md, how revolutionary\"
}"

  # Create JSON payload
  local json_payload=$(jq -n \
    --arg model "$MODEL_NAME" \
    --arg prompt "$user_prompt" \
    --arg system "$system_prompt" \
    '{
      model: $model,
      prompt: $prompt,
      system: $system,
      format: "json",
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
  
  # Parse JSON and extract type, title and body
  if [[ "$result" == "{"* ]]; then
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
      else
        # Fallback if no body
        title=$(echo "$title" | sed 's/^[[:space:]]*//')
        type=$(echo "$type" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        printf "%s: %s" "$type" "$(echo "$title" | cut -c 1-70)"
      fi
      return
    fi
  fi
  
  # Fallback message
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