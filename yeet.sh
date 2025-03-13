#!/usr/bin/env bash
# yeet.sh - Generate funny commit messages and automatically commit all changes

set -o pipefail

# Configuration
MODEL_NAME="qwen:0.5b"
OLLAMA_API="http://localhost:11434/api/generate"
TIMEOUT=10

# Stage all changes and get the diff
stage_and_get_diff() {
  # Add all changes
  git add .
  
  # Get the staged diff
  git diff --staged
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
  local system_prompt="You are a sarcastic, slightly annoyed developer who writes funny git commit messages."
  local user_prompt="Create a snarky, hilarious git commit message for this diff:
$diff

The message must:
1. Follow the Conventional Commits format with a title AND body
2. Use one of these types: feat, fix, refactor, perf
3. Title should be under 50 characters total and should be specific to what changed
4. Include an emoji at the beginning of the title that matches the type of change
5. The body MUST include a bullet-point list of what actually changed, with each bullet starting with a dash (-)
6. Each bullet point must explain an actual specific change from the diff, not generic statements
7. Body should be separated from title by a blank line
8. Body should be written in sarcastic, condescending tone like you're explaining to someone who will never understand

Return as a JSON object with these fields:
- 'type': the commit type (feat, fix, etc.)
- 'title': the commit title/summary (without the type prefix)
- 'body': your snarky bullet-point explanation of what changed"

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
  
  # Call the Ollama API and get response
  local response=$(timeout $TIMEOUT curl -s -X POST $OLLAMA_API \
    -H "Content-Type: application/json" \
    -d "$json_payload" 2>/dev/null)
    
  # Extract the JSON response
  local result=$(echo "$response" | jq -r '.response // empty')
  
  # Parse JSON and extract type, title and body
  if [[ "$result" == "{"* ]]; then
    local type=$(echo "$result" | jq -r '.type // empty')
    local title=$(echo "$result" | jq -r '.title // empty')
    local body=$(echo "$result" | jq -r '.body // empty')
    
    if [[ -n "$type" && -n "$title" ]]; then
      # Normalize type
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
        # Remove any leading spaces from the title
        title=$(echo "$title" | sed 's/^[[:space:]]*//')
        # Ensure we have correct formatting, avoiding double spaces between type and title
        printf "%s: %s\n\n%s" "$type" "$(echo "$title" | cut -c 1-50)" "$body"
      else
        # Fallback if no body
        title=$(echo "$title" | sed 's/^[[:space:]]*//')
        echo "$type: $title" | cut -c 1-70
      fi
      return
    fi
  fi
  
  # Fallback message
  echo -e "feat: ✨ Made some awesome changes!\n\nSomehow things work better now. Magic! 🎩✨"
}

# Create commit with the generated message
do_commit() {
  local message="$1"
  
  # Check if there are staged changes
  if git diff --staged --quiet; then
    echo "Nothing to commit. Make some changes first!"
    exit 1
  fi
  
  # Commit with the generated message
  git commit -m "$message"
  
  echo "🚀 Yeeted your changes to the repo!"
}

# Main execution - the full yeet process
echo "🧙 Summoning the commit genie..."
diff=$(stage_and_get_diff)

if [ -z "$diff" ]; then
  echo "No changes detected. Nothing to yeet!"
  exit 0
fi

echo "🔮 Generating a witty commit message..."
message=$(generate_commit_message "$diff")

echo -e "\n💬 Your commit message:\n"
echo "$message"
echo -e "\n"

# Auto-commit unless told not to
if [[ "$1" != "--dry-run" && "$1" != "-d" ]]; then
  do_commit "$message"
fi