function GetContent(url) {
	var api = "//query.yahooapis.com/v1/public/yql?q=" + encodeURIComponent("select * from xml where url = '" + url + "'") + "&format=json";

	$.getJSON(api, function(data){
		if (data.query.count > 0) {
			for (var i = 0; i < data.query.results.rss.channel.item.length; i++) {
				// get item and thumbnail from feed item
				item = data.query.results.rss.channel.item[i];
				itemThumb = item.content.thumbnail;
				//build up item to insert
				rssLink = '<a href="' + item.link + '"><img class="featured-news-image" src="' + itemThumb.url + '" alt="' + item.title + '" height>' + '</a>';
				rssCapt = '<div class="carousel-caption"><h3><a href="' + item.link + '">' + item.title + '</a></h3></div>';
				rssSpan = '<span class="wrap" style="height:300px;">' + rssLink + rssCapt + '</span>';
				rssItem = '<div class="item slide pane-' + (i + 1) + '">' + rssSpan + '</div>';
				jQuery('#latest-news').append(rssItem);
			}
			// after our JSON has loaded successfully, then we begin to slide
			jQuery('#latest-news .slide').first().addClass('active');
			jQuery('#featured-slider').carousel('pause');
		}
		else {
			// no content from the feed, log data for analysis and show message
			console.log( data );
			jQuery('#latest-news').append('<div class="item slide"><span class="wrap" style="height:300px;"></span><div class="carousel-caption"><h3>Sorry, something went wrong when we tried to get those stories for you.</h3></div></div>');
		}
	});
}