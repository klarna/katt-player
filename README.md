# KATT player [![Build Status][2]][1]

KATT player is a mock HTTP server that replies with HTTP responses based on KATT blueprints."


## Install

```bash
npm install katt-player
```


## Usage

```bash
katt-player [--engine=linear] [--port=1337] FOLDER      # default engine is linear, port is 1337
katt-player [--engine=linear] [--port=1337] FILE1 FILE2 # accepts blueprints as well
katt-player --engine=path/to/engine.js FOLDER           # use a custom engine
NODE_ENV=development katt-player FOLDER                 # enable logging to console, instead of console.log
```

```coffee
kattPlayer = require 'katt-player'
app = kattPlayer kattPlayer.engines.linear
app.load 'FOLDER', 'FILE1', 'FILE2'
app.listen 1337
```


## License

[Apache 2.0](LICENSE)


  [1]: https://travis-ci.org/klarna/katt-player
  [2]: https://travis-ci.org/klatna/katt-player.png
