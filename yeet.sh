#!/usr/bin/env bash
# yeet.sh - Generate funny commit messages and automatically commit all changes

set -o pipefail

# Configuration
MODEL_NAME="llama3.2:1b"  # Default model - can be changed with --model flag
OLLAMA_HOST=${OLLAMA_HOST:-"localhost"}  # Respect OLLAMA_HOST env variable
OLLAMA_PORT=${OLLAMA_PORT:-"11434"}  # Respect OLLAMA_PORT env variable 
OLLAMA_BASE_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
OLLAMA_API="${OLLAMA_BASE_URL}/api/chat"
OLLAMA_API_BASE="${OLLAMA_BASE_URL}/api"
TIMEOUT=120  # Timeout in seconds for Ollama API calls - can be changed with --timeout flag
DRY_RUN=0

# Display version
VERSION="1.0.0"

# Stage all changes and get the diff
stage_and_get_diff() {
  # Add all changes
  git add .
  
  # Get the staged diff (with compact summary and unified format)
  git --no-pager diff --staged --compact-summary --unified=1
}

# Generate a generic fallback message based on changes
generate_fallback_message() {
  local diff="$1"
  
  # Extract file names from the diff
  local changed_files=$(echo "$diff" | grep -E "^\+\+\+ b/" | sed 's/^+++ b\///' | sort -u)
  
  # Create a more useful fallback message based on file types
  local type="feat"
  local title=""
  local body=""
  
  # Check for file types to determine commit type
  if echo "$changed_files" | grep -q '\.md$'; then
    type="docs"
    title="📚 Finally wrote some damn documentation"
  elif echo "$changed_files" | grep -qE '\.(test|spec)\.[jt]s$'; then
    type="test"
    title="✅ Added tests you should've written months ago"
  elif echo "$changed_files" | grep -qE '\.css$|\.scss$'; then
    type="style"
    title="🎨 Fixed your ugly-ass styling"
  elif echo "$diff" | grep -q "^+.*bug\|^+.*fix\|^+.*error"; then
    type="fix"
    title="🐛 Fixed your embarrassing bug in $(echo "$changed_files" | tr '\n' ' ')"
  else
    # Default to feat type
    type="feat"
    title="✨ Added crap to $(echo "$changed_files" | tr '\n' ' ')"
  fi
  
  # Prepare the content for the fallback message
  local file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
  local file_list=$(echo "$changed_files" | sed 's/^/- /' | head -10)
  
  # Create a snarky body 
  local body_text="You somehow managed to screw up $file_count file(s):\n$file_list"
  
  # If there are more files, indicate that
  if [ "$file_count" -gt 10 ]; then
    body_text="${body_text}\n- ... and $(($file_count - 10)) more stupid changes. Jesus Christ."
  fi
  
  # Add notice that this is a fallback message
  body_text="${body_text}\n\n(This is a fallback message because Ollama got fed up with your crappy code)"
  
  # Create proper JSON object with valid escaping using jq
  local json_response=$(jq -n \
    --arg type "$type" \
    --arg subject "$title" \
    --arg body "$body_text" \
    '{type: $type, subject: $subject, body: $body}')
    
  echo "$json_response"
}

