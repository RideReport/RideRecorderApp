// create extension postgis;
// create extension CREATE EXTENSION postgis;
// create user honeybee PASSWORD 'An4mPzPrGffhavd9aT'
// create database honeybee owner honeybee

client.query("DROP TABLE IF EXISTS trips");
client.query("DROP TABLE IF EXISTS locations");

client.query('CREATE TABLE trips(
    id integer PRIMARY KEY NOT NULL,
    uuid char(36) NOT NULL,
    creation_date date NOT NULL,  
    activity_type integer,
    rating integer)');
    
var query = client.query('CREATE TABLE locations(
        id integer PRIMARY KEY NOT NULL,
        trip_id integer REFERENCES trips NOT NULL,
        post geometry NOT NULL,
        date date NOT NULL,        
        horizontal_accuracy integer,
        course float,
        speed float,
        activity_type integer,
        rating integer)'); 
query.on('end', function() { client.end(); });

