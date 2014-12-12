var config = require('./config/config.js');
var mongo = require('mongodb');
var monk = require('monk');

var conn_string = config.db.type + '://' + config.db.user + ':' + config.db.pass + '@' + config.db.dbAddress + ':' + config.db.port + '/' + config.db.db;
var client = monk(conn_string);

exports.client = client;