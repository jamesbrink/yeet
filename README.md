# 🚀 yeet

A lazy developer's git tool for generating BRUTALLY RUDE commit messages with AI and automatically pushing changes.

## What is yeet?

`yeet` is a bash script that:

1. Stages all your changes (`git add .`)
2. Uses Ollama to generate a funny, offensive, but technically accurate commit message based on your code changes
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
   ollama pull llama3.2:1b
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
   ollama pull llama3.2:1b
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

### Command Line Options

```
Options:
  --dry-run, -d       Show what would be committed but don't actually commit
  --model, -m NAME    Use a specific Ollama model (default: llama3.2:1b)
  --timeout, -t SECS  Set API timeout in seconds (default: 120)
  --version, -v       Show version information
  --help, -h          Show this help message

Environment variables:
  OLLAMA_HOST         Set Ollama host (default: localhost)
  OLLAMA_PORT         Set Ollama port (default: 11434)
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

## Customization

You can modify the script to change:

- The Ollama model used (change `MODEL_NAME="llama3.2:1b"` to your preferred model)
- The API endpoint (if you're running Ollama somewhere other than localhost)
- The commit message style by editing the prompt
- The timeout for API calls (default is 120 seconds)
- The fallback message patterns in the script (it analyzes your changes to create relevant messages)

## Features

### Smart Commit Message Generation

- Generates rude, offensive commit messages based on actual code changes
- Analyzes added/removed lines to create relevant titles
- Falls back to intelligent defaults when the AI generates generic messages
- Properly formats commit messages with conventional commit types

### Improved Error Handling

- Handles both JSON and plain text responses from the LLM
- Gracefully recovers from API errors or timeouts
- Provides meaningful fallback messages based on file changes
- Automatically pulls missing models when needed

## Examples

```
$ ./yeet.sh
🧙 Summoning the commit demon to judge your pathetic code...
🔮 Generating an insult for your crappy code...

💬 Your insulting commit message (you deserve it):

feat: ✨ Fixed your embarrassing commit message format

You somehow managed to screw up 1 file(s):
- yeet.sh

🚀 Yeeted your crappy changes to the repo! Hope they don't break everything!
🌐 Remote detected! Inflicting your garbage on everyone else...
💩 Successfully dumped your trash into the remote! Your teammates will be THRILLED.
```

```
$ ./yeet.sh --dry-run
🧙 Summoning the commit demon to judge your pathetic code...
🔍 DRY RUN MODE - I'll show you how bad your changes are without committing them

📝 This is the crap you want to commit:
[diff output here]

🔮 Generating an insult for your crappy code...

💬 Your insulting commit message (you deserve it):

fix: 🐛 Fixed your embarrassing bug in auth.js api.js users.py 

Did you seriously think this would work? It took you THIS long to figure out how to validate a damn email? Delete your IDE.

🧪 Dry run complete - saved your ass from committing that garbage. You're welcome.
```

## License

MIT - Do whatever you want, just don't blame me when your colleagues get offended by your commit messages.
