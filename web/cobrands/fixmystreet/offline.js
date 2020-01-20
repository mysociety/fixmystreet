fixmystreet.offlineBanner = (function() {
    var toCache = 0;
    var cachedSoFar = 0;

    // Extremely noddy function
    function sprintf(s, p) {
        return s.replace('%s', p);
    }

    // Note this non-global way of handling plurals may need looking at in future
    function formText(num) {
        if ( num === 1 ) {
            return num + ' ' + translation_strings.offline.update_single;
        } else {
            return num + ' ' + translation_strings.offline.update_plural;
        }
    }

    function onlineText(num) {
        return sprintf(translation_strings.offline.saved_to_submit, formText(num));
    }

    function offlineText(num) {
        return translation_strings.offline.you_are_offline + ' \u2013 ' + sprintf(translation_strings.offline.N_saved, formText(num));
    }

    function remove() {
        $('.top_banner--offline').slideUp();
    }

    return {
        make: function(offline) {
            fixmystreet.offlineData.getFormsLength().then(function(num) {
                var banner = ['<div class="top_banner top_banner--offline"><p><span id="offline_saving"></span> <span id="offline_forms">'];
                if (offline || num > 0) {
                    banner.push(offline ? offlineText(num) : onlineText(num));
                }
                banner.push('</span></p></div>');
                banner = $(banner.join(''));
                banner.prependTo('.content');
                if (num === 0) {
                    banner.hide();
                }
            });

            window.addEventListener("offline", function(e) {
                fixmystreet.offlineData.getFormsLength().then(function(num) {
                    $('#offline_forms').html(offlineText(num));
                });
            });

            window.addEventListener("online", function(e) {
                fixmystreet.offlineData.getFormsLength().then(function(num) {
                    $('#offline_forms').html(onlineText(num));
                });
            });

            function nextForm(DataOrJqXHR, textStatus, jqXHROrErrorThrown) {
                fixmystreet.offlineData.shiftForm();
                $(document).dequeue('postForm');
            }

            function postForm(url, data) {
                return $.ajax({ url: url, data: data, type: 'POST' }).done(nextForm);
            }

            $(document).on('click', '#oFN', function(e) {
                e.preventDefault();
                fixmystreet.offlineData.getForms().then(function(forms) {
                    forms.forEach(function(form) {
                        $(document).queue('postForm', function() {
                            postForm(form[0], form[1]).fail(function(jqXHR) {
                                if (jqXHR.status !== 400) {
                                    return nextForm();
                                }
                                // In case the request failed due to out-of-date CSRF token,
                                // try once more with a new token given in the error response.
                                var m = jqXHR.responseText.match(/content="([^"]*)" name="csrf-token"/);
                                if (!m) {
                                    return nextForm();
                                }
                                var token = m[1];
                                if (!token) {
                                    return nextForm();
                                }
                                var param = form[1].replace(/&token=[^&]*/, '&token=' + token);
                                return postForm(form[0], param).fail(nextForm);
                            });
                        });
                    });
                    $(document).dequeue('postForm');
                });
            });
        },
        update: function() {
            $('.top_banner--offline').slideDown();
            fixmystreet.offlineData.getFormsLength().then(function(num) {
                $('#offline_forms span').text(formText(num));
                if (num === 0) {
                    window.setTimeout(remove, 3000);
                }
            });
        },
        startProgress: function(l) {
            $('.top_banner--offline').slideDown();
            toCache = l;
            $('#offline_saving').html(translation_strings.offline.saving_reports + ' &ndash; <span>0</span>/' + toCache + '.');
        },
        progress: function() {
            cachedSoFar += 1;
            if (cachedSoFar === toCache) {
                $('#offline_saving').text(translation_strings.offline.reports_saved);
                window.setTimeout(remove, 3000);
            } else {
                $('#offline_saving span').text(cachedSoFar);
            }
        }
    };
})();

fixmystreet.offlineData = (function() {
    var data;

    function getData() {
        if (data !== undefined) {
            return Promise.resolve(data);
        }
        return idbKeyval.get('offlineData').then(function(d) {
            data = d || { cachedReports: {}, forms: [] };
            return data;
        });
    }

    function updateData(cb) {
        getData().then(function(data) {
            cb(data);
            idbKeyval.set('offlineData', data);
        });
    }

    return {
        getFormsLength: function() {
            return getData().then(function(data) { return data.forms.length; });
        },
        getForms: function() {
            return getData().then(function(data) { return data.forms; });
        },
        shiftForm: function(idx) {
            updateData(function(data) {
                data.forms.shift();
                fixmystreet.offlineBanner.update();
            });
        },
        clearForms: function(idx) {
            updateData(function(data) {
                data.forms = [];
                fixmystreet.offlineBanner.update();
            });
        },
        getCachedReports: function() {
            return getData().then(function(data) { return data.cachedReports; });
        },
        add: function(url, lastupdate) {
            updateData(function(data) {
                data.cachedReports[url] = lastupdate || "-";
            });
        },
        remove: function(urls) {
            updateData(function(data) {
                urls.forEach(function(url) {
                    delete data.cachedReports[url];
                });
            });
        }
    };
})();

