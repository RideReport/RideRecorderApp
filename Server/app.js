// set variables for environment
var express = require('express');
var bodyParser = require('body-parser');
var config = require('./config/config.js');
var path = require('path');
var trips = require('./routes/trips');
var dashboard = require('./routes/dashboard');

var db = require('./db.js');

var app = express();

app.use(express.compress());
app.use(bodyParser.json({limit: '1mb'}));
app.use(bodyParser.urlencoded({
    extended: true
}));
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.static('public'));

app.get('/', function(req, res) {
  res.render('index');
});

app.get('/utPjfzYgJGp69modBo', function(req, res) {
  res.render('download');
});

app.get('/beta/u1z3', function(req, res) {
  res.render('download');
});

app.get('/map', function(req, res) {
  res.render('map');
});

app.get('/date/:date', function(req, res) {
  res.locals.date = req.params.date
  res.render('date');
});

//app.get('/dashboard', dashboard.show);
app.get('/trips', trips.getAll);
app.get('/trips/date/:date', trips.getTripsOnDate);
app.post('/trips/save', trips.save);

// Set server port
app.listen(config.server.httpListenPort);
console.log('server is running');

module.exports = app;
