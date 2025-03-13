# 🚀 yeet

A lazy developer's git tool for generating snarky, hilarious commit messages with AI and automatically pushing changes.

## What is yeet?

`yeet` is a bash script that:

1. Stages all your changes (`git add .`)
2. Uses Ollama to generate a funny, sarcastic, but technically accurate commit message based on your code changes
3. Commits the changes with the generated message
4. Automatically pushes to your remote (if one exists)

All with a single command: `./yeet.sh`

## Requirements

- Bash
- Git
- [Ollama](https://ollama.com/) running locally
- `curl`
- `jq`

## Installation

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

## Customization

You can modify the script to change:

- The Ollama model used (change `MODEL_NAME="qwen:0.5b"` to your preferred model)
- The API endpoint (if you're running Ollama somewhere other than localhost)
- The commit message style by editing the prompt

## Examples

```
$ ./yeet.sh
🧙 Summoning the commit genie...
🔮 Generating a witty commit message...

💬 Your commit message:

feat: 🔧 Add user authentication to backend API

- Added login/logout endpoints that even a toddler could understand
- Created JWT token generation that might actually be secure this time
- Implemented password hashing because apparently "password123" isn't secure

🚀 Yeeted your changes to the repo!
🌐 Remote detected! Pushing changes...
🚀 Changes successfully pushed to remote!
```

## License

MIT - Do whatever you want, just don't blame me when your colleagues get annoyed at your commit messages.