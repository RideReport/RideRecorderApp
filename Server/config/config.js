module.exports = {
	server : {
		serverAddress 	: '127.0.0.1',
		httpListenPort 	: 8080,
		httpsListenPort	: 8443,
		urlBase			: '/api/v1',
		useHTTPS 		: false,
	},
	db: {
		dbAddress : '127.0.0.1',
		type	: 'postgres',
		port	: 5432,
		user	: 'ride',
		pass	: 'An4mPzPrGffhavd9aT',
		db		: 'ride'
	},
}
