# asciinema-polish

A command-line Perl tool for processing and refining Asciinema terminal recording JSON files by adjusting inter-event idle times. This allows for smoother, faster, and more natural playback by applying context-aware timing rules to recorded input ("i") and output ("o") events. Ideal for cleaning up demos, tutorials or other terminal recordings that may have excessive delays or unnatural pauses.

## Why?

Asciinema captures real-time terminal interaction for accurate playback — but sometimes raw recordings contain unnatural pauses or slow outputs. Put simply, they lack polish. Rather than aiming for the perfect recording upfront, this tool intelligently optimizes event intervals to make playback seem polished and viewer-friendly.

## Features

- ⏱️ Adjusts idle time between events in asciinema recordings
- 🔄 Configurable handling of:
  - Output events following input (labeled "oi"), including simulation of character-by-character output
  - Long sequences of output-only events
  - Carriage return behavior (`\r`)
  - First input events following output blocks
- ⚙️ Fine-tuned via command-line parameters
- 🐞 Debug mode for viewing full event details
- 🧪 Works with both file input and STDIN

## Usage

```bash
perl asciinema-polish.pl [options] <asciinema-file.json>
```

If no file is specified, it reads from STDIN.

### Options

```text
--max-idle-time-io-event <seconds>        Max idle delay for "i/o" interactions (default: 0.1)
--idle-time-simulated-io-event <seconds>  Idle time for simulated character output (default: 0.066)
--idle-time-io-cr-event <seconds>         Idle time for carriage return output (default: 1)
--idle-time-first-i-event <seconds>       Idle time for first input after output (default: 0)
--max-idle-time-first-i-event <seconds>   Max idle time for first input (default: 1)
--max-idle-time-o-event <seconds>         Max idle time for consecutive output-only events (default: 3)
--debug                                   Enable verbose debug output
-h, --help                                Show usage info
```

## Example

```bash
cat asciinema-recording.json | perl asciinema-polish.pl --max-idle-time-o-event 1.5 >asciinema-recording-polished.json
```

## Useful tools

If you need to convert between different Asciinema formats, here are some useful tools.

### svg-term-cli

Create a Docker build for `svg-term-cli`, which converts Asciinema recordings to SVG format:

```dockerfile
cat <<EOF | docker build --tag=svg-term-cli -
FROM node:14-alpine

RUN chown -R node:node /usr/local

USER node

RUN npm install -g svg-term-cli

ENTRYPOINT ["/usr/local/bin/svg-term"]
EOF
```

Run it with:

```bash
docker run --rm -i svg-term-cli <asciinema-recording-polished >asciinema-recording-polished.svg
```

## License

MIT License  
© 2023–2024 Struan Bartlett

---

Let me know if you'd like a condensed one-line summary for your GitHub repo sidebar as well!