fixmystreet.cachet = (function(){
    var urlsInProgress = {};

    function cacheURL(url) {
        urlsInProgress[url] = 1;
        return caches.open('pages').then(function(cache) {
            return fetch(url).then(function(response) {
                if (response.ok) {
                    cache.put(url, response.clone()).then(function() {
                        delete urlsInProgress[url];
                    });
                }
                return response;
            });
        });
    }

    function cacheReport(item) {
        return cacheURL(item.url).then(function(response) {
            return response.text();
        }).then(function(html) {
            var $reportPage = $(html);
            var imagesToGet = [
                item.url + '/map' // Static map image
            ];
            $reportPage.find('img').each(function(i, img) {
                if (img.src.indexOf('/photo/') === -1 || urlsInProgress[img.src]) {
                    return;
                }
                imagesToGet.push(img.src);
                imagesToGet.push(img.src.replace('.jpeg', '.fp.jpeg'));
            });
            var imagePromises = imagesToGet.map(function(url) {
                return cacheURL(url);
            });
            return Promise.all(imagePromises).finally(function() {
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
        return Promise.all(promises);
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

        idbKeyval.set('/my/planned', $('.item-list').html());

        fixmystreet.offlineData.getCachedReports().then(function(reports) {
            getReportsFromList().forEach(function(item, i) {
                var t = reports[item.url];
                if (t !== item.lastupdate) {
                    toCache.push(item);
                }
                shouldBeCached[item.url] = 1;
            });

            Object.keys(reports).forEach(function(url) {
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
        });
    }

    // Remove a list of reports from the offline cache
    function removeReports(urls) {
        caches.open('pages').then(function(cache) {
            urls.forEach(function(url) {
                fetch(url).then(function(response) {
                    return response.text();
                }).then(function(html) {
                    var $reportPage = $(html);
                    cache.delete(url + '/map');
                    $reportPage.find('img').each(function(i, img) {
                        if (img.src.indexOf('/photo/') === -1) {
                            return;
                        }
                        cache.delete(img.src);
                        cache.delete(img.src.replace('.jpeg', '.fp.jpeg'));
                    });
                    cache.delete(url);
                });
            });
            fixmystreet.offlineData.remove(urls);
        });
    }

    function showReportOffline(url) {
        $('#map_box').html('<img src="' + url + '/map">').css({ textAlign: 'center', height: 'auto' });
        $('.moderate-display.segmented-control, .shadow-wrap, #update_form, #report-cta, .mysoc-footer, .nav-wrapper').hide();
        $('.js-back-to-report-list').attr('href', '/my/planned');

        // Refill form with saved data if there is any
        fixmystreet.offlineData.getForms().then(function(forms) {
            var savedForm;
            forms.forEach(function(form) {
                if (form[0].endsWith(url)) {
                    savedForm = form[1];
                }
            });
            if (savedForm) {
                savedForm.replace(/\+/g, '%20').split('&').forEach(function(kv) {
                    kv = kv.split('=', 2);
                    if (kv[0] != 'include_update' && kv[0] != 'public_update' && kv[0] != 'save') {
                        $('[name=' + kv[0] + ']').val(decodeURIComponent(kv[1]));
                    }
                });
            }
        });
    }

    return {
        showReportOffline: showReportOffline,
        removeReports: removeReports,
        updateCachedReports: updateCachedReports
    };

})();

if (!navigator.onLine && location.pathname.indexOf('/report') === 0) {
    fixmystreet.offline.showReportOffline(location.pathname);
}

if ($('#offline_list').length) {
    // We are OFFLINE
    idbKeyval.get('/my/planned').then(function(html) {
        if (!html) { return; }
        $('#offline_list').before('<h2>'+translation_strings.offline.your_reports+'</h2>');
        $('#offline_list').html(html);
        if (location.search.indexOf('saved=1') > 0) {
            $('#offline_list').before('<p class="form-success">'+translation_strings.offline.update_saved+'</p>');
        }
        fixmystreet.offlineData.getForms().then(function(offlineForms) {
            var savedForms = {};
            offlineForms.forEach(function(form) {
                savedForms[form[0]] = 1;
            });
            $('#offline_list a').each(function(i, a) {
                if (savedForms[a.href]) {
                    $(this).find('h3').prepend('<em>'+translation_strings.offline.update_data_saved+'</em> ');
                }
            });
        });
        $('#offline_clear').css('margin-top', '5em').html('<button id="js-clear-storage">'+translation_strings.offline.clear_data+'</button>');
        $('#js-clear-storage').click(function() {
            if (window.confirm(translation_strings.offline.are_you_sure)) {
                fixmystreet.offlineData.getCachedReports().then(function(reports) {
                    fixmystreet.offline.removeReports(Object.keys(reports));
                });
                fixmystreet.offlineData.clearForms();
                idbKeyval.del('/my/planned');
                alert(translation_strings.offline.data_cleared);
            }
        });
    });
    fixmystreet.offlineBanner.make(true);
} else {
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

    $(document).on('shortlist-all', function(e, args) {
      fixmystreet.cachet.cacheReports(args.items);
    });

    $(document).on('shortlist-remove', function(e, id) {
        fixmystreet.offline.removeReports(['/report/' + id]);
    });
}
