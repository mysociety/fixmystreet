/**
 * Plugin: jquery.zRSSFeed
 * 
 * Version: 1.0.1m
 * (c) Copyright 2010, Zazar Ltd
 * 
 * Description: jQuery plugin for display of RSS feeds via Google Feed API
 *              (Based on original plugin jGFeed by jQuery HowTo)
 * 
 * History:
 * 1.0.1 - Corrected issue with multiple instances
 * 1.0.1m - fixed content showing issue - PL
 *
 **/

(function($){

	var current = null; 
	
	$.fn.rssfeed = function(url, options) {	
	
		// Set pluign defaults
		var defaults = {
			limit: 10,
			header: false,
			titletag: 'h4',
			date: true,
			content: true,
			snippet: true,
			showerror: true,
			errormsg: '',
			key: null
		};  
		var options = $.extend(defaults, options); 
		
		// Functions
		return this.each(function(i, e) {
			var $e = $(e);
			
			// Add feed class to user div
			if (!$e.hasClass('rssFeed')) $e.addClass('rssFeed');
			
			// Check for valid url
			if(url == null) return false;

			// Create Google Feed API address
			var api = "http://ajax.googleapis.com/ajax/services/feed/load?v=1.0&callback=?&q=" + url;
			if (options.limit != null) api += "&num=" + options.limit;
			if (options.key != null) api += "&key=" + options.key;

			// Send request
			$.getJSON(api, function(data){
				
				// Check for error
				if (data.responseStatus == 200) {
	
					// Process the feeds
					_callback(e, data.responseData.feed, options);
				} else {

					// Handle error if required
					if (options.showerror)
						if (options.errormsg != '') {
							var msg = options.errormsg;
						} else {
							var msg = data.responseDetails;
						};
						$(e).html('<div class="rssError"><p>'+ msg +'</p></div>');
				};
			});				
		});
	};
	
	// Callback function to create HTML result
	var _callback = function(e, feeds, options) {
		if (!feeds) {
			return false;
		}
		var html = '';	
		var row = 'first';	
		
		// Add header if required
		if (options.header)
			html +=	'<h3 class="news-feed-header">' +
				'<a href="'+ feeds.link +'" title="'+ feeds.description +'">'+ feeds.title +'</a>' +
				'</h3>';
			
		// Add body
		html += '<ul class="rss-list">';
		
		// Add feeds
		for (var i=0; i<feeds.entries.length; i++) {
			
			// Get individual feed
			var entry = feeds.entries[i];
			
			// Format published date
			var entryDate = new Date(entry.publishedDate);
			var pubDate = entryDate.toLocaleDateString() + ' ' + entryDate.toLocaleTimeString();
			
			// Add feed row
			html += '<li class="rss-list-item-'+ row +'">' + 
				'<'+ options.titletag +'><a href="'+ entry.link +'" title="View this feed at '+ feeds.title +'">'+ entry.title +'</a></'+ options.titletag +'>'
			if (options.date) html += '<h5>'+ pubDate +'</h5>'
			if (options.content) {
			
				// Use feed snippet if available and optioned
				if (options.snippet != '') {
					var content = entry.contentSnippet;
				} else if (entry.contentSnippet != '') {
					var content = '';
				}
				else {
					var content = '';
				}
				
				html += '<p class="snippet">'+ content +'</p>'
			}
			
			html += '</li>';
			
			// Alternate row classes
			if (row = 'first') {
				row = 'sub';
			} else {
				if (row == 'first') {
					row = 'even';
				} else {
					row = 'first';
				}
			
			}
		}
		
		html += '</ul>'
		
		$(e).html(html);
	};
})(jQuery);
