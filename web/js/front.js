// document.getElementById('pc').focus();

(function(){

    function dropzoneSetup() {
        console.log('dropzoneSetup');
        if ('Dropzone' in window) {
            Dropzone.autoDiscover = false;
            console.log('Dropzone', Dropzone);
        } else {
            console.log('Dropzone not found');
            return;
        }

        var dz = new Dropzone('#photoFormPhoto', {
            url: '/photo/upload?get_latlon=1',
            paramName: 'photo',
            maxFiles: 1,
            addRemoveLinks: true,
            thumbnailHeight: 256,
            thumbnailWidth: 256,
            // resizeHeight: 2048,
            // resizeWidth: 2048,
            // resizeQuality: 0.6,
            acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png,.png,.tiff,.tif,.gif,.jpeg,.jpg',
            dictDefaultMessage: "Upload a photo to start a new report",
            // dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
            // dictInvalidFileType: translation_strings.upload_invalid_file_type,
            // dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,
            init: function() {
                console.log('init', this);
                var $f = $("#photoForm");
                $("#photoForm label, #photoForm input[type=file], #photoForm input[type=submit]").hide();
                $f.attr("method", "get");
                $f.attr("action", "/report/new");
                $f.attr("enctype", "");
                this.on("success", function(file, xhrResponse) {
                    console.log('success', file, xhrResponse);
                    $("#photoForm label, #photoForm input[type=file], #photoForm input[type=submit]").remove();
                    $f.find("input[name=photo_id]").val(xhrResponse.id);
                    $f.find("input[name=lat]").val(xhrResponse.lat);
                    $f.find("input[name=lon]").val(xhrResponse.lon);
                    $f.submit();
                });
            }
        });
    }
    dropzoneSetup();
    function set_up_mobile_nav() {
        var html = document.documentElement;
        if (!html.classList) {
          return;
        }

        // Just the HTML class bit of the main resize listener, just in case
        window.addEventListener('resize', function() {
            var type = Modernizr.mq('(min-width: 48em)') ? 'desktop' : 'mobile';
            if (type == 'mobile') {
                html.classList.add('mobile');
            } else {
                html.classList.remove('mobile');
            }
        });

        var modal = document.getElementById('js-menu-open-modal'),
            nav = document.getElementById('main-nav'),
            nav_checkbox = document.getElementById('main-nav-btn'),
            nav_link = document.querySelector('label[for="main-nav-btn"]');

        var toggle_menu = function(e) {
            if (!html.classList.contains('mobile')) {
                return;
            }
            e.preventDefault();
            var opened = html.classList.toggle('js-nav-open');
            if (opened) {
                // Set height so can scroll menu if not enough space
                var nav_top = nav_checkbox.offsetTop;
                var h = window.innerHeight - nav_top;
                nav.style.maxHeight = h + 'px';
                modal.style.top = nav_top + 'px';
            }
            nav_checkbox.setAttribute('aria-expanded', opened);
            nav_checkbox.checked = opened;
        };

        nav_checkbox.addEventListener('focus', function() {
            nav_link.classList.add('focussed');
        });
        nav_checkbox.addEventListener('blur', function() {
            nav_link.classList.remove('focussed');
        });
        modal.addEventListener('click', toggle_menu);
        nav_checkbox.addEventListener('change', toggle_menu);
        nav.addEventListener('click', function(e) {
            if (e.target.matches('span')) {
                toggle_menu(e);
            }
        });
    }

    set_up_mobile_nav();

    var around_forms = document.querySelectorAll('form[action*="around"]');
    for (var i=0; i<around_forms.length; i++) {
        var form = around_forms[i];
        var el = document.createElement('input');
        el.type = 'hidden';
        el.name = 'js';
        el.value = 1;
        form.insertBefore(el, form.firstChild);
    }

    var around_links = document.querySelectorAll('a[href*="around"]');
    for (i=0; i<around_links.length; i++) {
        var link = around_links[i];
        link.href = link.href + (link.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    }

    if (!('addEventListener' in window)) {
        return;
    }

    var lk = document.querySelector('span.report-a-problem-btn');
    if (lk && lk.addEventListener) {
        lk.setAttribute('role', 'button');
        lk.setAttribute('tabindex', '0');
        lk.addEventListener('click', function(e){
            e.preventDefault();
            scrollTo(0,0);
            document.getElementById('pc').focus();
        });
    }

    var cta = document.getElementById('report-cta');
    if (cta && cta.addEventListener) {
        cta.addEventListener('click', function(e) {
            e.preventDefault();
            scrollTo(0,0);
            document.getElementById('pc').focus();
        });
    }

})();
