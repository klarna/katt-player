#!/usr/bin/env node
/*jshint node:true*/
var fs = require('fs'),
    ArgumentParser = require('argparse').ArgumentParser,
    express = require('express'),
    kattPlayer = require('./index'),
    pkg = require('./package'),
    parser,
    args,
    app,
    engine;

parser = new ArgumentParser({
    description: pkg.description,
    version: pkg.version,
    addHelp:true
});
parser.addArgument(
    [ '-e', '--engine' ],
    {
        help: 'Engine as built-in name or filename path (%(defaultValue)s)',
        defaultValue: 'linear'
    }
);
parser.addArgument(
    [ '-p', '--port' ],
    {
        help: 'Port number (%(defaultValue)d)',
        defaultValue: '1337'
    }
);
parser.addArgument(
    ['scenarios'],
    {
        help: 'Scenarios as files/folders',
        nargs: '+'

    }
);
parser.addArgument(
    ['--engineOptions'],
    {
        help: 'Options for the engine (JSON string) (%(defaultValue)s)',
        defaultValue: '{}'
    }
);
args = parser.parseArgs();
args.engineOptions = JSON.parse(args.engineOptions);

app = express();

if (kattPlayer.engines[args.engine]) {
    engine = kattPlayer.engines[args.engine](app, args.engineOptions);
} else if (fs.existsSync(args.engine)) {
    engine = require(args.engine);
}
kattPlayer(app, engine, {scenarios: args.scenarios});
console.log('Server start on http://127.0.0.1:' + args.port);

app.listen(args.port);
