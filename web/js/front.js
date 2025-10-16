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
            dictInvalidFileType:"You can't upload files of this type. Please try again using the following formats: png, tiff, tif, gif, jpeg, jpg",
            // resizeHeight: 2048,
            // resizeWidth: 2048,
            // resizeQuality: 0.6,
            acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png,.png,.tiff,.tif,.gif,.jpeg,.jpg',
            dictDefaultMessage: '<div class="dropzone-desktop">Browse or drag files here to upload</div><div class="dropzone-mobile"><u><svg width="44" height="44" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M5.75 3L5.5935 3.203L5 4H1.5V13H14.5V4H11L10.406 3.203L10.25 3H5.75ZM6.25 4H9.75L10.344 4.797L10.5 5H13.5V12H2.5V5H5.5L5.6565 4.797L6.25 4ZM4 5.5C3.725 5.5 3.5 5.725 3.5 6C3.5 6.275 3.725 6.5 4 6.5C4.275 6.5 4.5 6.275 4.5 6C4.5 5.725 4.275 5.5 4 5.5ZM8 5.5C6.35 5.5 5 6.85 5 8.5C5 10.15 6.35 11.5 8 11.5C9.65 11.5 11 10.15 11 8.5C11 6.85 9.65 5.5 8 5.5ZM8 6.5C9.1115 6.5 10 7.3885 10 8.5C10 9.6115 9.1115 10.5 8 10.5C6.8885 10.5 6 9.6115 6 8.5C6 7.3885 6.8885 6.5 8 6.5Z" fill="currentColor"/></svg>Start a report with a photo</u></div>',
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

                    if (!xhrResponse.lat || !xhrResponse.lon) {
                        if (file.previewElement) {
                            file.previewElement.classList.add("dz-error");
                            var errorElement = file.previewElement.querySelector("[data-dz-errormessage]");
                            if (errorElement) {
                                errorElement.textContent = "No location data found. You can still use the postcode form on the left to start a report";
                            }
                        }
                        return;
                    }

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
