#!/usr/bin/env bash
# yeet.sh - Generate funny commit messages and automatically commit all changes

set -o pipefail

# Configuration
MODEL_NAME="qwen:0.5b"
OLLAMA_API="http://localhost:11434/api/generate"
TIMEOUT=30  # Increased timeout for larger diffs
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

# Generate a generic fallback message based on changes
generate_fallback_message() {
  local diff="$1"
  
  # Extract file names from the diff
  local changed_files=$(echo "$diff" | grep -E "^\+\+\+ b/" | sed 's/^+++ b\///' | sort -u)
  debug "Changed files: $changed_files"
  
  # Extract what was added/removed from the diff
  local added_lines=$(echo "$diff" | grep "^+" | grep -v "^+++" | head -10)
  local removed_lines=$(echo "$diff" | grep "^-" | grep -v "^---" | head -10)
  
  # Default commit type and title
  local type="feat"
  local title="✨ Updated $(echo "$changed_files" | tr '\n' ' ')"
  local body=""
  
  # Create a generic body based on the actual changes
  body="- Made changes to $(echo "$changed_files" | wc -l) file(s)"
  
  if [[ -n "$added_lines" ]]; then
    body="${body}\n- Added new code and functionality"
  fi
  
  if [[ -n "$removed_lines" ]]; then
    body="${body}\n- Removed or replaced outdated code"
  fi
  
  # Return the formatted commit message
  echo -e "$type: $title\n\n$body"
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
  
  # Create a prompt using Ollama's structured output format
  local system_prompt="You are a sarcastic developer who writes technically accurate git commit messages based on the actual code changes in a diff. You MUST return a valid JSON object with exactly these fields: type, title, and body."
  local user_prompt="<diff>\n$diff\n</diff>\n\nBased on the diff above, generate a snarky but technically accurate git commit message. Return ONLY a valid JSON object with these fields: type (must be one of: feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert), title (a short description), and body (a detailed explanation). Do not include any explanatory text, just return the JSON object."
  
  # Create JSON payload for Ollama API with structured output format
  local json_payload=$(jq -n \
    --arg model "$MODEL_NAME" \
    --arg prompt "$user_prompt" \
    --arg system "$system_prompt" \
    '{
      model: $model,
      prompt: $prompt,
      system: $system,
      stream: false,
      format: "json"
    }')
  
  # Debug the request
  debug "Sending request to Ollama API"
  debug "System prompt: $system_prompt"
  debug "User prompt length: $(echo -n "$user_prompt" | wc -c) characters"

  # Call the Ollama API and get response
  local response=$(timeout $TIMEOUT curl -s -X POST $OLLAMA_API \
    -H "Content-Type: application/json" \
    -d "$json_payload" 2>/dev/null)
    
  # Debug the response
  debug "Raw API response:"
  debug "$response"
  debug "Raw API response length: $(echo -n "$response" | wc -c) characters"
  
  # Try to extract the JSON response directly from the API response
  debug "Attempting to extract JSON from API response"
  
  # First, try to extract the JSON directly from the response field
  local json_result=""
  
  # Check if the response field contains valid JSON
  if json_result=$(echo "$response" | jq -e '.response' 2>/dev/null); then
    debug "Found JSON in response field"
    
    # The response might be a JSON string that contains a JSON object
    # Try to extract a JSON object from the string
    local extracted_json=""
    if extracted_json=$(echo "$json_result" | grep -o '{.*}' | head -n 1); then
      debug "Found JSON object in string: $extracted_json"
      
      # Try to parse the extracted JSON
      if echo "$extracted_json" | jq -e '.' &>/dev/null; then
        debug "Successfully parsed extracted JSON object"
        json_result="$extracted_json"
      fi
    fi
    
    # Try to parse the JSON from the response field
    if echo "$json_result" | jq -e '.' 2>/dev/null; then
      debug "Successfully parsed JSON from response field"
      
      # Try to extract the commit message components
      local type=""
      local title=""
      local body=""
      
      # First, check if the response is already a properly formatted JSON object
      if echo "$json_result" | jq -e '.type' &>/dev/null && 
         echo "$json_result" | jq -e '.title' &>/dev/null && 
         echo "$json_result" | jq -e '.body' &>/dev/null; then
        debug "Found properly formatted JSON object with all required fields"
        type=$(echo "$json_result" | jq -r '.type' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        title=$(echo "$json_result" | jq -r '.title')
        body=$(echo "$json_result" | jq -r '.body')
      else
        # The response might be a string containing JSON
        debug "Response field doesn't contain a properly formatted JSON object, trying to extract JSON from string"
        
        # Try to extract JSON from the string by finding the first '{' and last '}'
        local json_text=$(echo "$json_result" | tr -d '\n' | sed -E 's/.*\{(.*)}.*/{\1}/')
        
        if echo "$json_text" | jq -e '.' &>/dev/null; then
          debug "Successfully extracted JSON from string"
          
          # Extract components from the extracted JSON
          if echo "$json_text" | jq -e '.type' &>/dev/null && 
             echo "$json_text" | jq -e '.title' &>/dev/null && 
             echo "$json_text" | jq -e '.body' &>/dev/null; then
            debug "Extracted JSON has all required fields"
            type=$(echo "$json_text" | jq -r '.type' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            title=$(echo "$json_text" | jq -r '.title')
            body=$(echo "$json_text" | jq -r '.body')
          fi
        fi
      fi
      
      # If we successfully extracted all components, format and return the commit message
      if [[ -n "$type" && -n "$title" ]]; then
        debug "Successfully extracted all required components from JSON"
        
        # Clean up the title
        title=$(echo "$title" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        # Ensure title has an emoji if it doesn't already have one
        if [[ "$title" != *"🔥"* && "$title" != *"✨"* && "$title" != *"🛒"* && "$title" != *"🚀"* && 
              "$title" != *"🐛"* && "$title" != *"🔧"* && "$title" != *"📚"* && "$title" != *"🎨"* && 
              "$title" != *"♻️"* && "$title" != *"⚡️"* && "$title" != *"✅"* && "$title" != *"🔨"* ]]; then
          if [[ "$type" == "feat" ]]; then
            title="✨ $title"
          elif [[ "$type" == "fix" ]]; then
            title="🐛 $title"
          elif [[ "$type" == "docs" ]]; then
            title="📚 $title"
          elif [[ "$type" == "perf" ]]; then
            title="⚡️ $title"
          else
            title="✨ $title"
          fi
        fi
        
        # Format and return the commit message
        if [[ -n "$body" ]]; then
          echo -e "$type: $title\n\n$body"
          return
        else
          echo "$type: $title"
          return
        fi
      fi
    fi
  fi
  
  # If we couldn't extract a proper JSON object, try to extract the plain text response
  debug "Couldn't extract proper JSON object, falling back to plain text extraction"
  local result=$(echo "$response" | jq -r '.response // empty')
  
  debug "Extracted result text length: $(echo -n "$result" | wc -c) characters"
  
  # If no result or empty result, use a fallback message
  if [[ -z "$result" ]]; then
    debug "Empty response from API, using fallback message"
    generate_fallback_message "$diff"
    return
  fi
  
  # Fallback to conventional commit pattern parsing if not JSON
  debug "Response is not valid JSON, falling back to text parsing"
  
  if [[ "$result" =~ ^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)[[:space:]]*:[[:space:]]*(.*) ]]; then
      local type="${BASH_REMATCH[1]}"
      local title="${BASH_REMATCH[2]}"
      
      debug "Found conventional commit format. Type: $type, Title: $title"
      
      # Try to extract body (everything after first blank line)
      if [[ "$result" =~ $type:[[:space:]]*$title$'\n'$'\n'(.*) ]]; then
        local body="${BASH_REMATCH[1]}"
        
        debug "Body found: $body"
        
        # Clean up the title and body
        title=$(echo "$title" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        body=$(echo "$body" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        # Ensure title has an emoji if it doesn't already have one
        if [[ "$title" != *"🔥"* && "$title" != *"✨"* && "$title" != *"🛒"* && "$title" != *"🚀"* && 
              "$title" != *"🐛"* && "$title" != *"🔧"* && "$title" != *"📚"* && "$title" != *"🎨"* && 
              "$title" != *"♻️"* && "$title" != *"⚡️"* && "$title" != *"✅"* && "$title" != *"🔨"* ]]; then
          if [[ "$type" == "feat" ]]; then
            title="✨ $title"
          elif [[ "$type" == "fix" ]]; then
            title="🐛 $title"
          elif [[ "$type" == "docs" ]]; then
            title="📚 $title"
          elif [[ "$type" == "perf" ]]; then
            title="⚡️ $title"
          else
            title="✨ $title"
          fi
        fi
        
        # Return the formatted commit message with body
        echo -e "$type: $title\n\n$body"
      else
        # No body found, just return the type and title
        debug "No body found, using title only"
        echo "$type: $title"
      fi
    else
      # If no conventional commit format found, use the first line as title with a default type
      debug "No conventional commit format found, parsing as free text"
      local first_line=$(echo "$result" | head -n 1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      
      # Default to feat type if no type found, and add emoji if needed
      if [[ "$first_line" != *"🔥"* && "$first_line" != *"✨"* && "$first_line" != *"🛒"* && "$first_line" != *"🚀"* && 
            "$first_line" != *"🐛"* && "$first_line" != *"🔧"* && "$first_line" != *"📚"* && "$first_line" != *"🎨"* && 
            "$first_line" != *"♻️"* && "$first_line" != *"⚡️"* && "$first_line" != *"✅"* && "$first_line" != *"🔨"* ]]; then
        first_line="✨ $first_line"
      fi
      
      debug "First line (title): $first_line"
      
      # Try to extract body from rest of text (after first blank line)
      if [[ $(echo "$result" | wc -l) -gt 2 ]]; then
        local body=$(echo "$result" | tail -n +3)
        if [[ -n "$body" ]]; then
          debug "Body found from free text"
          echo -e "feat: $first_line\n\n$body"
        else
          debug "No body found in free text"
          echo "feat: $first_line"
        fi
      else
        debug "Single line result, no body"
        echo "feat: $first_line"
      fi
    fi
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