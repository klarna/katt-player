# KATT player [![Build Status][2]][1]

KATT player is a mock HTTP server that replies with HTTP responses
based on KATT blueprints.

KATT blueprints describe a scenario as a sequence of HTTP requests and
responses (the pair is called an HTTP transaction).

KATT player instantiates an HTTP server that loads these scenarios and,
given a reference to one of them, it can respond to a HTTP request
with the HTTP response prescribed by the referenced scenario.

The HTTP response is decided by a KATT player engine. Two engines are built-in:
one that validates the incoming requests against the blueprint (`linear-check`),
and one that doesn't and just blindly replies with the consecutive response
(`linear`). The former is the default.


## Built-in engines

These two engines will look at

* the request's cookie `katt_scenario` to decide which scenario to focus on
(e.g. basename of the scenario)
* the request's cookie `katt_transaction` to decide the request to match against
and which response is suitable (defaults to 0)

Both engines will automatically set a response header `Set-Cookie` in order
to advance the transaction count.

The `linear-check` engine can have the validation turned off temporarily via a
request header `X-KATT-Dont-Validate`.

You can see an example [here](test/katt-player-fixtures.coffee#L55).


## Custom engines

Custom engines may be implemented in order to add support for dealing with KATT
recall structures, for example.

There are no restrictions or requirements at all.


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
