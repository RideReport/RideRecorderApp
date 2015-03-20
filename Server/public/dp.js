!function() {
	var global = this
	global.DatePicker = ctor;

	ctor.VERSION = '0.5.0';

	ctor.prototype =
		{ show: show
		, hide: hide
		, toggle: toggle

		, render: render
		, on: on
		, off: off

		, emit: emit
		, trigger: emit

		, resolveSelector: resolveSelector
		, getOffset: getOffset
		, rerender: rerender
		, renderControls: renderControls
		, renderHeaderLabels: renderHeaderLabels
		, renderDateCells: renderDateCells
		, nextMonth: nextMonth
		, prevMonth: prevMonth
		, dateCellClicked: dateCellClicked

		, _removeFloater: _removeFloater
		};

	ctor.getCurrentMonth = getCurrentMonth;
	ctor.getOverflowNext = getOverflowNext;
	ctor.getOverflowPrev = getOverflowPrev;
	ctor.parseDate = parseDate;
	ctor.formatDate = formatDate;

	function ctor(options) {
		// It should not matter if "new" keyword is used!
		if(this === global) {
			return new ctor(options);
		}

		this.options =
			{ weekStart: 1 // 1 == monday
			, elm: null
			, weekdays: [ 'su', 'mo', 'tu', 'we', 'th', 'fr', 'sa' ]
			, months:
			  [ 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'
			  , 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
			  ]
			, buttons: { next: 'Next', prev: 'Prev', close: 'x' }
			, date: new Date()
			, dateFormat: 'y/m/d'
			, floatingOverlay: false
			};

		this._events = {};
		this._elms = {};

		if(options) {
			_(options).keys().each(function(key) {
				this.options[key] = options[key];
			}, this);
		}

		_(this).bindAll('nextMonth', 'prevMonth', 'dateCellClicked');
	};

	function on(event, callback) {
		if(typeof(callback) != 'function') {
			throw new Error('Second argument needs to be a function');
		}
		if(!this._events[event]) {
			this._events[event] = [];
		}
		this._events[event].push(callback);

		return this;
	};
	function off(event, callback) {
		if(!this._events[event]) {
			return;
		}
		var index
		while((index = this._events[event].indexOf(callback)) > -1) {
			this._events[event].splice(index, 1);
		}

		return this;
	};
	function emit(event) {
		var listeners = this._events[event]
		  , args = Array.prototype.slice.call(arguments, 1)

		if(listeners) {
			_(listeners).each(function(cb) {
				cb.apply(null, args);
			});
		}

		return this;
	};

	function dateCellClicked(e) {
		var elm = e ? e.target : event.srcElement
		  , date = elm.getAttribute('data-date')
		  , dateFormat = this.options.dateFormat

		if(!date) {
			return;
		}

		date = date.split('/');

		this.options.date.setFullYear(date[0]);
		this.options.date.setMonth(date[1]-1);
		this.options.date.setDate(date[2]);

		if(this._elms.input) {
			this._elms.input.value = formatDate(this.options.date, dateFormat);
		}

		this._visibleDate = this.options.date;

		this.emit('change', this.options.date, this);

		if(this._elms.floater) {
			this.hide();
			return;
		}

		this.rerender();
	};
	function nextMonth() {
		this._visibleDate.setDate(1);
		this._visibleDate.setMonth(this._visibleDate.getMonth() + 1);

		this.rerender();
	};
	function prevMonth() {
		this._visibleDate.setDate(1);
		this._visibleDate.setMonth(this._visibleDate.getMonth() - 1);

		this.rerender();
	};

	function rerender() {
		if(!this.container) {
			return this;
		}

		var frag = this.render()

		this.container.innerHTML = '';
		this.container.appendChild(frag);

		return this;
	};
	function render() {
		var frag = document.createDocumentFragment()
		  , container = createElement('div', { className: 'fzk-dp-wdgt' })
		  , now = this._visibleDate || this.options.date
		  , overlay = this._elms.floater && this.options.floatingOverlay
		    ? createElement('div', { className: 'fzk-dp-overlay' })
		    : null
		  , showCloseButton = !!this._elms.floater
		  , hide = _(this.hide).bind(this)

		if(!this._visibleDate) {
			this._visibleDate = new Date(now.getTime());
		}

		if(overlay) {
			frag.appendChild(overlay);
		}

		frag.appendChild(container);

		container.appendChild(this.renderControls(showCloseButton));
		container.appendChild(this.renderHeaderLabels());
		container.appendChild(this.renderDateCells());

		// Closing the overlay
		if(overlay) {
			overlay.onclick = hide;
		}
		if(showCloseButton) {
			$$('.fzk-dp-btn-cls', frag).onclick = hide;
		}

		// Navigating between months
		$$('.fzk-dp-btn-nxt', frag).onclick = this.nextMonth;
		$$('.fzk-dp-btn-prv', frag).onclick = this.prevMonth;

		// Selecting a date
		$$('.fzk-dp-cells', frag).onclick = this.dateCellClicked;

		return frag;
	};
	function renderControls(showCloseButton) {
		var div = createElement('div', { className: 'fzk-dp-ctrls' })
		  , now = this._visibleDate
		div.appendChild(createElement('label',
			{ className: 'fzk-dp-month'
			, innerHTML: this.options.months[now.getMonth()] + ' ' + now.getFullYear()
			}
		));
		div.appendChild(createElement('button',
			{ className: 'fzk-dp-btn-prv'
			, innerHTML: this.options.buttons.prev
			}
		));
		div.appendChild(createElement('button',
			{ className: 'fzk-dp-btn-nxt'
			, innerHTML: this.options.buttons.next
			}
		));
		if(showCloseButton) {
			div.appendChild(createElement('button',
				{ className: 'fzk-dp-btn-cls'
				, innerHTML: this.options.buttons.close
				}
			));
		}
		return div;
	};
	function renderHeaderLabels() {
		var div = createElement('div', { className: 'fzk-dp-lbls' })
		_(getWeekdays(this.options)).each(function(weekday) {
			div.appendChild(createElement('label',
				{ className: 'fzk-dp-cell'
				, innerHTML: weekday
				}
			));
		});
		return div;
	};
	function renderDateCells() {
		var div = createElement('div', { className: 'fzk-dp-cells' })

		  , date = this._visibleDate
		  , dateStr =
		    date.getFullYear() + '/'
		    + padDate(date.getMonth() +1) + '/'
		    + padDate(date.getDate())

		  , selected = this.options.date
		  , selectedStr =
		    selected.getFullYear() + '/'
		    + padDate(selected.getMonth() +1) + '/'
		    + padDate(selected.getDate())

		  , now = new Date()
		  , nowStr =
		    now.getFullYear() + '/'
		    + padDate(now.getMonth() +1) + '/'
		    + padDate(now.getDate())

		_(getOverflowPrev(date, this.options)).each(addToDiv('fzk-dp-cell-prv'));
		_(getCurrentMonth(date)).each(addToDiv(''));
		_(getOverflowNext(date, this.options)).each(addToDiv('fzk-dp-cell-nxt'));

		return div;

		function addToDiv(className) {
			return function(date) {
				var opts =
					{ className: 'fzk-dp-cell ' + className
					, innerHTML: date.date
					}
				  , data = { date: date.fullDate }
				if(nowStr === date.fullDate) {
					opts.className += ' fzk-dp-cell-today';
				}
				if(selectedStr === date.fullDate) {
					opts.className += ' fzk-dp-cell-current';
				}
				div.appendChild(createElement('span', opts, data));
			};
		};
	};

	/**
	 * This method is static, and exposed as static
	 */
	function getWeekdays(opts) {
		var days = []
		  , i
		  , current = opts.weekStart

		for(i = 0; i < 7; i++) {
			days[i] = opts.weekdays[current++];
			if(current == 7) current = 0;
		};

		return days;
	};

	/**
	 * This method is static, and exposed as static
	 */
	function getCurrentMonth(now, opts) {
		var year = now.getFullYear()
		  , month = padDate(now.getMonth() + 1)
		  , day = now.getDate()
		  // we do not need to subtract one here, since that has already been done
		  , lastDay = new Date(year, +month, 0).getDate()
		  , days = []
		  , i

		for(i = 1; i <= lastDay; i++) {
			var date = padDate(i)
			days.push(
				{ date: date
				, fullDate: year + '/' + month + '/' + date
				, current: day === i
				}
			);
		}

		return days;
	};

	/**
	 * This method is static, and exposed as static
	 */
	function getOverflowPrev(now, opts) {
		var firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
		if(firstDayOfMonth.getDay() == opts.weekStart) {
			return [];
		}

		var previousMonth = new Date(now.getFullYear(), now.getMonth(), 0)
		  , year = previousMonth.getFullYear()
		  , month = padDate(previousMonth.getMonth() + 1)
		  , lastDate = previousMonth.getDate()

		  , currentDay = firstDayOfMonth.getDay()
		  , results = []
		  , i
		  , l = currentDay - opts.weekStart

		if(l < 0) l += 7;

		for(i = 0; i < l; i++) {
			var currentDate = (lastDate - l + i + 1).toString()
			results.push(
				{ date: currentDate
				, fullDate: year + '/' + month + '/' + currentDate
				}
			);
		}
		return results;
	};

	/**
	 * This method is static, and exposed as static
	 */
	function getOverflowNext(now, opts) {
		var firstDayOfNextMonth = new Date(now.getFullYear(), now.getMonth()+1, 1)
		if(firstDayOfNextMonth.getDay() == opts.weekStart) {
			return [];
		}

		var year = firstDayOfNextMonth.getFullYear()
		  , month = padDate(firstDayOfNextMonth.getMonth() +1)

		  , result = []
		  , i = firstDayOfNextMonth.getDay() - opts.weekStart
		  , l = 7
		  , current = 1

		if(i < 0) {
			i += 7
		}

		for(; i < l; i++) {
			var date = padDate(current++)
			result.push(
				{ date: date
				, fullDate: year + '/' + month + '/' + date
				}
			);
		}

		return result;
	};

	/**
	 * This method is static
	 */
	function padDate(date) {
		date = +date;
		return date < 10 ? '0' + date : date.toString();
	};

	function show(selector) {
		this.resolveSelector(selector || this.selector || this.options.elm);

		if(this._elms.input) {
			this.options.date =
				parseDate(this._elms.input.value, this.options.dateFormat) || this.options.date;
		}
		if(!this._visibleDate) {
			this._visibleDate = new Date(this.options.date.getTime());
		}

		ensureClassName(this.container, 'fzk-dp');
		this.rerender();
		this.showing = true;

		return this.emit('show', this);
	};
	function hide() {
		if(!this.showing) {
			return this;
		}

		this.container.innerHTML = '';
		this._removeFloater();
		this.showing = false;
		this._visibleDate = null;
		this.selector = null;

		return this.emit('hide', this);
	};
	function toggle(selector) {
		if(this.showing && (!selector || this.selector === selector)) {
			return this.hide();
		}
		return this.show(selector);
	};

	function _removeFloater() {
		if(this._elms.floater) {
			this._elms.floater.parentNode.removeChild(this._elms.floater);
			this._elms.floater = null;
		}
	};

	function resolveSelector(sel) {
		this.container = (typeof(sel) === 'string')
			? $$(sel)
			: sel;

		if(!this.container) {
			throw new Error('"' + sel + '" does not resolve to an element!');
		}
		this.selector = sel;

		if(this.container.tagName.toLowerCase() === 'input') {
			this._elms.input = this.container;
		}
		this._removeFloater();
		if(this._elms.input) {
			if(this._elms.input.value) {
				this._visibleDate = null;
				this.options.date =
					ctor.parseDate(this._elms.input.value, this.options.dateFormat);
			}

			this._elms.floater = this.container
				= createElement('div', { className: 'fzk-dp-float' });
			document.body.appendChild(this._elms.floater);
			var offset = getOffset(this._elms.input);
			this.container.style.left = offset.left + 'px';
			this.container.style.top = (offset.top + offset.height) + 'px';
		}
	};

	/**
	 * This code is most graciously stolen from jQuery:
	 * https://github.com/jquery/jquery/blob/7c23b77af2477417205/src/offset.js
	 */
	function getOffset(elm) {
		var box = _(elm.getBoundingClientRect()).clone()
		  , doc = elm.ownerDocument
		  , body = doc.body
		  , docElm = doc.documentElement

		  , scroll =
		    { top: docElm.scrollTop || body.scrollTop
		    , left: docElm.scrollLeft || body.scrollLeft
		    }
		  , client =
		    { top: docElm.clientTop || body.clientTop || 0
		    , left: docElm.clientLeft || body.clientLeft || 0
		    }

		if(box.height === undefined) {
			box.height = ie8.height(elm);
		}

		return (
			{ top: box.top + scroll.top - client.top
			, left: box.left + scroll.left - client.left
			, width: box.width
			, height: box.height
			}
		);
	};

	var ie8 = {};
	ie8.height = function(elm) {
		var curStyle = elm.currentStyle
		  , suffixes = [ 'Top', 'Bottom' ]
		  , prefixes = [ 'border', 'padding' ]
		  , height = elm.offsetHeight
		  , i
		  , j

		for(i = 0; i < 2; i++) {
			for(j = 0; j < 2; j++) {
				height -= parseFloat(curStyle[prefixes[i] + suffixes[j]]) || 0;
			}
		}
		return height;
	};

	/**
	 * This method is static, and exposed as static
	 */
	function parseDate(str, format) {
		if(!str) {
			return null;
		}
		if(!format) {
			format = 'y/m/d';
		}

		var keys = {}
		  , i = 1
		  , keyMap =
		    { m: 'month', M: 'month'
		    , d: 'day', D: 'day'
		    , y: 'year', Y: 'year'
		    }
		  , parser = new RegExp(format.replace(/[yYdDmM]/g, parseDate))
		  , date = str.match(parser)

		if(!date || date.length != 4 || !keys.day || !keys.month || !keys.year) {
			return null;
		}

		if(date[keys.year].length == 2) {
			date[keys.year] = (date[keys.year] < 25 ? '20' : '19') + date[keys.year];
		}

		return new Date(date[keys.year], date[keys.month]-1, date[keys.day]);

		// This function is responsible for matching capture groups against
		// keys
		function parseDate(key) {
			keys[keyMap[key]] = i++;
			return '(\\d+)';
		};
	};

	/**
	 * This method is static, and exposed as static
	 */
	function formatDate(date, format) {
		return format.replace(/([YyMmDd])/g, function(key) {
			switch(key) {
				case 'd':
					return padDate(date.getDate());
				case 'D':
					return date.getDate();
				case 'm':
					return padDate(date.getMonth()+1);
				case 'M':
					return date.getMonth()+1;
				case 'y':
					return date.getFullYear();
				case 'Y':
					return date.getFullYear().toString().substring(2);
			}
		});
	};

	function createElement(tag, opts, data) {
		var elm = document.createElement(tag);
		if(opts) {
			_(opts).keys().each(function(key) {
				elm[key] = opts[key];
			});
		}
		if(data) {
			_(data).keys().each(function(key) {
				elm.setAttribute('data-' + key, data[key]);
			});
		}
		return elm;
	};

	function ensureClassName(elm, className) {
		if(!new RegExp('(^| )' + className + '($| )')
			.test(elm.className))
		{
			elm.className += ' ' + className;
		}
	}

	/**
	 * This is a (very!) raw implementation of underscore.
	 * It takes plenty of assumptions in order to be lean!
	 */
	function _(obj) {
		return (
			{ bind: bind
			, bindAll: bindAll
			, keys: keys
			, each: forEach
			, clone: clone
			}
		);

		function clone() {
			var cp = {}
			  , key
			for(key in obj) {
				cp[key] = obj[key];
			}
			return cp;
		};

		// keys() assumes obj to be any object
		function keys() {
			var keys = []
			  , key
			for(key in obj) {
				if(obj.hasOwnProperty(key)) {
					keys.push(key);
				}
			}
			return _(keys);
		};

		// bind() assumes obj to be a function
		function bind(ctx) {
			return function() {
				return obj.apply(ctx, arguments);
			};
		};

		function bindAll(methods) {
			methods = Array.prototype.slice.call(arguments)
			_(methods).each(function(func) {
				obj[func] = _(obj[func]).bind(obj);
			});
		};

		function forEach(func, ctx) {
			var i = 0
			  , l = obj.length
			for(; i < l; i++) {
				func.call(ctx, obj[i], i, obj);
			}
		};
	};

	/**
	 * These two helpers are inverted from what the webkit console expects
	 * (which was derived from the Prototype framework) in order to match the
	 * jQuery behaviour more closely.
	 *
	 * $: Acts more or less like jQuery, except it is based on querySelectorAll.
	 * $$: Basically an optimized version of $(sel, scope)[0].
	 */
	function $(selector, scope) {
		return Array.prototype.slice.call(
			(scope || document).querySelectorAll(selector));
	};
	function $$(selector, scope) {
		return (scope || document).querySelector(selector);
	};
}();