# Function to generate a commit message using Ollama
generate_commit_message() {
  local diff="$1"
  
  # Check if dependencies are available
  if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    echo "{\"type\":\"feat\",\"subject\":\"🛒 Missing dependencies (curl or jq)\",\"body\":\"Please install required dependencies\"}"
    exit 1
  fi
  
  # Properly escape the git diff for JSON using jq
  local GIT_DIFF=$(echo "$diff" | jq -Rs .)
  
  # Try a simpler model if the requested one is too big
  local actual_model="$MODEL_NAME"
  local diff_size=${#GIT_DIFF}
  
  # For very large diffs, suggest a smaller model
  if [[ $diff_size -gt 100000 && "$MODEL_NAME" != *":1b" && "$MODEL_NAME" != *"tiny"* ]]; then
    echo "⚠️ Diff is very large. Consider using a smaller model with --model llama3.2:1b" >&2
  fi
  
  # Create a temporary file for the system prompt
  local SYSTEM_PROMPT_FILE=$(mktemp)
  cat > "$SYSTEM_PROMPT_FILE" << 'EOF'
You are a BRUTALLY RUDE commit message generator. Your job is to roast the developer's code while ACCURATELY describing what actually changed. Follow these RULES:
1. BE MEAN AND OFFENSIVE without using slurs or truly inappropriate language
2. Use curse words (damn, hell, shit, ass, etc.)
3. Mock the developer's coding skills and life choices
4. Call out obvious mistakes with extreme prejudice
5. Be condescending, sarcastic, and judgmental
6. CRITICAL: Follow Conventional Commits format (type: subject) and DO NOT include git diff output in the message
7. Keep subject under 50 chars, body 1-3 harsh sentences
8. Use emojis aggressively (🔥💩🤦‍♂️🙄)
9. For body text, roast the developer directly ("Did you seriously think this would work?")
10. Include SPECIFIC DETAILS about what ACTUALLY changed in the code (functions modified, bugs fixed, etc.)
11. If you see specific files being modified, mention them by name (not the entire diff)
12. ANALYZE the diff to extract key technical changes and mention them in a mocking way
13. Never break character - you're always annoyed by these changes
14. Make the commit message ACCURATE despite being mean - a reader should understand what changed
15. DON'T INCLUDE RAW DIFF OUTPUT - convert it to human-readable descriptions

BAD EXAMPLE (DON'T DO THIS):
feat: ✨ poop.txt | 2 +-
 yeet.sh  | 10 +++++++---
 2 files changed, 8 insertions(+), 4 deletions(-)

GOOD EXAMPLE:
feat: 🔥 Finally fixed your garbage pagination logic

Are you kidding me? It took you THIS long to figure out how to count? Your fix in ListComponent.js just adds the damn offset parameter everyone else knew to use. Delete your IDE.
EOF

  # Create a temporary file for storing the payload
  local PAYLOAD_FILE=$(mktemp)
  
  # Create JSON payload with jq in a much simpler way
  jq -n \
    --arg model "$MODEL_NAME" \
    --rawfile system "$SYSTEM_PROMPT_FILE" \
    --arg diff "$GIT_DIFF" \
    '{
      model: $model,
      messages: [
        {
          role: "system",
          content: $system
        },
        {
          role: "user",
          content: $diff
        }
      ],
      stream: false,
      format: {
        type: "object",
        properties: {
          type: {
            type: "string",
            enum: ["feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert"]
          },
          subject: {
            type: "string"
          },
          body: {
            type: "string"
          }
        },
        required: ["type", "subject", "body"]
      }
    }' > "$PAYLOAD_FILE"
    
  # Set the payload variable
  local payload=$(<"$PAYLOAD_FILE")
  
  # Clean up temporary files
  rm -f "$SYSTEM_PROMPT_FILE" "$PAYLOAD_FILE"
  
  # Call the Ollama API
  local response=""
  local curl_exit_code=0
  
  # Use timeout to prevent hanging if Ollama is unresponsive
  response=$(timeout $TIMEOUT curl -s -X POST "$OLLAMA_API" \
    -H "Content-Type: application/json" \
    --max-time $TIMEOUT \
    -d "$payload" 2>/dev/null)
  curl_exit_code=$?
  
  # Check if curl timed out or had other issues
  if [ $curl_exit_code -ne 0 ]; then
    echo "⚠️ Ollama API call failed with exit code $curl_exit_code - your code probably crashed it" >&2
    
    if [ $curl_exit_code -eq 124 ] || [ $curl_exit_code -eq 28 ]; then
      echo "⏱️ Request timed out after $TIMEOUT seconds. Your code was so terrible it broke the damn LLM." >&2
      echo "🤦‍♂️ Try increasing the TIMEOUT value, or writing better code, you animal." >&2
    fi
    
    # Return a fallback message
    generate_fallback_message "$diff"
    return
  fi
  
  # First try to look for the response fields directly in the response
  if echo "$response" | jq -e '.type' >/dev/null 2>&1 && 
     echo "$response" | jq -e '.subject' >/dev/null 2>&1; then
    # Already in the right format, nothing to do
    :
  # Try to extract from various locations API might put it
  elif echo "$response" | jq -e '.message.content' >/dev/null 2>&1; then
    # Message content field exists, extract as JSON if possible
    local content=$(echo "$response" | jq -r '.message.content')
    if echo "$content" | jq -e '.' >/dev/null 2>&1; then
      response="$content"
    fi
  elif echo "$response" | jq -e '.response' >/dev/null 2>&1; then
    # Response field exists, extract as JSON if possible
    local resp=$(echo "$response" | jq -r '.response')
    if echo "$resp" | jq -e '.' >/dev/null 2>&1; then
      response="$resp"
    fi
  fi
  
  # In dry run mode, print the response for debugging
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "=== DEBUG: API RESPONSE START ===" >&2
    echo "$response" | jq '.' >&2
    echo "=== DEBUG: API RESPONSE END ===" >&2
  fi

  # Check for valid JSON with required fields
  if ! echo "$response" | jq -e '.type' >/dev/null 2>&1 || 
     ! echo "$response" | jq -e '.subject' >/dev/null 2>&1; then
    
    echo "⚠️ Response missing required fields (type or subject)" >&2
    
    # Check if there's an error message
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
      local error_msg=$(echo "$response" | jq -r '.error')
      echo "⚠️ Ollama API returned an error: $error_msg" >&2
      
      # Handle model not found error
      if [[ "$error_msg" == *"not found"* ]]; then
        if check_model "$MODEL_NAME" 2>/dev/null; then
          echo "✅ Model pulled successfully, retrying..." >&2
          generate_commit_message "$diff"
          return
        fi
      fi
    fi
    
    # If all else fails, use fallback message
    generate_fallback_message "$diff"
    return
  fi
  
  # At this point, response should be valid JSON with our fields
  echo "$response"
}

# Create commit with the generated message
do_commit() {
  local json_msg="$1"
  
  # Check if there are staged changes
  if git --no-pager diff --staged --quiet; then
    echo "🙄 Nothing to commit, you absolute donut. Make some damn changes first!"
    exit 1
  fi
  
  # Use the JSON message directly - it's already valid JSON
  local clean_json="$json_msg"
  
  # Extract the parts from our JSON with fallbacks for missing fields
  local type=$(echo "$clean_json" | jq -r '.type // "feat"')
  local subject=$(echo "$clean_json" | jq -r '.subject // "✨ Changes"')
  local body=$(echo "$clean_json" | jq -r '.body // ""')
  
  # Validate that we have at least a subject
  if [[ -z "$subject" || "$subject" == "null" ]]; then
    subject="✨ Changes"
  fi
  
  # Format the commit message
  # Truncate excessively long subjects
  if [[ ${#subject} -gt 100 ]]; then
    subject="${subject:0:97}..."
  fi
  
  # Clean up body (remove explicit newlines if necessary)
  body=$(echo "$body" | sed 's/\\n/\n/g')
  
  # Build the final message in a format git expects (first line, blank line, then body)
  # Force the use of proper conventional commit format
  if [[ -n "$type" && "$type" != "null" ]]; then
    echo "${type}: ${subject}" > /tmp/yeet_commit_msg
  else
    echo "feat: ${subject}" > /tmp/yeet_commit_msg
  fi
  
  if [[ -n "$body" ]]; then
    echo "" >> /tmp/yeet_commit_msg
    echo "$body" >> /tmp/yeet_commit_msg
  fi
  
  # Debug output
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DEBUG: Commit message content:" >&2
    cat /tmp/yeet_commit_msg >&2
  fi
  
  # Commit with the generated message from file to preserve formatting
  git --no-pager commit -F /tmp/yeet_commit_msg
  
  # Clean up
  rm -f /tmp/yeet_commit_msg
  
  echo "🚀 Yeeted your crappy changes to the repo! Hope they don't break everything!"
  
  # Check if there's a remote configured for the current branch
  if git --no-pager remote -v | grep -q "^origin"; then
    echo "🌐 Remote detected! Inflicting your garbage on everyone else..."
    
    # Get current branch name
    local current_branch=$(git --no-pager rev-parse --abbrev-ref HEAD)
    
    # Push to the remote (with no pager)
    if git --no-pager push origin "$current_branch"; then
      echo "💩 Successfully dumped your trash into the remote! Your teammates will be THRILLED."
    else
      echo "🤦‍♂️ Even Git couldn't handle your mess. Push your own damn code."
    fi
  fi
}

# Check if ollama is running
check_ollama() {
  if ! curl -s -o /dev/null "${OLLAMA_API_BASE}/version"; then
    echo "⚠️ HEY GENIUS! Ollama service is not running at ${OLLAMA_HOST}:${OLLAMA_PORT}!" >&2
    echo "Did you forget to start it? Are you kidding me right now?" >&2
    echo "Go install Ollama from https://ollama.ai/ if you're too dumb to have it already." >&2
    exit 1
  fi
}

# Check if model is available and pull if needed
check_model() {
  local model="$1"
  
  # Check if model exists
  if ! curl -s "${OLLAMA_API_BASE}/tags" | jq -e ".models[] | select(.name==\"$model\")" >/dev/null; then
    echo "⚠️ Model '$model' not found. Attempting to pull it automatically..." >&2
    
    # Try to pull the model with progress indicator
    echo "📥 Downloading model '$model'. This may take several minutes..." >&2
    
    # Set up spinner characters
    local spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    local i=0
    
    # Use stream mode to show progress
    curl -s -X POST "${OLLAMA_API_BASE}/pull" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"$model\", \"stream\": true}" | 
    while read -r line; do
      if echo "$line" | grep -q "error"; then
        # Extract error message
        local error=$(echo "$line" | jq -r '.error')
        echo -e "\r❌ Failed to pull model '$model': $error                    " >&2
        
        # Suggest fallback models
        echo "ℹ️ Try using one of these available models instead:" >&2
        curl -s "${OLLAMA_API_BASE}/tags" | jq -r '.models[].name' | head -5 | sed 's/^/   - /' >&2
        return 1
      elif echo "$line" | grep -q "status"; then
        # Extract and show progress
        local progress=$(echo "$line" | grep -o '"completed":[0-9.]*,"total":[0-9.]*' | sed 's/"completed":\([0-9.]*\),"total":\([0-9.]*\)/\1\/\2/')
        
        if [[ -n "$progress" ]]; then
          # Calculate percentage
          local completed=$(echo "$progress" | cut -d'/' -f1)
          local total=$(echo "$progress" | cut -d'/' -f2)
          local percent=0
          
          if [[ $total != "0" ]]; then
            percent=$(echo "scale=0; 100*$completed/$total" | bc)
          fi
          
          # Show spinner and progress
          local spin_char=${spinner[$i]}
          ((i = (i + 1) % 10))
          
          echo -ne "\r    $spin_char Downloading: $percent% ($progress)                    " >&2
        fi
      fi
    done
    
    # Verify model was downloaded
    sleep 2 # Give Ollama a moment to index the new model
    if curl -s "${OLLAMA_API_BASE}/tags" | jq -e ".models[] | select(.name==\"$model\")" >/dev/null; then
      echo -e "\r✅ Model '$model' downloaded successfully!                                   " >&2
      return 0
    else
      echo -e "\r❌ Something went wrong during download. Model '$model' not available.       " >&2
      return 1
    fi
  fi
  return 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-d)
      DRY_RUN=1
      shift
      ;;
    --model|-m)
      if [[ -n "$2" ]]; then
        MODEL_NAME="$2"
        shift 2
      else
        echo "Error: --model requires a model name" >&2
        exit 1
      fi
      ;;
    --timeout|-t)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        TIMEOUT="$2"
        shift 2
      else
        echo "Error: --timeout requires a number in seconds" >&2
        exit 1
      fi
      ;;
    --help|-h)
      echo "yeet.sh v$VERSION - Generate funny commit messages using Ollama LLMs"
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -d       Show what would be committed but don't actually commit"
      echo "  --model, -m NAME    Use a specific Ollama model (default: $MODEL_NAME)"
      echo "  --timeout, -t SECS  Set API timeout in seconds (default: $TIMEOUT)"
      echo "  --version, -v       Show version information"
      echo "  --help, -h          Show this help message"
      echo ""
      echo "Environment variables:"
      echo "  OLLAMA_HOST         Set Ollama host (default: localhost)"
      echo "  OLLAMA_PORT         Set Ollama port (default: 11434)"
      exit 0
      ;;
    --version|-v)
      echo "yeet.sh v$VERSION"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

