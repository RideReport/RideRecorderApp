// set variables for environment
var express = require('express'),
    bodyParser = require('body-parser');
var config = require('./config/config.js');
var path = require('path');
var trips = require('./routes/trips');

var utils = require('./utils/utils.js');
var db = require('./db.js');

var app = express();

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

app.get('/today', function(req, res) {
  res.render('today');
});

app.get('/trips', trips.getAll);
app.get('/trips/today', trips.getToday);
app.post('/trips/save', trips.save);

// Set server port
app.listen(config.server.httpListenPort);
console.log('server is running');

module.exports = app;