document.getElementById('pc').focus();

(function(){

    function dropzoneSetup() {
        if ('Dropzone' in window) {
            Dropzone.autoDiscover = false;
        } else {
            console.error('Dropzone not found');
            return;
        }

        var photoForm = document.getElementById('photoForm');
        var dropzone = document.getElementById('photoFormPhoto');
        if (!dropzone) {
            return;
        }

        var dz = new Dropzone(dropzone, {
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
            dictDefaultMessage: '<span class="dropzone-desktop">' + translation_strings.frontpage_upload_default_message_desktop + '</span><span class="dropzone-mobile"><u><svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M13.997 4C14.3578 3.99999 14.7119 4.09759 15.0217 4.28244C15.3316 4.46729 15.5856 4.73251 15.757 5.05L16.243 5.95C16.4144 6.26749 16.6684 6.53271 16.9783 6.71756C17.2881 6.90241 17.6422 7.00001 18.003 7H20C20.5304 7 21.0391 7.21071 21.4142 7.58579C21.7893 7.96086 22 8.46957 22 9V18C22 18.5304 21.7893 19.0391 21.4142 19.4142C21.0391 19.7893 20.5304 20 20 20H4C3.46957 20 2.96086 19.7893 2.58579 19.4142C2.21071 19.0391 2 18.5304 2 18V9C2 8.46957 2.21071 7.96086 2.58579 7.58579C2.96086 7.21071 3.46957 7 4 7H5.997C6.35742 7.00002 6.71115 6.90264 7.02078 6.71817C7.33041 6.53369 7.58444 6.26897 7.756 5.952L8.245 5.048C8.41656 4.73103 8.67059 4.46631 8.98022 4.28183C9.28985 4.09736 9.64358 3.99998 10.004 4H13.997Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 16C13.6569 16 15 14.6569 15 13C15 11.3431 13.6569 10 12 10C10.3431 10 9 11.3431 9 13C9 14.6569 10.3431 16 12 16Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>' + translation_strings.frontpage_upload_default_message_mobile + '</u></span>',
            dictInvalidFileType: translation_strings.upload_invalid_file_type,
            fallback: function() {
                dropzone.remove();
                photoForm.querySelector('.fallback').classList.remove('hidden-js');
            },
            init: function() {
                var errorContainer = document.getElementById("photo-upload-error");

                this.on("error", function(file, errorMessage) {
                    // Show error in the dedicated container (visible on mobile)
                    var message = typeof errorMessage === 'string' ? errorMessage : (errorMessage.error || 'Upload failed');
                    errorContainer.innerText = message;
                    errorContainer.hidden = false;
                    // Remove the failed file so user can try again
                    this.removeFile(file);
                });

                this.on("addedfile", function() {
                    // Clear any previous error when user tries again
                    errorContainer.hidden = true;
                });

                this.on("success", function(file, xhrResponse) {
                    if (!xhrResponse.lat || !xhrResponse.lon) {
                        // Photo without GPS - go to /around
                        location.href = '/around?photo_id=' + xhrResponse.id;
                    } else {
                        // Photo with GPS - go to /report/new with photo_first flag
                        location.href = '/report/new?lat=' + xhrResponse.lat + '&lon=' + xhrResponse.lon + '&photo_id=' + xhrResponse.id + '&photo_first=1';
                    }
                });
            }
        });

        dropzone.addEventListener('keydown', function(e) {
            if (e.keyCode === 13 || e.keyCode === 32) {
                e.preventDefault();
                dropzone.click();
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