# Check if Ollama is running
check_ollama

# Check if the selected model is available
check_model "$MODEL_NAME"

# Main execution
echo "🧙 Summoning the commit demon to judge your pathetic code..."

# Handle dry run mode
if [[ $DRY_RUN -eq 1 ]]; then
  echo "🔍 DRY RUN MODE - I'll show you how bad your changes are without committing them"
  
  # Show all changes
  echo -e "\n📝 This is the crap you want to commit:"
  git --no-pager diff --color HEAD | cat
  
  # Get the diff for message generation
  diff=$(git --no-pager diff HEAD --compact-summary --unified=1)
else
  # Normal mode - stage all changes
  diff=$(stage_and_get_diff)
fi

if [ -z "$diff" ]; then
  echo "🤬 Are you kidding me? No changes detected. What the hell am I supposed to work with?"
  exit 0
fi

echo "🔮 Generating an insult for your crappy code..."

# Use fallback message generation directly to ensure we get something reasonable
fallback_json=$(generate_fallback_message "$diff")
type=$(echo "$fallback_json" | jq -r '.type')
subject=$(echo "$fallback_json" | jq -r '.subject')
body=$(echo "$fallback_json" | jq -r '.body')

# Try to get a better message from Ollama
json_message=$(generate_commit_message "$diff")

