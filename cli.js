#!/usr/bin/env node
/*jshint node:true*/
var kattPlayer = require('./index.js'),
    fs = require('fs'),
    argv,
    app,
    engine;

argv = require('optimist')
       .usage('Usage:$0 [--engine=linear] [--port=1337] FOLDER1 FILE2')
       .options('engine', {
           'default': 'linear'
       })
       .options('port', {
           'default': '1337'
       })
       .check(function(argv) {
           if (argv._.length === 0) {
               throw new Error('Please give at least one KATT blueprint');
           }
       })
       .argv;

if (kattPlayer.engines[argv.engine]) {
    engine = kattPlayer.engines[argv.engine];
} else if (fs.existsSync(argv.engine)) {
    engine = require(argv.engine);
}
app = kattPlayer(engine);
app.load.apply(this, argv._);
console.log('Server start on http://127.0.0.1:' + argv.port);
app.listen(argv.port);
