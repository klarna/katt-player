#!/usr/bin/env node
/*jshint node:true*/
var fs = require('fs'),
    ArgumentParser = require('argparse').ArgumentParser,
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
        help: 'Engine as built-in name or filename path',
        defaultValue: 'linear'
    }
);
parser.addArgument(
    [ '-p', '--port' ],
    {
        help: 'Port number',
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
args = parser.parseArgs();

if (kattPlayer.engines[args.engine]) {
    engine = kattPlayer.engines[args.engine];
} else if (fs.existsSync(args.engine)) {
    engine = require(args.engine);
}
app = kattPlayer(engine, {scenarios: args.scenarios});
if (process.env.NODE_ENV !== 'development') {
    console.log('Server start on http://127.0.0.1:' + args.port);
}
app.listen(args.port);
