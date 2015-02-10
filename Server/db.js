// Mongo Database

var config_mongo = require('./config/config_mongo.js');
var mongo = require('mongodb');
var monk = require('monk');

var mongo_conn_string = config_mongo.db.type + '://' + config_mongo.db.user + ':' + config_mongo.db.pass + '@' + config_mongo.db.dbAddress + ':' + config_mongo.db.port + '/' + config_mongo.db.db;
var mongo_client = monk(mongo_conn_string);

// PG Database
var pg = require('pg').native;
var config = require('./config/config.js');

var pg_conn_string = config.db.type + '://' + config.db.user + ':' + config.db.pass + '@' + config.db.dbAddress + ':' + config.db.port + '/' + config.db.db;
var pg_client = new pg.Client(pg_conn_string)

exports.client = pg_client;
exports.mongo_client = mongo_client;