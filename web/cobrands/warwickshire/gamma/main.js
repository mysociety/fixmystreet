nav_window_size_threshold = 768;
lastwidth = 1000000;

jQuery(document).ready( function() {
	resize_nav();
            lastwidth = jQuery(window).width();
            jQuery(window).resize( function(e) {
                resize_nav();
            });
	jQuery('.entry-content a[href^="#"]').click(function() {
		if (true != (jQuery(this).hasClass("carousel-control")) && (true != (jQuery(this).hasClass("simple-tab")) && (true != (jQuery(this).hasClass("btn"))) ) ) {
			// unfinished || jQuery(this).attr('data-toggle', 'tab') check
			var target = jQuery(this.hash);
			if (target.length == 0) target = jQuery('a[name="' + this.hash.substr(1) + '"]');
			if (target.length == 0) target = jQuery('html');
			jQuery('html, body').animate({ scrollTop: target.offset().top - 60 }, 500);
			return false;
		}
		// else if (true != (jQuery(this).attr('data-toggle', 'tab'))) {
		// }
		else {
			// do nothing
		}
      });
	$('#sb-leftarrow').on('click', function(e) {
        e.preventDefault();
        if($('#super-menu li.active').prev().length) { // check for being at last li
            var b = $('#super-menu li.active').prev();
            $('#super-menu li.active').prev().find('a').click();
        } else {
            $('#super-menu li').last().find('a').click();
        }
    });

    $('#sb-rightarrow').on('click', function(e) {
        e.preventDefault();
        if($('#super-menu li.active').next().length) { // check for being at last li
            $('#super-menu li.active').next().find('a').click();
        } else {
            $('#super-menu li').first().find('a').click();
        }
    });
});

function resize_nav() {
	if(lastwidth != jQuery(window).width()) {
		check_nav_alignments();
		var newwidth = jQuery(window).width();
		if(lastwidth < nav_window_size_threshold && newwidth >= nav_window_size_threshold) {
			// widened past threshold
			jQuery('#mega-menu a.dropdown-toggle').attr('data-toggle', 'dropdown').find('b').show(0);
		} else if(lastwidth >= nav_window_size_threshold && newwidth < nav_window_size_threshold) {
			jQuery('#mega-menu a.dropdown-toggle').removeAttr('data-toggle').find('b').hide(0);
		}
		lastwidth = newwidth;
	}
}

function check_nav_alignments() {
	// Fix unintelligent Bootstrap nav dropdown alignment behaviour
	jQuery('#mega-menu .pull-right').removeClass('pull-right');
	jQuery('#mega-menu ul.dropdown-menu').each( function(i) {
		var rhs = jQuery(this).parent().offset().left + jQuery(this).outerWidth();
		if(rhs > jQuery(window).width()) {
			jQuery(this).parent().addClass('pull-right');
		}
	});
}

jQuery(function() {
	jQuery(".accordion-slide-content").hide();
	jQuery(".accordion-slide-header").click(function() {
			jQuery(this).toggleClass("active");
		});
	jQuery(".accordion-slide-header").click(function() {
			jQuery(this).next(".accordion-slide-content").stop().slideToggle(400).toggleClass("open");
			jQuery(this).parent().siblings(".wrap").children(".accordion-slide-content").stop().slideUp(400);
		}, function() {
			jQuery(this).next(".accordion-slide-content").stop().slideToggle(400);
		});
	
});