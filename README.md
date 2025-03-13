# 🚀 yeet

A lazy developer's git tool for generating snarky, hilarious commit messages with AI and automatically pushing changes.

## What is yeet?

`yeet` is a bash script that:

1. Stages all your changes (`git add .`)
2. Uses Ollama to generate a funny, sarcastic, but technically accurate commit message based on your code changes
3. Intelligently falls back to smart default messages when the AI is being generic
4. Commits the changes with the generated message
5. Automatically pushes to your remote (if one exists)

All with a single command: `./yeet.sh`

## Requirements

- Bash
- Git
- [Ollama](https://ollama.com/) running locally
- `curl`
- `jq`

## Installation

### The "I'm a serious developer" way:

1. Clone this repository or download `yeet.sh`:
   ```bash
   git clone https://github.com/yourusername/yeet.git
   cd yeet
   chmod +x yeet.sh
   ```

2. Make sure Ollama is installed and running:
   ```bash
   # Install Ollama following instructions at https://ollama.com/
   # Start Ollama
   ollama serve
   # Pull the default model (one time)
   ollama pull qwen:0.5b
   ```

3. Optionally, create a symlink to use `yeet` from anywhere:
   ```bash
   sudo ln -s "$(pwd)/yeet.sh" /usr/local/bin/yeet
   ```

### The "I just want this to work" way:

1. Save the script directly to your project:
   ```bash
   # From your project directory
   curl -o yeet.sh https://raw.githubusercontent.com/yourusername/yeet/main/yeet.sh
   chmod +x yeet.sh
   ```

2. Install dependencies if you don't have them:
   ```bash
   # Mac
   brew install ollama jq curl
   # Ubuntu/Debian
   sudo apt install jq curl
   # Install Ollama from https://ollama.com/
   ```

3. Run Ollama and pull the model:
   ```bash
   ollama serve &
   ollama pull qwen:0.5b
   ```

4. That's it. Just run `./yeet.sh` whenever you want to commit. 
   Who needs proper installation when you can just copy-paste?

## Usage

Just run:

```bash
./yeet.sh
```

Or if you created the symlink:

```bash
yeet
```

### Dry run mode

If you want to see what commit message would be generated without actually committing:

```bash
./yeet.sh --dry-run
# or
./yeet.sh -d
```

Dry run mode:
1. Shows all changes that would be committed (both staged and unstaged)
2. Generates a commit message based on those changes
3. Displays the commit message that would be used
4. Does NOT stage or commit any changes

### Debug mode

Enable debug output by setting the DEBUG environment variable:

```bash
DEBUG=1 ./yeet.sh
```

Debug mode will print detailed information about:
- API requests being sent to Ollama
- Raw API responses 
- Parsed components of the commit message
- Git diff information

## Customization

You can modify the script to change:

- The Ollama model used (change `MODEL_NAME="qwen:0.5b"` to your preferred model)
- The API endpoint (if you're running Ollama somewhere other than localhost)
- The commit message style by editing the prompt
- The timeout for API calls (default is 10 seconds)
- The fallback message patterns in the script (it analyzes your changes to create relevant messages)

## Features

### Smart Commit Message Generation

- Generates commit messages based on actual code changes
- Analyzes added/removed lines to create relevant titles
- Falls back to intelligent defaults when the AI generates generic messages
- Properly formats commit messages with conventional commit types

### Improved Error Handling

- Handles both JSON and plain text responses from the LLM
- Gracefully recovers from API errors or timeouts
- Provides meaningful fallback messages based on file changes

## Examples

```
$ ./yeet.sh
🧙 Summoning the commit genie...
🔮 Generating a witty commit message...

💬 Your commit message:

feat: ✨ Fixed newline formatting in commit messages

- Simplified the LLM prompt for better commit message generation
- Removed JSON schema format requirement for more flexible responses
- Added better error handling for both JSON and plain text responses

🚀 Yeeted your changes to the repo!
🌐 Remote detected! Pushing changes...
🚀 Changes successfully pushed to remote!
```

```
$ ./yeet.sh --dry-run
🧙 Summoning the commit genie...
🔍 DRY RUN MODE - Showing changes but not committing

📝 Changes that would be committed:
[diff output here]

🔮 Generating a witty commit message...

💬 Your commit message:

feat: 🔧 Add user authentication to backend API

- Added login/logout endpoints in auth.js that even a toddler could understand
- Created JWT token generation in tokens.js that might actually be secure this time
- Implemented password hashing in users.py because apparently "password123" isn't secure

🧪 Dry run complete - changes not committed
```

## License

MIT - Do whatever you want, just don't blame me when your colleagues get annoyed at your commit messages.