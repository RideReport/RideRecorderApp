// set variables for environment
var express = require('express');
var config = require('./config/config.js');
var mongo = require('mongodb');
var monk = require('monk');
var path = require('path');
var trips = require('./routes/trips');

var conn_string = config.db.type + '://' + config.db.user + ':' + config.db.pass + '@' + config.db.dbAddress + ':' + config.db.port + '/' + config.db.db;
var client = monk(conn_string);

var app = express();

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.static('public'));

app.get('/', function(req, res) {
  res.render('index');
});

app.get('/trips', trips.getAll);
app.post('/trips/:id', trips.new);

// Set server port
app.listen(4000);
console.log('server is running');