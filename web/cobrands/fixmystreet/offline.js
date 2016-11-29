fixmystreet.offlineBanner = (function() {
    var toCache = 0;
    var cachedSoFar = 0;

    return {
        make: function(offline) {
            var banner = ['<div class="top_banner top_banner--offline"><p><span id="offline_saving">'];
            banner.push('</span></p></div>');
            banner = $(banner.join(''));
            banner.prependTo('.content');
            banner.hide();
        },
        startProgress: function(l) {
            $('.top_banner--offline').slideDown();
            toCache = l;
            $('#offline_saving').html('Saving reports offline &ndash; <span>0</span>/' + toCache + '.');
        },
        progress: function() {
            cachedSoFar += 1;
            if (cachedSoFar === toCache) {
                $('#offline_saving').text('Reports saved offline.');
            } else {
                $('#offline_saving span').text(cachedSoFar);
            }
        }
    };
})();

fixmystreet.offlineData = (function() {
    var data;

    function getData() {
        if (data === undefined) {
            data = JSON.parse(localStorage.getItem('offlineData'));
            if (!data) {
                data = { cachedReports: {} };
            }
        }
        return data;
    }

    function saveData() {
        localStorage.setItem('offlineData', JSON.stringify(getData()));
    }

    return {
        getCachedUrls: function() {
            return Object.keys(getData().cachedReports);
        },
        isIndexed: function(url, lastupdate) {
            if (lastupdate) {
                return getData().cachedReports[url] === lastupdate;
            }
            return !!getData().cachedReports[url];
        },
        add: function(url, lastupdate) {
            var data = getData();
            data.cachedReports[url] = lastupdate || "-";
            saveData();
        },
        remove: function(urls) {
            var data = getData();
            urls.forEach(function(url) {
                delete data.cachedReports[url];
            });
            saveData();
        }
    };
})();

fixmystreet.cachet = (function(){
    var urlsInProgress = {};

    function cacheURL(url, type) {
        urlsInProgress[url] = 1;

        var ret;
        if (type === 'image') {
            ret = $.Deferred(function(deferred) {
                var oReq = new XMLHttpRequest();
                oReq.open("GET", url, true);
                oReq.responseType = "blob";
                oReq.onload = function(oEvent) {
                    var blob = oReq.response;
                    var reader = new window.FileReader();
                    reader.readAsDataURL(blob);
                    reader.onloadend = function() {
                        localStorage.setItem(url, reader.result);
                        delete urlsInProgress[url];
                        deferred.resolve(blob);
                    };
                };
                oReq.send();
            });
        } else {
            ret = $.ajax(url).pipe(function(content, textStatus, jqXHR) {
                localStorage.setItem(url, content);
                delete urlsInProgress[url];
                return content;
            });
        }
        return ret;
    }

    function cacheReport(item) {
        return cacheURL(item.url, 'html').pipe(function(html) {
            var $reportPage = $(html);
            var imagesToGet = [
                item.url + '/map' // Static map image
            ];
            $reportPage.find('img').each(function(i, img) {
                if (img.src.indexOf('/photo/') === -1 || fixmystreet.offlineData.isIndexed(img.src) || urlsInProgress[img.src]) {
                    return;
                }
                imagesToGet.push(img.src);
                imagesToGet.push(img.src.replace('.jpeg', '.fp.jpeg'));
            });
            var imagePromises = imagesToGet.map(function(url) {
                return cacheURL(url, 'image');
            });
            return $.when.apply(undefined, imagePromises).pipe(function() {
                fixmystreet.offlineBanner.progress();
                fixmystreet.offlineData.add(item.url, item.lastupdate);
            }, function() {
                fixmystreet.offlineBanner.progress();
                fixmystreet.offlineData.add(item.url, item.lastupdate);
            });
        });
    }

    // Cache a list of reports offline
    // This fetches the HTML and any img elements in that HTML
    function cacheReports(items) {
        fixmystreet.offlineBanner.startProgress(items.length);
        var promises = items.map(function(item) {
            return cacheReport(item);
        });
        return $.when.apply(undefined, promises);
    }

    return {
        cacheReports: cacheReports
    };
})();

