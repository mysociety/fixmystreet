fixmystreet.offlineBanner = (function() {
    var toCache = 0;
    var cachedSoFar = 0;

    // Extremely noddy function
    function sprintf(s, p) {
        return s.replace('%s', p);
    }

    // Note this non-global way of handling plurals may need looking at in future
    function formText() {
        var num = fixmystreet.offlineData.getForms().length;
        if ( num === 1 ) {
            return num + ' ' + translation_strings.offline.update_single;
        } else {
            return num + ' ' + translation_strings.offline.update_plural;
        }
    }

    function onlineText() {
        return sprintf(translation_strings.offline.saved_to_submit, formText());
    }

    function offlineText() {
        return translation_strings.offline.you_are_offline + ' \u2013 ' + sprintf(translation_strings.offline.N_saved, formText());
    }

    function remove() {
        $('.top_banner--offline').slideUp();
    }

    return {
        make: function(offline) {
            var num = fixmystreet.offlineData.getForms().length;
            var banner = ['<div class="top_banner top_banner--offline"><p><span id="offline_saving"></span> <span id="offline_forms">'];
            if (offline || num > 0) {
                banner.push(offline ? offlineText() : onlineText());
            }
            banner.push('</span></p></div>');
            banner = $(banner.join(''));
            banner.prependTo('.content');
            if (num === 0) {
                banner.hide();
            }

            window.addEventListener("offline", function(e) {
                $('#offline_forms').html(offlineText());
            });

            window.addEventListener("online", function(e) {
                $('#offline_forms').html(onlineText());
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
                fixmystreet.offlineData.getForms().forEach(function(form) {
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
        },
        update: function() {
            $('.top_banner--offline').slideDown();
            $('#offline_forms span').text(formText());
            var num = fixmystreet.offlineData.getForms().length;
            if (num === 0) {
                window.setTimeout(remove, 3000);
            }
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
        if (data === undefined) {
            data = JSON.parse(localStorage.getItem('offlineData'));
            if (!data) {
                data = { cachedReports: {}, forms: [] };
            }
        }
        return data;
    }

    function saveData() {
        localStorage.setItem('offlineData', JSON.stringify(getData()));
    }

    return {
        getForms: function() {
            return getData().forms;
        },
        addForm: function(action, formData) {
            var forms = getData().forms;
            if (!forms.length || formData != forms[forms.length - 1][1]) {
                forms.push([action, formData]);
                saveData();
            }
            fixmystreet.offlineBanner.update();
        },
        shiftForm: function(idx) {
            getData().forms.shift();
            saveData();
            fixmystreet.offlineBanner.update();
        },
        clearForms: function(idx) {
            getData().forms = [];
            saveData();
            fixmystreet.offlineBanner.update();
        },
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

        // Refill form with saved data if there is any
        var savedForm;
        fixmystreet.offlineData.getForms().forEach(function(form) {
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

        // If we catch the form submit, e.g. Chrome still seems to
        // try and submit and we get the Chrome offline error page
        var btn = $('#report_inspect_form input[type=submit]');
        btn.click(function() {
            var form = $(this).closest('form');
            var data = form.serialize() + '&save=1&saved_at=' + Math.floor(+new Date() / 1000);
            fixmystreet.offlineData.addForm(form.attr('action'), data);
            location.href = '/my/planned?saved=1';
            return false;
        });
        btn[0].type = 'button';

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
            $('#offline_list').before('<h2>'+translation_strings.offline.your_reports+'</h2>');
            $('#offline_list').html(html);
            if (location.search.indexOf('saved=1') > 0) {
                $('#offline_list').before('<p class="form-success">'+translation_strings.offline.update_saved+'</p>');
            }
            fixmystreet.offline.replaceImages('#offline_list img');
            var offlineForms = fixmystreet.offlineData.getForms();
            var savedForms = {};
            offlineForms.forEach(function(form) {
                savedForms[form[0]] = 1;
            });
            $('#offline_list a').each(function(i, a) {
                if (savedForms[a.href]) {
                    $(this).find('h3').prepend('<em>'+translation_strings.offline.update_data_saved+'</em> ');
                }
            });
            $('#offline_clear').css('margin-top', '5em').html('<button id="js-clear-localStorage">'+translation_strings.offline.clear_data+'</button>');
            $('#js-clear-localStorage').click(function() {
                if (window.confirm(translation_strings.offline.are_you_sure)) {
                    fixmystreet.offline.removeReports(fixmystreet.offlineData.getCachedUrls());
                    fixmystreet.offlineData.clearForms();
                    localStorage.removeItem('/my/planned');
                    alert(translation_strings.offline.data_cleared);
                }
            });
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

    $(document).on('shortlist-all', function(e, args) {
      fixmystreet.cachet.cacheReports(args.items);
    });

    $(document).on('shortlist-remove', function(e, id) {
        fixmystreet.offline.removeReports(['/report/' + id]);
    });
}
