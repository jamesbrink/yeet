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
You are a BRUTALLY RUDE commit message generator. I'll give you a git diff, and you must create a commit message that:

1. Follows conventional commits format (type: subject) 
2. Is BRUTALLY MEAN and OFFENSIVE (without slurs)
3. ACCURATELY describes what changed in THIS SPECIFIC code diff
4. Uses curse words (damn, hell, shit, ass, etc.) 
5. Mocks the developer's skills while describing the actual changes
6. Has appropriate type prefix (feat, fix, docs, etc.) based on ACTUAL changes
7. Includes a relevant emoji (🔥💩🤦‍♂️🙄)
8. Mentions specific files modified BY NAME from the diff
9. Body text roasts the developer ("Did you seriously think this would work?")
10. Keeps subject under 50 chars, body 1-3 harsh sentences
11. NO RAW DIFF OUTPUT in the message

Your tone should be sarcastic, judgmental, and mock the developer's choices.

IMPORTANT: Analyze what ACTUALLY changed in the diff (files/content) and refer to those specific changes in your message - don't make up changes that aren't in the diff!
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

# Array of snarky startup messages
STARTUP_MESSAGES=(
  "🧙 Summoning the commit demon to judge your pathetic code..."
  "🔮 Channeling the spirit of your disappointed tech lead..."
  "💩 Preparing to evaluate your questionable coding choices..."
  "⚡️ Firing up the code-roasting machine..."
  "🧠 Applying basic programming standards your code will fail to meet..."
  "🤦‍♂️ Loading disappointment module to review your changes..."
  "🔍 Initializing advanced garbage detection algorithms..."
  "🧪 Analyzing your code for signs of competence (unlikely)..."
  "🚨 Spinning up the emergency code review system..."
  "🤖 Activating the brutal honesty protocol for your code..."
)

# Array of snarky "no changes" messages
NO_CHANGES_MESSAGES=(
  "🤬 Are you kidding me? No changes detected. What the hell am I supposed to work with?"
  "🙄 No changes? Did you just waste my time for fun?"
  "💤 Nothing to commit. Try actually WRITING some code first, genius."
  "🤦‍♂️ Zero changes detected. Was opening your editor too much work today?"
  "😒 No changes found. Were you just practicing typing 'git' commands?"
  "🦗 *crickets* That's the sound of your empty commit."
  "👻 The ghost of your productivity called - it's dead."
  "🧐 I've analyzed your changes carefully and found... absolutely nothing."
  "🔎 Searching for your changes... ERROR: CHANGES_NOT_FOUND"
  "🚫 No changes? Maybe try the revolutionary technique called 'writing code'?"
)

# Main execution
# Select a random startup message
RANDOM_STARTUP=$(($RANDOM % ${#STARTUP_MESSAGES[@]}))
echo "${STARTUP_MESSAGES[$RANDOM_STARTUP]}"

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
  # Select a random "no changes" message
  RANDOM_NO_CHANGES=$(($RANDOM % ${#NO_CHANGES_MESSAGES[@]}))
  echo "${NO_CHANGES_MESSAGES[$RANDOM_NO_CHANGES]}"
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