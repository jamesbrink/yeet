# 🚀 yeet

A lazy developer's git tool for generating BRUTALLY RUDE commit messages with AI and automatically pushing changes, because you're too important to write your own damn commit messages.

## What the hell is yeet?

`yeet` is a bash script for developers who can't be bothered to:

1. Stage their changes manually (typing `git add .` is EXHAUSTING)
2. Come up with meaningful commit messages (thinking is HARD)
3. Push their code (SO MANY KEYSTROKES)

Instead, it:
1. Stages all your changes (`git add .`) because selection is for suckers
2. Uses Ollama to generate a hilariously offensive, yet technically accurate commit message that will make your coworkers question your sanity
3. Intelligently falls back to smart default messages when the AI is being as lazy as you are
4. Commits your questionable code with the generated message
5. Automatically pushes to your remote so everyone can witness your shame immediately

All with a single command: `./yeet.sh` - because typing more would be cruel and unusual punishment.

## Requirements

- Bash (if you don't have this, how are you even alive?)
- Git (duh)
- [Ollama](https://ollama.com/) running locally (no, we won't support ChatGPT - pay for your own API keys, cheapskate)
- `curl` (it's 2025, how do you not have curl?)
- `jq` (because parsing JSON with grep and sed is for masochists)

## Installation

### The "I'm a serious developer" way (narrator: you're not):

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

### The "I just want this to work because I have deadlines" way:

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
   Who needs proper installation when you can just copy-paste like a Stack Overflow champion?

## Usage

Just run:

```bash
./yeet.sh
```

Or if you created the symlink (look at you, being all professional):

```bash
yeet
```

### Command Line Options (for the 0.1% who actually read documentation)

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

### Dry run mode (for the pathologically cautious)

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
4. Does NOT stage or commit any changes (you coward)

## Customization (as if you'll ever bother)

You can modify the script to change:

- The Ollama model used (change `MODEL_NAME="llama3.2:1b"` to your preferred model)
- The API endpoint (if you're running Ollama somewhere other than localhost)
- The commit message style by editing the prompt (make it even more offensive, we dare you)
- The timeout for API calls (default is 120 seconds, because waiting is torture)
- The fallback message patterns in the script (it analyzes your changes to create relevant messages)

## Features (that you'll never fully appreciate)

### Smart Commit Message Generation

- Generates rude, offensive commit messages that will make HR send you concerned emails
- Analyzes added/removed lines to create relevant titles that actually describe your changes
- Falls back to intelligent defaults when the AI generates generic messages (it's sometimes as lazy as you are)
- Properly formats commit messages with conventional commit types (because standards matter, even in chaos)

### Improved Error Handling (because your errors need handling)

- Handles both JSON and plain text responses from the LLM
- Gracefully recovers from API errors or timeouts (unlike your relationships)
- Provides meaningful fallback messages based on file changes
- Automatically pulls missing models when needed (we anticipated your incompetence)

## Examples (of your future shame)

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

MIT - Do whatever you want with this abomination. When your coworkers stage an intervention about your commit messages or HR asks why you called your own code "a festering pile of legacy spaghetti," that's on you, buddy.