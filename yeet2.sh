#!/usr/bin/env bash
set -x
# Properly escape the git diff for JSON
MODEL_NAME="llama3.2:1b"  # Default model - can be changed with --model flag
OLLAMA_HOST=${OLLAMA_HOST:-"localhost"}  # Respect OLLAMA_HOST env variable
OLLAMA_PORT=${OLLAMA_PORT:-"11434"}  # Respect OLLAMA_PORT env variable 
OLLAMA_BASE_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
OLLAMA_API="${OLLAMA_BASE_URL}/api/chat"
OLLAMA_API_BASE="${OLLAMA_BASE_URL}/api"
GIT_DIFF=$(git diff --compact-summary --unified=1 | jq -Rs .)
echo $GIT_DIFF

curl -X POST http://${OLLAMA_HOST}:11434/api/chat -H "Content-Type: application/json" -d '{
  "model": "llama3.2:1b",
  "messages": [
    {
      "role": "system",
      "content": "You are a commit message generator that follows the Conventional Commits specification. Your job is to analyze git diffs and create descriptive commit message and body."
    },
    {
      "role": "user",
      "content": '"$GIT_DIFF"'
    }
  ],
  "context_length": 4096,
  "stream": false,
  "format": {
    "type": "object",
    "properties": {
      "type": {
        "type": "string",
        "enum": ["feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert"]
      },
      "scope": {
        "type": "string"
      },
      "breaking": {
        "type": "boolean",
        "default": false
      },
      "subject": {
        "type": "string",
        "description": "A concise description of the changes, including filenames and functions modified"
      },
      "body": {
        "type": "string",
        "description": "Detailed explanation of what was changed and why"
      }
    },
    "required": ["type", "subject", "body"]
  }
}' | jq "."