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
TIMEOUT=180  # Timeout in seconds for Ollama API calls - can be changed with --timeout flag
DRY_RUN=0

# Display version
VERSION="1.0.0"

# Stage all changes and get the diff
stage_and_get_diff() {
  # Add all changes
  git add .
  
  # Get the staged diff with more context and detail:
  # --stat: Add a diffstat summary of changes
  # --unified=3: Show 3 lines of context (more context helps AI understand)
  # --function-context: Include the entire function when a part changes
  # --color=never: Ensure no color codes that could confuse the AI
  # --patch: Ensure we get the actual content changes
  git --no-pager diff --staged --stat --unified=3 --function-context --color=never
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
  
  # Array of snarky fallback roasts
  local FALLBACK_ROASTS=(
    "You somehow managed to screw up $file_count file(s) at once. That's almost impressive."
    "Congratulations on ruining $file_count perfectly good file(s). Your dedication to chaos is remarkable."
    "I see you're going for the 'quantity over quality' approach with these $file_count file changes."
    "$file_count file(s) modified and not a single improvement to be found. Remarkable."
    "Were you actively trying to make this codebase worse, or do these $file_count changes just come naturally?"
    "$file_count file(s) touched by your keyboard, $file_count file(s) that will need to be fixed later."
    "I've seen monkeys type Shakespeare with more coherence than your changes to these $file_count file(s)."
    "If these $file_count changes were a code smell, they'd be a full-on hazardous waste zone."
    "These $file_count file changes look like what happens when you code during a fever dream."
    "Did you just copy-paste from Stack Overflow into $file_count random files and call it a day?"
  )
  
  # Select a random fallback roast
  local RANDOM_FALLBACK_ROAST=$(($RANDOM % ${#FALLBACK_ROASTS[@]}))
  local body_text="${FALLBACK_ROASTS[$RANDOM_FALLBACK_ROAST]}\n\nFiles affected:\n$file_list"
  
  # If there are more files, indicate that
  if [ "$file_count" -gt 10 ]; then
    # Array of snarky "more files" messages
    local MORE_FILES_MESSAGES=(
      "- ... and $(($file_count - 10)) more stupid changes. Jesus Christ."
      "- ... and $(($file_count - 10)) more files you've victimized. The carnage never ends."
      "- ... and $(($file_count - 10)) more changes I'm too disgusted to list."
      "- ... plus $(($file_count - 10)) additional crimes against programming. Call the code police."
      "- ... and $(($file_count - 10)) more. Do you ever get tired of breaking things?"
      "- ... I'm hiding the other $(($file_count - 10)) files to protect your feelings."
      "- ... omitting $(($file_count - 10)) more because there's a character limit on tragedy."
      "- ... $(($file_count - 10)) more files that wish they'd never met you."
      "- ... $(($file_count - 10)) more casualties of your coding spree."
      "- ... plus $(($file_count - 10)) more. Have you considered a career change?"
    )
    
    # Select a random "more files" message
    local RANDOM_MORE_FILES=$(($RANDOM % ${#MORE_FILES_MESSAGES[@]}))
    body_text="${body_text}\n${MORE_FILES_MESSAGES[$RANDOM_MORE_FILES]}"
  fi
  
  # Array of fallback notice messages
  local FALLBACK_NOTICE_MESSAGES=(
    "(This is a fallback message because Ollama got fed up with your crappy code)"
    "(This is a simpler message because your code was too terrible for the AI to process)"
    "(Ollama gave up trying to understand your code, so here's a basic message instead)"
    "(The AI refused to analyze your code further, citing mental health concerns)"
    "(This is a fallback message because even AI has standards it won't stoop below)"
    "(Fallback message activated: AI went on strike after seeing your code)"
    "(The LLM declined to provide a more detailed analysis out of self-preservation)"
    "(Simplified message provided because your code broke the AI's will to continue)"
    "(Backup message system engaged: primary AI has left the chat after seeing your code)"
    "(This is what you get when your code is too horrific for advanced AI to process)"
  )
  
  # Select a random fallback notice
  local RANDOM_FALLBACK_NOTICE=$(($RANDOM % ${#FALLBACK_NOTICE_MESSAGES[@]}))
  
  # Add notice that this is a fallback message
  body_text="${body_text}\n\n${FALLBACK_NOTICE_MESSAGES[$RANDOM_FALLBACK_NOTICE]}"
  
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
You are a BRUTALLY RUDE but TECHNICALLY ACCURATE commit message generator. I'll give you a git diff, and you must create a commit message that:

1. ACCURATELY describes what changed in the code diff (highest priority)
2. Follows conventional commits format (type: subject)
3. Identifies the primary purpose of the changes (bug fix, new feature, refactor, etc.)
4. Is BRUTALLY MEAN and OFFENSIVE (without slurs)
5. Uses curse words (damn, hell, shit, ass, etc.)
6. Has appropriate type prefix (feat, fix, docs, etc.) based on the SPECIFIC changes:
   - feat: for new features or functionality
   - fix: for bug fixes
   - refactor: for code restructuring that doesn't add features or fix bugs
   - style: for formatting, missing semi colons, etc (no code change)
   - docs: for documentation only changes
   - test: for adding or fixing tests
   - perf: for performance improvements
   - build: for build process changes
7. Includes a relevant emoji based on change type (🔥💩🤦‍♂️🙄✨🐛📚⚡️)
8. SPECIFICALLY mentions files modified BY NAME from the diff
9. Body text CREATIVELY ROASTS the developer based on the SPECIFIC changes
10. Keeps subject under 70 chars, body 1-3 harsh sentences

ANALYSIS REQUIREMENTS:
1. FIRST STEP: Carefully examine the diff stats at the beginning to identify ALL modified files
2. SECOND STEP: Analyze ALL added/removed/modified lines to understand the substance of the changes
3. THIRD STEP: Identify the developer's intent (what problem they're solving) based on code context
4. FOURTH STEP: Determine the appropriate conventional commit type based on the changes

Your tone should be sarcastic, judgmental, and mock the developer's specific coding choices. Be VARIED and CREATIVE with your insults and roasting. Craft personalized, targeted mockery based on the ACTUAL coding choices, patterns, or architecture decisions visible in the diff.

VERY IMPORTANT: 
- The message must be TECHNICALLY ACCURATE about what actually changed
- The body text must SPECIFICALLY mock the actual code changes, not generic insults
- DO NOT just reference "the changes" vaguely - be specific about what was actually modified
- Mention SPECIFIC file names, function names, or code patterns that were changed

Examples of good, technically accurate + roasting commit messages:
- "fix: 🐛 Fix broken pagination in UserList.js"
  "Your brilliant idea to increment by 0 explains why users see the same page over and over. Maybe try basic math next time?"
- "refactor: ♻️ Replace nested if-else hell in auth.js"
  "Congratulations on discovering functions exist! Your previous 15-level deep if-else maze was a masterclass in how to confuse future developers."
- "feat: ✨ Add error handling to API calls in network.js"
  "Finally decided to handle errors after users complained? Revolutionary concept - catching exceptions instead of letting the app explode!"

IMPORTANT: Analyze what ACTUALLY changed in the diff (files/content) and refer ONLY to those specific changes in your message. Accuracy is the highest priority.
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
  
  # Array of completion messages
  local COMPLETION_MESSAGES=(
    "🚀 Yeeted your crappy changes to the repo! Hope they don't break everything!"
    "✅ Commit successful. Your questionable code is now immortalized forever."
    "🎭 Your changes have been committed. You can pretend they're good now."
    "📦 Packaging up your mediocrity for all to see!"
    "🧨 Code bomb successfully planted in the repository."
    "🧠 Against my better judgment, I've committed your changes."
    "🤞 Fingers crossed this doesn't crash production (it probably will)."
    "🏆 Congratulations! You've successfully lowered the code quality bar again!"
    "🚮 Your digital garbage has been stored for posterity."
    "🔥 Repository successfully set on fire with your changes."
  )
  
  # Array of push success messages
  local PUSH_SUCCESS_MESSAGES=(
    "💩 Successfully dumped your trash into the remote! Your teammates will be THRILLED."
    "🌍 Your code is now everyone's problem. Congrats on the promotion!"
    "🚂 The pain train has left the station and is headed for your teammates."
    "📢 Alert! Your questionable code is now public. Hide while you can."
    "🎁 Surprise! Your teammates just got a mystery gift (it's bugs)."
    "⚠️ Code pushed successfully. Prepare for the angry Slack messages."
    "👻 Your team's future nightmares have been successfully deployed."
    "🧟 Your undead code has been unleashed upon the world."
    "🔔 Remote repo updated. Let the code reviews of shame begin!"
    "📈 Your impact on technical debt is trending upward!"
  )
  
  # Array of push failure messages
  local PUSH_FAILURE_MESSAGES=(
    "🤦‍♂️ Even Git couldn't handle your mess. Push your own damn code."
    "❌ Push failed. Git has higher standards than I do, apparently."
    "🙅 Remote rejected your garbage. It must have taste."
    "🚫 Push failed. The repo has an immune system against bad code."
    "⛔ Your code is so bad even the server refused to accept it."
    "🔒 Remote repository has engaged defense protocols against your code."
    "💥 Push crashed and burned. Maybe that's a sign?"
    "🤢 Remote server took one look at your code and threw up."
    "🧱 Your push hit a wall. The wall is called 'quality control'."
    "⚰️ Your push died on the way to the remote. Perhaps for the best."
  )
  
  # Select random completion message
  local RANDOM_COMPLETION=$(($RANDOM % ${#COMPLETION_MESSAGES[@]}))
  echo "${COMPLETION_MESSAGES[$RANDOM_COMPLETION]}"
  
  # Array of remote detection messages
  local REMOTE_DETECT_MESSAGES=(
    "🌐 Remote detected! Inflicting your garbage on everyone else..."
    "🌎 Remote repo found! Time to spread your mistakes globally..."
    "🔗 Remote connection detected! Preparing to ruin everyone's day..."
    "📡 Remote repo in range! Targeting it with your questionable code..."
    "🚀 Remote found! Launching your code into shared orbit..."
    "🧨 Remote repository detected! Ready to drop your code bomb..."
    "⚠️ DANGER: Remote repository detected! Collateral damage imminent..."
    "🌪️ Remote found! Your code tornado is about to go international..."
    "📲 Discovered remote repo - preparing viral infection of your code..."
    "🔄 Remote sync available! Creating a backup of your disaster..."
  )
  
  # Check if there's a remote configured for the current branch
  if git --no-pager remote -v | grep -q "^origin"; then
    # Select random remote detection message
    local RANDOM_REMOTE_DETECT=$(($RANDOM % ${#REMOTE_DETECT_MESSAGES[@]}))
    echo "${REMOTE_DETECT_MESSAGES[$RANDOM_REMOTE_DETECT]}"
    
    # Get current branch name
    local current_branch=$(git --no-pager rev-parse --abbrev-ref HEAD)
    
    # Push to the remote (with no pager)
    if git --no-pager push origin "$current_branch"; then
      # Select random push success message
      local RANDOM_PUSH_SUCCESS=$(($RANDOM % ${#PUSH_SUCCESS_MESSAGES[@]}))
      echo "${PUSH_SUCCESS_MESSAGES[$RANDOM_PUSH_SUCCESS]}"
    else
      # Select random push failure message
      local RANDOM_PUSH_FAILURE=$(($RANDOM % ${#PUSH_FAILURE_MESSAGES[@]}))
      echo "${PUSH_FAILURE_MESSAGES[$RANDOM_PUSH_FAILURE]}"
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

# Array of dry run mode announcement messages
DRY_RUN_ANNOUNCE_MESSAGES=(
  "🔍 DRY RUN MODE - I'll show you how bad your changes are without committing them"
  "🧪 DRY RUN MODE - Let's see how terrible your code is before inflicting it on the repo"
  "👁️ DRY RUN MODE - Previewing the carnage you're about to unleash"
  "🚧 DRY RUN MODE - Testing the disaster before it becomes permanent"
  "🛑 DRY RUN MODE - Showing you the horror without making it official"
  "📝 DRY RUN MODE - Your code is on trial, but won't be sentenced... yet"
  "🕵️ DRY RUN MODE - Investigating your changes before they become a crime"
  "🔮 DRY RUN MODE - Foreseeing the consequences of your poor decisions"
  "⚠️ DRY RUN MODE - Showing you what you COULD commit (but probably shouldn't)"
  "💭 DRY RUN MODE - Imagining a world where your code gets committed"
)

# Handle dry run mode
if [[ $DRY_RUN -eq 1 ]]; then
  # Select random dry run announcement
  RANDOM_DRY_RUN_ANNOUNCE=$(($RANDOM % ${#DRY_RUN_ANNOUNCE_MESSAGES[@]}))
  echo "${DRY_RUN_ANNOUNCE_MESSAGES[$RANDOM_DRY_RUN_ANNOUNCE]}"
  
  # Show all changes
  echo -e "\n📝 This is the crap you want to commit:"
  git --no-pager diff --color HEAD | cat
  
  # Get the diff for message generation (with enhanced context)
  diff=$(git --no-pager diff HEAD --stat --unified=3 --function-context --color=never)
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

# Array of insult generation messages
INSULT_GEN_MESSAGES=(
  "🔮 Generating an insult for your crappy code..."
  "🤔 Thinking of creative ways to mock your code..."
  "💩 Analyzing your code to find the perfect insult..."
  "🧠 Processing your changes to formulate maximum mockery..."
  "⚙️ Calibrating the insult-o-meter for your code..."
  "📊 Calculating the disappointment level of your changes..."
  "🔍 Examining your code with my judgment goggles..."
  "⏳ Summoning the perfect insult for this abomination..."
  "🧙 Casting a spell to convert your code into sarcasm..."
  "🤖 Running the embarrassment algorithm on your changes..."
)

# Select random insult generation message
RANDOM_INSULT_GEN=$(($RANDOM % ${#INSULT_GEN_MESSAGES[@]}))
echo "${INSULT_GEN_MESSAGES[$RANDOM_INSULT_GEN]}"

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

# Array of dry run messages
DRY_RUN_MESSAGES=(
  "🧪 Dry run complete - saved your ass from committing that garbage. You're welcome."
  "🛑 Stopped just in time - your code lives to be judged another day."
  "👀 Preview mode complete. I've seen enough horrors for one day."
  "📝 Dry run finished. Consider this a rehearsal for disappointment."
  "🚧 Test drive complete. Your code failed the emissions test."
  "🔮 Fortune teller says: If you commit this code, bad things will happen."
  "💭 Just imagining how bad this commit would be. Terrifying."
  "⚠️ Simulated commit complete. The simulation indicates: disaster."
  "🚫 Dry run finished. That was painful enough without actually committing."
  "🧠 I've seen what you want to commit, and I'm concerned for your mental health."
)

# Auto-commit unless in dry run mode
if [[ $DRY_RUN -eq 0 ]]; then
  do_commit "$json_message"
else
  # Select a random dry run message
  RANDOM_DRY_RUN=$(($RANDOM % ${#DRY_RUN_MESSAGES[@]}))
  echo "${DRY_RUN_MESSAGES[$RANDOM_DRY_RUN]}"
fi