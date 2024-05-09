document.getElementById('pc').focus();

(function(){

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
