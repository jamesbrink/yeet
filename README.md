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

### The "I read documentation and take myself seriously" method:

1. Clone this repository like the Git wizard you pretend to be:
   ```bash
   git clone https://github.com/jamesbrink/yeet.git
   cd yeet
   chmod +x yeet.sh
   ```

2. Install Ollama because apparently you can't be bothered to write your own commit messages:
   ```bash
   # Follow instructions at https://ollama.com/ or just Google it, jeez
   # Start Ollama (this app won't magically run itself)
   ollama serve
   # Pull the default model (yes, we need to download a whole AI model for commit messages)
   ollama pull llama3.2:1b
   ```

3. Optionally, create a symlink so you can be lazy from ANY directory:
   ```bash
   sudo ln -s "$(pwd)/yeet.sh" /usr/local/bin/yeet
   ```

### The "I'm in a hurry and my boss is watching" express method:

1. Just grab the damn script directly:
   ```bash
   # From ANY directory you want to use yeet in
   curl -o yeet.sh https://raw.githubusercontent.com/jamesbrink/yeet/main/yeet.sh
   chmod +x yeet.sh    # Don't forget this or you'll be back asking why it doesn't work
   ```

2. Make sure you have the required tools (we can't work miracles with nothing):
   ```bash
   # On your fancy MacBook Pro
   brew install ollama jq curl
   
   # On your company's ancient Ubuntu server
   sudo apt install jq curl
   # Get Ollama from https://ollama.com/ (we're not explaining how, figure it out)
   ```

3. Start Ollama and get the model (yes, both steps are required, shocking):
   ```bash
   # Start the Ollama server (the & runs it in the background so you can continue being unproductive)
   ollama serve &
   
   # Get the model (this might take a while on your potato internet)
   ollama pull llama3.2:1b
   ```

4. That's literally it. Run `./yeet.sh` in any directory with a git repo, and watch the magic happen.
   If this is too complicated for you, maybe stick to sending code changes as screenshots in Slack.

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