fixmystreet.offline = (function() {
    function getReportsFromList() {
        var reports = $('.item-list__item').map(function(i, li) {
            var $li = $(li),
                url = $li.find('a')[0].pathname,
                lastupdate = $li.data('lastupdate');
            return { 'url': url, 'lastupdate': lastupdate };
        }).get();
        return reports;
    }

    function updateCachedReports() {
        var toCache = [];
        var toRemove = [];
        var shouldBeCached = {};

        localStorage.setItem('/my/planned', $('.item-list').html());

        getReportsFromList().forEach(function(item, i) {
            if (!fixmystreet.offlineData.isIndexed(item.url, item.lastupdate)) {
                toCache.push(item);
            }
            shouldBeCached[item.url] = 1;
        });

        fixmystreet.offlineData.getCachedUrls().forEach(function(url) {
            if ( !shouldBeCached[url] ) {
                toRemove.push(url);
            }
        });

        if (toRemove[0]) {
            removeReports(toRemove);
        }
        if (toCache[0]) {
            fixmystreet.cachet.cacheReports(toCache);
        }
    }

    // Remove a list of reports from the offline cache
    function removeReports(urls) {
        var pathsRemoved = [];
        urls.forEach(function(url) {
            var html = localStorage.getItem(url);
            var $reportPage = $(html);
            localStorage.removeItem(url + '/map');
            $reportPage.find('img').each(function(i, img) {
                if (img.src.indexOf('/photo/') === -1) {
                    return;
                }
                localStorage.removeItem(img.src);
                localStorage.removeItem(img.src.replace('.jpeg', '.fp.jpeg'));
            });
            localStorage.removeItem(url);
        });
        fixmystreet.offlineData.remove(urls);
    }

    function showReportFromCache(url) {
        var html = localStorage.getItem(url);
        if (!html) {
            return false;
        }
        var map = localStorage.getItem(url + '/map');
        var found = html.match(/<body[^>]*>[\s\S]*<\/body>/);
        document.body.outerHTML = found[0];
        $('#map_box').html('<img src="' + map + '">').css({ textAlign: 'center', height: 'auto' });
        replaceImages('img');

        $('.moderate-display.segmented-control, .shadow-wrap, #update_form, #report-cta, .mysoc-footer, .nav-wrapper').hide();

        $('.js-back-to-report-list').attr('href', '/my/planned');

        return true;
    }

    function replaceImages(selector) {
        $(selector).each(function(i, img) {
            if (img.src.indexOf('/photo/') > -1) {
                var dataImg = localStorage.getItem(img.src);
                if (dataImg) {
                    img.src = dataImg;
                }
            }
        });
    }

    return {
        replaceImages: replaceImages,
        showReportFromCache: showReportFromCache,
        removeReports: removeReports,
        updateCachedReports: updateCachedReports
    };

})();

if ($('#offline_list').length) {
    // We are OFFLINE
    var success = false;
    if (location.pathname.indexOf('/report') === 0) {
        success = fixmystreet.offline.showReportFromCache(location.pathname);
    }
    if (!success) {
        var html = localStorage.getItem('/my/planned');
        if (html) {
            $('#offline_list').before('<h2>Your offline reports</h2>');
            $('#offline_list').html(html);
            fixmystreet.offline.replaceImages('#offline_list img');
        }
    }
    fixmystreet.offlineBanner.make(true);
} else {
    // Put the appcache manifest in a page in an iframe so that HTML pages
    // aren't cached (thanks to Jake Archibald for documenting this!)
    if (window.applicationCache && window.localStorage) {
        $(document.body).prepend('<iframe src="/offline/appcache" style="position:absolute;top:-999em;visibility:hidden"></iframe>');
    }

    fixmystreet.offlineBanner.make(false);

    // On /my/planned, when online, cache all shortlisted
    if (location.pathname === '/my/planned') {
        fixmystreet.offline.updateCachedReports();
    }

    // Catch additions and removals from the shortlist
    $(document).on('shortlist-add', function(e, id) {
        var lastupdate = $('.problem-header').data('lastupdate');
        fixmystreet.cachet.cacheReports([{ 'url': '/report/' + id, 'lastupdate': lastupdate }]);
    });
    $(document).on('shortlist-remove', function(e, id) {
        fixmystreet.offline.removeReports(['/report/' + id]);
    });
}