# Check if the response has valid json with required fields
if echo "$json_message" | jq -e '.type' >/dev/null 2>&1 && 
   echo "$json_message" | jq -e '.subject' >/dev/null 2>&1; then
  
  # Extract fields from the response
  type=$(echo "$json_message" | jq -r '.type // "feat"')
  subject=$(echo "$json_message" | jq -r '.subject // "✨ Changes"')
  body=$(echo "$json_message" | jq -r '.body // ""')
fi

# Ensure subject has an emoji if it doesn't already have one
if [[ "$subject" != *"🔥"* && "$subject" != *"✨"* && "$subject" != *"🚀"* && 
       "$subject" != *"🐛"* && "$subject" != *"📚"* && "$subject" != *"♻️"* && 
       "$subject" != *"⚡️"* && "$subject" != *"🔧"* ]]; then
  case "$type" in
    feat) subject="✨ $subject" ;;
    fix) subject="🐛 $subject" ;;
    docs) subject="📚 $subject" ;;
    perf) subject="⚡️ $subject" ;;
    refactor) subject="♻️ $subject" ;;
    *) subject="✨ $subject" ;;
  esac
fi

# Recreate the json_message with our validated fields
json_message=$(jq -n \
  --arg type "$type" \
  --arg subject "$subject" \
  --arg body "$body" \
  '{type: $type, subject: $subject, body: $body}')

echo -e "\n💬 Your insulting commit message (you deserve it):\n"
echo -e "$type: $subject"
if [[ -n "$body" ]]; then
  echo -e "\n$body"
fi
echo -e "\n"

# Auto-commit unless in dry run mode
if [[ $DRY_RUN -eq 0 ]]; then
  do_commit "$json_message"
else
  echo "🧪 Dry run complete - saved your ass from committing that garbage. You're welcome."
fi