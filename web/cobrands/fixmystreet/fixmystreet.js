/*
 * fixmystreet.js
 * FixMyStreet JavaScript
 */

var fixmystreet = fixmystreet || {};

/*
 * Find directionality of content
 */
function isR2L() {
    return !!$('html[dir=rtl]').length;
}

// Some small jQuery extensions
(function($) {
  var opened;

  $.fn.extend({
    // A sliding drawer from the bottom of the page, small version
    // that doesn't change the main content at all.
    small_drawer: function(id) {
        var $this = $(this), d = $('#' + id),
        keyboardTriggered = false,
        previousFocus;

        this.on('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                keyboardTriggered = true;
            }
        });

        this.on('click', function(e) {
            e.preventDefault();
            previousFocus = $(document.activeElement);
            if (!$this.hasClass('hover')) {
                if (opened) {
                    opened.trigger('click');
                }
                if (!$this.addClass('hover').data('setup')) {
                    var parentWidth = d.parent().width();
                    var isMobile = $('html').hasClass('mobile');
                    var bottomValue = ( $(window).height() - $this.offset().top + 3 ) + 'px';
                    d.hide().removeClass('hidden-js').css({
                    padding: '1em',
                    background: '#fff',
                    position: 'fixed',
                    top: isMobile ? '0' : '',
                    left: '0',
                    bottom: isMobile ? '' : bottomValue,
                    'z-index': 9999,
                    width: isMobile ? '100vw' : parentWidth
                    });
                    $this.data('setup', true);
                }
                d.slideDown(function() {
                    $this.attr('aria-expanded', 'true');
                    // We want to focus on first focusable element inside the drawer, but only if the user has use the keyboard. It is a bit odd having this behaviour when using the mouse.
                    if (keyboardTriggered) {
                        d.find('a, button, input, select, textarea').first().focus();
                        keyboardTriggered = false;
                    }
                });
                opened = $this;
            } else {
                $this.removeClass('hover');
                d.slideUp(function() {
                    $this.attr('aria-expanded', 'false');
                });
                opened = null;
            }
        });

        d.on('click', '.close-drawer', function() {
            $this.removeClass('hover');
            d.slideUp(function() {
                $this.attr('aria-expanded', 'false');
                if (previousFocus) {
                    previousFocus.focus();
                }
            });
            opened = null;
        });
    },

    // A sliding drawer from the bottom of the page, large version
    drawer: function(id, ajax) {

        // The link/button that triggered the drawer
        var $this = $(this);

        // A bunch of elements that will come in handy when opening/closing
        // the drawer. Because $sw changes its position in the DOM, we capture
        // all these elements just once, the first time .drawer() is called.
        var $sidebar = $('#map_sidebar');
        var $sw = $this.parents('.shadow-wrap');
        var $swparent = $sw.parent();
        var $drawer = $('#' + id);

        this.off('click');
        this.on('click', function(e) {
            e.preventDefault();
            var drawer_top;
            if (!$this.hasClass('hover')) {
                // Find the specified drawer, or create it if it doesn't exist
                if ($drawer.length === 0) {
                    $drawer = $('<div id="' + id + '">');
                    $drawer.appendTo($swparent);
                }

                if (!$this.addClass('hover').data('setup')) {
                    // Optionally fill $drawer with HTML from an AJAX data source
                    if (ajax) {
                        var href = $this.attr('href') + ';ajax=1';
                        var margin = isR2L() ? 'margin-left' : 'margin-right';
                        var $ajax_result = $('<div>').appendTo($drawer);
                        $ajax_result.html('<p style="text-align:center">Loading</p>');
                        $ajax_result.load(href);
                    }
                    // Style up the $drawer
                    drawer_top = $(window).height() - $sw.height();
                    var drawer_css = {
                        position: 'fixed',
                        zIndex: 10,
                        top: drawer_top,
                        bottom: 0,
                        width: $sidebar.css('width'),
                        paddingLeft: $sidebar.css('padding-left'),
                        paddingRight: $sidebar.css('padding-right'),
                        overflow: 'auto',
                        background: '#fff'
                    };
                    drawer_css[isR2L() ? 'right' : 'left'] = 0;
                    $drawer.css(drawer_css).removeClass('hidden-js').find('h2').css({ marginTop: 0 });
                    $this.data('setup', true);
                }

                // Insert the .shadow-wrap controls into the top of the drawer.
                $sw.addClass('static').prependTo($drawer);
                $('.js-key-tools').addClass('area-js');
                $('#key-tool-wards').addClass('hover');

                // Animate the drawer into place, enitrely covering the sidebar.
                var sidebar_top_px = $sidebar.position().top;
                $drawer.show().animate({ top: sidebar_top_px }, 1000);

            } else {
                // Slide the drawer down, move the .shadow-wrap back to its
                // original parent, and hide the drawer for potential re-use later.
                $this.removeClass('hover');
                drawer_top = $(window).height() - $sw.height();

                $drawer.animate({ top: drawer_top }, 1000, function() {
                    $sw.removeClass('static').appendTo($swparent);
                    $drawer.hide();
                });
            }
        });
    },

    make_multi: function() {
      // A convenience wrapper around $.multiSelect() that translates HTML
      // data-* attributes into settings for the multiSelect constructor.
      return this.each(function() {
        var $select = $(this);
        var settings = {
            modalHTML: '<div class="multi-select-modal">'
        };

        if ( $select.data('none') ) {
            settings.noneText = $select.data('none');
        }

        if ($select.attr("id") == 'filter_categories' || $select.attr("id") == 'statuses') {
            settings.menuItemsHTML = '<div class="govuk-multi-select govuk-multi-select--checkboxes">';
            settings.menuItemHTML = '<label class="govuk-multi-select__label">';
            settings.menuFieldsetHTML = '<fieldset class="multi-select-fieldset govuk-fieldset">';
            settings.menuFieldsetLegendHTML = '<legend class="multi-select-fieldset govuk-fieldset__legend govuk-fieldset__legend--s">';
        }

        if ( $select.data('all') ) {
            settings.allText = $select.data('all');
            settings.noneText = settings.noneText || settings.allText;
            settings.presets = [];
            settings.presets.push({
                name: settings.allText,
            });

            if ($select.data('all-options')) {
                settings.presets[0].options = $select.data('all-options');
            }
            else {
                settings.presets[0].all = true;
            }
        }

        if ( $select.data('extra') && $select.data('extra-options') ) {
            settings.presets = settings.presets || [];
            settings.presets.push({
                name: $select.data('extra'),
                options: $select.data('extra-options')
            });
        }

        if ( document.querySelector('#side') && document.querySelector('#side').contains($select[0]) ) {
            settings.positionMenuWithin = $('#side');
        }

        $select.multiSelect(settings);
      });
    },
    bankDetailsFormatter: function(options) {
        var settings = $.extend({}, options);

        var sortCodeSelector = settings.sortCodeSelector || '#sort_code';
        var accountNumberSelector = settings.accountNumberSelector || '#account_number';

        function formatSortCode(input) {
            // Remove all non-digits/non-dashes
            var value = $(input).val().replace(/[^\d-]/g, '');

            // Limit to 8 characters (6 digits + 2 hyphens)
            $(input).val(value.substring(0, 8));
        }

        function formatAccountNumber(input) {
            // Remove all non-digits and limit to 8 digits
            var value = $(input).val().replace(/\D/g, '');
            $(input).val(value.substring(0, 8));
        }

        return this.each(function() {
            var $container = $(this);

            $container.find(sortCodeSelector).on('input', function() {
                formatSortCode(this);
            });

            $container.find(accountNumberSelector).on('input', function() {
                formatAccountNumber(this);
            });
        });
    }
  });
})(jQuery);

fixmystreet.mobile_reporting = {
  apply_ui: function() {
    // Creates the "app-like" mobile reporting UI with full screen map
    // and special "OK/Cancel" buttons etc.
    $('html').addClass('map-fullscreen only-map map-reporting map-with-crosshairs1');
    $('html').removeClass('map-with-crosshairs3 map-with-crosshairs2');
    $('#map_box').removeClass('hidden-js');
    $('#map_box').on('contextmenu', function(e) { e.preventDefault(); });

    if (fixmystreet.page === 'new') {
        // Might have come direct to report/new, need right buttons
        fixmystreet.pageController.mapStepButtons();
        return;
    }

    $('.mobile-map-banner span').text(translation_strings.place_pin_on_map);

    if ($('#map_filter').length === 0) {
        $map_filter = $('<a href="#side" id="map_filter">' + translation_strings.filter + '</a>');
        $map_filter.on('click', function(e) {
            e.preventDefault();
            var $form = $('#mapForm');
            var $sub_map_links = $('#sub_map_links');
            if ( $form.is('.mobile-filters-active') ) {
                $form.removeClass('mobile-filters-active');
                $sub_map_links.css('bottom', '');
            } else {
                $form.addClass('mobile-filters-active');
                $sub_map_links.css('bottom', $('.report-list-filters-wrapper').outerHeight() );
            }
        });
        $('#sub_map_links').prepend($map_filter);
    }

    // Do this on a timeout, so it takes precedence over the browser’s
    // remembered position, which we do not want, we want a fixed map.
    setTimeout(function() {
        $('html, body').scrollTop(0);
    }, 0);
  },

  remove_ui: function() {
    // Removes the "app-like" mobile reporting UI, reverting all the
    // changes made by fixmystreet.mobile_reporting.apply_ui().
    $('html').removeClass('map-fullscreen only-map map-reporting map-page map-with-crosshairs1');
    $('#mob_sub_map_links').remove();

    // Turn off the mobile map filters.
    $('#mapForm').removeClass('mobile-filters-active');
    $('#sub_map_links').css('bottom', '');
    $('#map_filter').remove();
  }
};

fixmystreet.resize_to = {
  mobile_page: function() {
    $('html').addClass('mobile');
    if (typeof fixmystreet !== 'undefined' && (fixmystreet.page === 'around' || fixmystreet.page === 'new') && Modernizr.mq('(min-height: 30em)')) {
        fixmystreet.mobile_reporting.apply_ui();
    }

    // Hide sidebar notes ("rap-notes") on the /report/new page on mobile,
    // and provide a button that reveals/hides them again.
    var $rapSidebar = $('#report-a-problem-sidebar');
    if ($rapSidebar.length) {
        $rapSidebar.hide();
        $('<a>')
            .addClass('rap-notes-trigger btn btn--block btn--forward')
            .html(translation_strings.how_to_send)
            .insertBefore($rapSidebar)
            .on('click', function(){
                $rapSidebar.slideToggle(100);
                $(this).toggleClass('btn--forward btn--cancel');
            });
    }
  },

  desktop_page: function() {
    $('html').removeClass('mobile');
    fixmystreet.mobile_reporting.remove_ui();

    // Undo the special "rap-notes" tweaks that might have
    // been put into place by previous mobile UI.
    $('#report-a-problem-sidebar').show();
    $('.rap-notes-trigger').remove();
  }
};

fixmystreet.update_list_item_buttons = function($list) {
    if (!$list) {
        return;
    }
  $list.find('[name="shortlist-up"], [name="shortlist-down"]').prop('disabled', false);
  $list.children(':first-child').find('[name="shortlist-up"]').prop('disabled', true);
  $list.children(':last-child').find('[name="shortlist-down"]').prop('disabled', true);
};

fixmystreet.pageController = {
    toPage: function(page, opts) {
        opts = opts || {};
        var $curr = $('.js-reporting-page--active');
        var $page;
        if (page === 'first') {
            $page = $('.js-reporting-page').first();
            page = $page.data('pageName');
        } else if (page === 'next') {
            if ($curr.data('pageName') === 'map') {
                if (!fixmystreet.reporting.selectedCategory().category) {
                    $page = $('.js-reporting-page').first();
                } else {
                    // It is possible for multiple map 'page' divs to exist if
                    // multiple layers shown. We only need one of them
                    $page = $curr.nextAll('.js-reporting-page:not(.js-reporting-page--skip,.js-reporting-page--map)').first();
                }
            } else {
                $page = $curr.nextAll('.js-reporting-page:not(.js-reporting-page--skip)').first();
            }
            page = $page.data('pageName');
        } else {
            $page = $('.js-reporting-page[data-page-name=' + page + ']');
        }
        // On mobile, skip desktop-only pages
        if ($("html").hasClass("mobile") && $page.hasClass('js-reporting-page--desktop-only')) {
            $page = $page.nextAll('.js-reporting-page:not(.js-reporting-page--skip,.js-reporting-page--desktop-only)').first();
            page = $page.data('pageName');
        }
        if ($curr.data('pageName') === 'map' || $('#mob_ok:visible').length || opts.forceMapHide) {
            if ($("html").hasClass("mobile")) {
                $('#map_box').addClass('hidden-js');
                $('html').removeClass('only-map map-page');
            }
        }

        $curr.removeClass('js-reporting-page--active');
        $page.addClass('js-reporting-page--active');

        if ($page.data('pageName') === 'map' || opts.forceMapShow) {
            // We're going to bypass to the map for the next step, then come back here
            // Or we have clicked Back to the original map
            if ($("html").hasClass("mobile")) {
                $('#map_box').removeClass('hidden-js');
                $('html').addClass('only-map map-page');
            }
        }
        setTimeout(function() {
            $('html, body, #map_sidebar').scrollTop(0);
        }, 0);
        if (!opts.popstate && 'pushState' in history) {
            history.pushState({
                reportingPage: page
            }, null, '#' + page);
        }
        $(fixmystreet).trigger('report_new:page_change', [ $curr, $page ]);
    },
    mapStepButtons: function() {
        // We are now in the reporting flow, so set the page flag used for error display
        $('html').addClass('map-page map-with-crosshairs2');
        $('html').removeClass('map-with-crosshairs1 map-with-crosshairs3');
        fixmystreet.maps.reposition_control.autoActivate = true;

        var $map_box = $('#map_box');
        var links = '<a href="#ok" id="mob_ok">' + translation_strings.ok + '</a>';
        if (fixmystreet.page !== 'new') {
            links = '<a href="#" class="js-back" id="problems_nearby">' + translation_strings.back + '</a>' + links;
        }
        $map_box.append('<p class="sub-map-links" id="mob_sub_map_links">' + links + '</p>');

        var bannerText = fixmystreet.photo_first ? translation_strings.right_place_photo_first : translation_strings.right_place;
        $('.mobile-map-banner span').text(bannerText);

        // mobile user clicks 'ok' on map
        $('#mob_ok').on('click', function(e){
            e.preventDefault();
            $('html').removeClass('map-with-crosshairs2 map-with-crosshairs3');
            var $page = $('.js-reporting-page--active');
            var first_page = $('.js-reporting-page').first().data('pageName');
            if ($page.data('pageName') === first_page || !$page.length) {
                // Either the original pin location, or the map 'page' was
                // removed while we had it open, due to e.g. clicking the map
                // in a totally different council. Show first step
                fixmystreet.pageController.toPage('first', {
                    forceMapHide: true
                });
            } else {
                // Something later, e.g. asset selection, move to next step
                fixmystreet.pageController.toPage('next');
            }
        });
    },
    addMapPage: function(layer) {
        var $map_page = $('#' + layer.id + '_map');
        if (!$map_page.length) {
            $map_page = $('<div data-page-name="map" class="js-reporting-page js-reporting-page--map" id="' + layer.id + '_map"></div>');
        }
        // Move the map page depending on if we are basing its appearance on the
        // answer to an extra question (so subcategories key is present) or not
        if (layer.fixmystreet.subcategories) {
            $map_page.insertAfter('#js-post-category-messages');
        } else {
            $map_page.insertBefore('#js-post-category-messages');
        }
    },
    addNextPage: function(name, $div) {
        $div.addClass('js-reporting-page');
        $div.attr('data-page-name', name);
        $div.append("<button class='btn btn--block btn--final js-reporting-page--next'>" + translation_strings.ok + "</button>");
        $('.js-reporting-page--active').after($div);
    }
};

fixmystreet.set_up = fixmystreet.set_up || {};
$.extend(fixmystreet.set_up, {
  basics: function() {
    // Preload the new report pin
    document.createElement('img').src = '/i/pins/' + (fixmystreet.pin_new_report_colour || 'green') + '/pin.png';

    $('a[href*="around"]').each(function() {
        this.href = this.href + (this.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    });
    $('input[name="js"]').val(1);
    $('form[action*="around"]').each(function() {
        $('<input type="hidden" name="js" value="1">').prependTo(this);
    });

    // Focus on postcode box on front page
    $('#pc').trigger('focus');

    // In case we've come here by clicking back to a form that disabled a submit button
    $('form.validate input[type=submit]').prop('disabled', false);

    $('[data-confirm]').on('click', function() {
        return confirm(this.getAttribute('data-confirm'));
    });
  },

  questionnaire: function() {
    // Questionnaire hide/showings
    if (!$('#been_fixed_no').prop('checked') && !$('#been_fixed_unknown').prop('checked')) {
        $('.js-another-questionnaire').hide();
    }
    $('#been_fixed_no').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_unknown').on('click', function() {
        $('.js-another-questionnaire').show('fast');
    });
    $('#been_fixed_yes').on('click', function() {
        $('.js-another-questionnaire').hide('fast');
    });
  },

  form_validation: function() {
    // FIXME - needs to use translated string
    if (jQuery.validator) {
        jQuery.validator.addMethod('validCategory', function(value, element) {
            return this.optional(element) || value != ''; }, translation_strings.category );
        jQuery.validator.addMethod('js-password-validate', function(value, element) {
            return !value || value.length >= fixmystreet.password_minimum_length;
        }, translation_strings.password_register.short.replace(/%d/, fixmystreet.password_minimum_length));
        jQuery.validator.addMethod('notEmail', function(value, element) {
            return this.optional(element) || !/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:\S{1,63})$/.test( value ); }, translation_strings.title );
        jQuery.validator.addMethod('in-the-past', function(value, element) {
            return this.optional(element) || new Date(value) <= new Date(); }, translation_strings.in_the_past );
        jQuery.validator.addClassRules('at-least-one-group', { require_from_group: [1, ".at-least-one-group"] });
    }

    var submitted = false;

    var defaultMessage = jQuery.validator.prototype.defaultMessage;
    jQuery.validator.prototype.defaultMessage = function() {
        var message = defaultMessage.apply(this, arguments);
        message = '<span class="visuallyhidden">' + translation_strings.error + ':</span> ' + message;
        return message;
    };

    $("form.validate").each(function(){
      fixmystreet.validator = $(this).validate({
        rules: validation_rules,
        messages: translation_strings,
        onkeyup: false,
        onfocusout: false,
        errorElement: 'div',
        errorClass: 'form-error',
        errorPlacement: function( error, element ) {
            if (element.hasClass('group-error-propagate')) {
                var groupParent = element.parents('.group-error-propagate-end');
                if (groupParent) {
                    var target = groupParent.find('.group-error-place-after');
                    if (target) {
                        target.after(error);
                        return;
                    }
                }
            }
            var typ = element.attr('type');
            if (typ == 'radio' || typ == 'checkbox') {
                element.parent().before( error );
            } else {
                element.before( error );
            }
        },
        submitHandler: function(form) {
            $('input[type=submit][data-disable]', form).prop("disabled", true);
            form.submit();
        },
        // make sure we can see the error message when we focus on invalid elements
        showErrors: function( errorMap, errorList ) {
            if ( submitted && errorList.length ) {
                var currScroll = $('#map_sidebar').scrollTop(),
                    pos = $(errorList[0].element).position().top;
               $('#map_sidebar').scrollTop( currScroll + pos - 120 );
            }
            this.defaultShowErrors();
            submitted = false;
        },
        invalidHandler: function(form, validator) { submitted = true; }
      });
    });

    /* set correct required status depending on what we submit */
    $('.js-submit_sign_in').on('click', function(e) {
        $('.js-form-name').removeClass('required').removeAttr('aria-required');
    } );

    $('.js-submit_register').on('click', function(e) {
        $('.js-form-name').addClass('required').attr('aria-required', true);
    } );

    $('#facebook_sign_in, #twitter_sign_in, #oidc_sign_in').on('click', function(e){
        $('#username, #form_username_register, #form_username_sign_in').removeClass('required');
    });

    $('#planned_form').on('submit', function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }

        e.preventDefault();
        var $form = $(this);
        var $submit = $('button[form="planned_form"]');
        var problemId = $form.find("input[name='id']").val();
        var data = $form.serialize() + '&ajax=1';

        $.post(this.action, data, function(data) {
            var inputName, newInputName, buttonLabel, buttonValue, classToAdd, classToRemove;

            if (data.outcome === 'add') {
                inputName = 'shortlist-add';
                newInputName = 'shortlist-remove';
                buttonLabel = $submit.data('label-remove');
                buttonValue = $submit.data('value-remove');
                classToAdd = $submit.data('class-remove');
                classToRemove = $submit.data('class-add');
                $('.shortlisted-status').remove();
                $(document).trigger('shortlist-add', problemId);
            } else if (data.outcome === 'remove') {
                inputName = 'shortlist-remove';
                newInputName = 'shortlist-add';
                buttonLabel = $submit.data('label-add');
                buttonValue = $submit.data('value-add');
                classToAdd = $submit.data('class-add');
                classToRemove = $submit.data('class-remove');
                $(document).trigger('shortlist-remove', problemId);
            }

            $form.find("input[name='" + inputName + "']").attr('name', newInputName);
            $submit.text(buttonValue)
                   .attr('aria-label', buttonLabel)
                   .removeClass(classToRemove)
                   .addClass(classToAdd);
        });
    });

    // Format account number and sort code
    $('#bank-details-form').bankDetailsFormatter();
  },

  autocomplete: function() {
    $('.js-autocomplete').each(function() {
        var $this = $(this);
        if (this.style.display === 'none') return; // Already set up
        accessibleAutocomplete.enhanceSelectElement({
            selectElement: this,
            displayMenu: 'overlay',
            required: $(this).prop('required') ? true : false,
            showAllValues: true,
            defaultValue: '',
            confirmOnBlur: false,
            onConfirm: function(label) {
                // If the user selects a value in the autocomplete dropdown, update the hidden 'select' element.
                // https://github.com/alphagov/accessible-autocomplete/issues/322
                var match = [].filter.call(this.selectElement.options, function(e){
                    return (e.textContent||e.innerText) === label;
                })[0];
                if (match) {
                    match.selected = true;
                    // Trigger a change event
                    $this.trigger("change");
                }
            }
        });
    });
  },

  category_change: function() {
    // Deal with changes to report category.

    function text_update(id, str) {
        var $id = $(id);
        if (!$id.data('original')) {
            $id.data('original', $id.text());
        }
        if (str) {
            $id.text(str);
        } else {
            $id.text($id.data('original'));
        }
    }

    var category_changed = function(category) {
        if (!fixmystreet.reporting_data) {
            return; // This will be called again when the data arrives
        }

        var data = fixmystreet.reporting_data.by_category[category] || {},
            $category_meta = $('#category_meta');

        if (!$.isEmptyObject(data)) {
            fixmystreet.bodies = data.bodies || [];
            fixmystreet.selected_category_data = data;

        } else {
            fixmystreet.bodies = fixmystreet.reporting_data.bodies || [];
            fixmystreet.selected_category_data = {};
        }
        if (fixmystreet.body_overrides) {
            fixmystreet.body_overrides.clear();
        }

        if (data.councils_text) {
            fixmystreet.update_councils_text(data);
        } else {
            // Use the original returned texts
            fixmystreet.update_councils_text(fixmystreet.reporting_data);
        }
        if (data.category_extra) {
            $category_meta.replaceWith( data.category_extra );
            var $new_category_meta = $('#category_meta');
            $new_category_meta.closest('.js-reporting-page').toggleClass('js-reporting-page--skip', !!data.extra_hidden);
            // Preserve any existing values
            $category_meta.find("[name]").each(function() {
                $new_category_meta.find("[name='"+this.name+"']").val(this.value);
            });
        } else {
            $category_meta.closest('.js-reporting-page').addClass('js-reporting-page--skip');
            $category_meta.empty();
        }
        if (data.non_public) {
            $(".js-hide-if-private-category").hide();
            $(".js-hide-if-public-category").removeClass("hidden-js").show();
            $('#form_non_public').prop('checked', true).prop('disabled', true);
        } else {
            $(".js-hide-if-private-category").show();
            $(".js-hide-if-public-category").hide();
            $('#form_non_public').prop('checked', false).prop('disabled', false);
        }
        if (data.category_photo_required) {
            $(".js-hide-if-category-photo-required").addClass('hidden-js');
        } else {
            $(".js-hide-if-category-photo-required").removeClass('hidden-js');
        }
        if (data.allow_anonymous) {
            $('.js-show-if-anonymous').removeClass('hidden-js');
            $('.js-reporting-page--include-if-anonymous').removeClass('js-reporting-page--skip');
        } else {
            $('.js-show-if-anonymous').addClass('hidden-js');
            $('.js-reporting-page--include-if-anonymous').addClass('js-reporting-page--skip');
        }
        if (data.phone_required) {
            $("#form_phone").prop('required', true);
            $("#js-optional-phone").hide();
        } else {
            $("#form_phone").prop('required', false);
            $("#js-optional-phone").show();
        }

        text_update('#title-label', data.title_label);
        text_update('#title-hint', data.title_hint);
        text_update('#detail-label', data.detail_label);
        text_update('#detail-hint', data.detail_hint);

        if (fixmystreet.message_controller && data.disable_form && data.disable_form.questions) {
            $.each(data.disable_form.questions, function(_, question) {
                if (question.message && question.code) {
                    $('#form_' + question.code).on('change.category', function() {
                        $(fixmystreet).trigger('report_new:category_change', { skip_duplicates: true } );
                    });
                }
            });
        }

        // remove existing validation rules
        validation_rules = fixmystreet.validator.settings.rules;
        $.each(validation_rules, function(rule) {
             var $el = $('#form_' + rule);
             if ($el.length) {
                 $el.rules('remove');
             }
        });
        // apply new validation rules
        fixmystreet.set_up.reapply_validation(core_validation_rules);
        $.each(fixmystreet.bodies, function(index, body) {
            if ( typeof body_validation_rules !== 'undefined' && body_validation_rules[body] ) {
                var rules = body_validation_rules[body];
                fixmystreet.set_up.reapply_validation(rules);
            }
        });

        // unhide hidden elements
        $.each(fixmystreet.hidden_elements, function(index, element) {
            element.show();
        });
        fixmystreet.hidden_elements = [];

        // Hide shown elements (that were previously triggered via
        // show_element_rules). This prevents elements from remaining
        // displayed if user clicks back to select another category.
        $.each(fixmystreet.shown_elements, function() {
            this.classList.add('hidden');
        });
        fixmystreet.shown_elements = [];

        // apply hide & show element rules
        var selectors;
        $.each(fixmystreet.bodies, function(index, body) {
            if ( typeof hide_element_rules !== 'undefined' && hide_element_rules[body] && hide_element_rules[body][category] ) {
                selectors = hide_element_rules[body][category];
                $(selectors.join(',')).each(function () {
                    if ($(this).css('display') === 'none') {
                        return;
                    }
                    $(this).hide();
                    fixmystreet.hidden_elements.push($(this));
                });
            }

            if ( typeof show_element_rules !== 'undefined' &&
                show_element_rules[body] &&
                show_element_rules[body][category] )
            {
                selectors = show_element_rules[body][category];
                $(selectors.join(',')).each(function () {
                    this.classList.remove('hidden');
                    fixmystreet.shown_elements.push(this);
                });
            }
        });

        $(fixmystreet).trigger('report_new:category_change');
    };
    fixmystreet.reporting.topLevelPoke = function() {
        var checked = $("#form_category_fieldset input:checked");
        if (checked.length) {
            checked.trigger('change');
        } else {
            var $subcategory_page = $('.js-reporting-page--subcategory');
            $subcategory_page.addClass('js-reporting-page--skip');
            category_changed('');
        }
    };

    // Delegation is necessary because category/subcategory may be replaced during the lifetime of the page
    $("#problem_form").on("change.category", '[name^="category."]', function() {
        category_changed($(this).val());
    });
    $("#problem_form").on("change.category", "[name=category]", function(e, no_event){
        // First we need to check if we are picking a group or a category
        var $subcategory_page = $('.js-reporting-page--subcategory');
        var subcategory_id = $(this).data("subcategory");
        $(".js-subcategory").addClass('hidden-js');
        var val;
        if (subcategory_id === undefined) {
            $subcategory_page.addClass('js-reporting-page--skip');
            val = $(this).data('valuealone'); // Don't want "H" hoisted bit of the submitted value
        } else {
            $subcategory_page.removeClass('js-reporting-page--skip');
            var $subcategory = $("#subcategory_" + subcategory_id);
            $subcategory.removeClass('hidden-js');
            val = $subcategory.find('input:checked').val();
        }
        if (!no_event) {
            category_changed(val);
        }
    });

    // If we haven't got any reporting data (e.g. came straight to
    // /report/new), fetch it first. That will then automatically call this
    // function again, due to it calling change() on the category if set.
    if (!fixmystreet.reporting_data && fixmystreet.page === 'new' && !$('body').hasClass('formflow')) {
        fixmystreet.fetch_reporting_data();
    }
  },

  category_filtering: function(subsequent) {
    var category_row = document.getElementById('form_category_row');
    var category_fieldset = document.getElementById('form_category_fieldset');
    var category_filter = document.getElementById('category-filter');
    if (!category_row || !category_fieldset || !category_filter) {
        return;
    }
    /* Make copy of subcats for direct display if matching filter */
    document.querySelectorAll('#form_subcategory_row fieldset').forEach(function(fieldset) {
        var copy = fieldset.cloneNode(true);
        var group_id = copy.id.replace('subcategory_', '');
        copy.id = 'js-filter-' + copy.id;
        copy.classList.remove('js-subcategory');
        copy.classList.add('js-filter-subcategory');

        copy.addEventListener('change', function(evt) {
            // A subcategory has been picked in this copy. Update the actual entry
            var target = evt.target;
            var actual_id = target.id.replace('js-filter-', '');
            var group_id = target.name.replace('js-filter-category\.', '');
            var actual = document.getElementById(actual_id);

            // Remove any other selected things
            category_row.querySelectorAll("input").forEach(function(input) {
                if (input !== target) {
                    input.checked = false;
                }
            });

            // Select the right category
            category_fieldset.querySelector('#category_' + group_id).checked = true;
            // Select the right subcategory
            actual.checked = true;
            // Mark the subcategory page as skippable
            document.querySelector('.js-reporting-page--subcategory').classList.add('js-reporting-page--skip');
            // Trigger a change event on the choice
            var event = document.createEvent('HTMLEvents');
            event.initEvent('change', true, false);
            actual.dispatchEvent(event);
        });
        // Update all the items to have unique IDs
        copy.querySelectorAll('.govuk-radios__item').forEach(function(item) {
            var input = item.querySelector('input');
            var label = item.querySelector('label');
            input.id = 'js-filter-' + input.id;
            input.name = 'js-filter-' + input.name;
            input.classList.remove('required');
            label.htmlFor = 'js-filter-' + label.htmlFor;
        });

        // Insert the copy just after the category option these are the subcategories for
        var category_div = category_fieldset.querySelector('#category_' + group_id).parentNode;
        category_fieldset.insertBefore(copy, category_div.nextSibling);
    });

    /* If category picked, make sure to uncheck all copy-of-subcategories */
    category_fieldset.addEventListener("change", function(e) {
        if (e.target.name === 'category') {
            document.querySelectorAll('.js-filter-subcategory input').forEach(function(input) {
                input.checked = false;
            });
        }
    });

    /* Update when key lifted in search box */
    var filter_keyup = function() {
        var items = category_row.querySelectorAll(".govuk-radios__item");
        var i;
        if (this.value) {
            var haystack = [];
            items.forEach(function(item) {
                item.querySelector('input').checked = false;
                var txt = item.textContent;
                haystack.push(txt);
            });
            var uf = new uFuzzy();
            var results = uf.search(haystack, this.value, 1);
            var subcats_to_show = {};
            for (i = 0; i<items.length; i++) {
                var input = items[i].querySelector('input'),
                    match = !(results[0] && results[0].indexOf(i) < 0),
                    in_matching_subcat = subcats_to_show[input.name];
                items[i].classList.toggle('hidden-category-filter', !(in_matching_subcat || match));
                if (match && input.name !== 'category') {
                    // A subcategory, make sure category item is shown, disabled. We've already passed it in the loop
                    var group_id = input.name.replace('js-filter-category.', '');
                    var category_div = category_row.querySelector('#category_' + group_id).parentNode; // div
                    category_div.classList.remove('hidden-category-filter');
                    category_div.classList.add('js-filter-disabled');
                }
                // If this is a category with subcategories, show every item in the subcategory
                if (input.dataset.subcategory) {
                    items[i].classList.toggle('js-filter-disabled', match);
                    if (match) {
                        subcats_to_show['js-filter-category.' + input.dataset.subcategory] = true;
                    }
                }
            }
            // Show the fieldsets (their contents hidden/shown by the above)
            category_row.querySelectorAll('fieldset').forEach(function(fieldset) {
                fieldset.classList.remove('hidden-js');
            });
            /* If the filtering reduces the list to one, the web page becomes
             * so short that the bottom of the page moves down, underneath the
             * on-screen keyboard and your input box disappears. This feels like
             * a bug in the web browser but I doubt it is going to be fixed any
             * time soon. Introduce some padding so this does not happen. */
            category_row.style.paddingBottom = window.innerHeight + 'px';
            disable_on_empty();
        } else {
            // Hide all the copied subcategories
            document.querySelectorAll('.js-filter-subcategory').forEach(function(fieldset) {
                fieldset.classList.add('hidden-js');
            });
            for (i = 0; i<items.length; i++) {
                items[i].classList.remove('hidden-category-filter');
                items[i].classList.remove('js-filter-disabled');
            }
            category_row.style.paddingBottom = null;
            disable_on_empty();
        }

        function disable_on_empty() {
            // If there are no items found, give a message and disable the Continue button
            if (items.length && items.length === document.querySelectorAll(".hidden-category-filter").length) {
                $('#js-top-message').html('<p class="form-error" id="filter-category-error">Please try another search or delete your search and choose from the categories</p>');
                $('.js-reporting-page--next').prop("disabled",true);
                category_row.style.paddingBottom = null;
            } else {
                $('#filter-category-error').remove();
                $('.js-reporting-page--next').prop("disabled",false);
            }
        }
    };

    if (!subsequent) {
        category_filter.addEventListener('keyup', filter_keyup);
        category_filter.addEventListener('blur', function() {
            category_row.style.paddingBottom = null;
        });
        filter_keyup.apply(category_filter);
    }
  },

  reapply_validation: function(rules) {
        if (rules === undefined) {
            return;
        }
        $.each(rules, function(name, rule) {
            var $el = $('#form_' + name);
            if ($el.length) {
                $el.rules('add', rule);
                if (rule.maxlength) {
                  $el.attr('maxlength', rule.maxlength);
                } else {
                  $el.removeAttr('maxlength');
                }
                if (rule.required) {
                  $el.attr('aria-required', true);
                }
            }
        });
  },

  hide_name: function() {
      $('body').on('click', '.js-hide-name', function(e){
          e.preventDefault();

          var $p = $(this).parents('p');
          var $form = $p.next('.hide-name-form'); // might not exist yet
          var url = $(this).attr('href');

          if ($form.length) {
              $form.slideUp(function(){
                  $form.remove();
              });
          } else {
              $.get(url).done(function(html){
                  $(html).find('.hide-name-form').hide().insertAfter($p).slideDown();
              }).fail(function(){
                  window.location.href = url;
              });
          }
      });
  },

  on_resize: function() {
    var last_type;
    $(window).on('resize', function() {
        var type = Modernizr.mq('(min-width: 48em)') ? 'desktop' : 'mobile';
        if (last_type == type) { return; }
        if (type == 'mobile') {
            fixmystreet.resize_to.mobile_page();
        } else {
            fixmystreet.resize_to.desktop_page();
        }
        $('#form_service').val(type);
        last_type = type;
    }).trigger('resize');
  },

  dropzone: function($context) {
    if ('Dropzone' in window) {
        Dropzone.autoDiscover = false;
      } else {
        return;
      }

    // we don't want to create this if we're offline (e.g using the inspector
    // panel to add a photo) as the server side bit does not work.
    if (!navigator.onLine) {
      return;
    }

    // Pass a jQuery element, eg $('.foobar'), into this function
    // to limit all the selectors to that element. Handy if you want
    // to only bind/detect Dropzones in a particular part of the page,
    // or if your selectors (eg: "#form_photo") aren't unique across
    // the whole page.
    if (typeof $context === undefined) {
        $context = $(document);
    }

    var forms = $('[for="form_photo"], .js-photo-label', $context).closest('form');
    forms.each(function() {
      // Internal $context is the individual form with the photo upload inside
      var $context = $(this);
      var $originalLabel = $('[for="form_photo"], .js-photo-label', $context);
      var $originalInputs = $('#form_photos, .js-photo-fields', $context);
      $originalInputs.each(function() {
        var $originalInput = $(this);
        if ($originalInput.css('display') === 'none') return; // Already set up
        var $dropzone = $('<div tabindex=0 role="button">').addClass('dropzone');
        var $fileid_input = $originalInput.data('upload-field') || 'upload_fileid';
        var max_photos = !isNaN($originalInput.data('max-photos')) ? $originalInput.data('max-photos') : 3;

        $('[data-plural]', $originalLabel).text(
            $('[data-plural]', $originalLabel).attr('data-plural')
        );
        $originalInput.hide();

        $dropzone.insertAfter($originalInput);
        var default_message = translation_strings.upload_default_message;
        if ($("html").hasClass("mobile")) {
            default_message = translation_strings.upload_default_message_mobile;
        }
        var prevFile;
        var photodrop = new Dropzone($dropzone[0], {
            url: '/photo/upload?get_latlon=1',
            paramName: 'photo',
            maxFiles: max_photos,
            addRemoveLinks: true,
            thumbnailHeight: 150,
            thumbnailWidth: 150,
            // resizeWidth: 2048,
            // resizeHeight: 2048,
            // resizeQuality: 0.6,
            acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png,.png,.tiff,.tif,.gif,.jpeg,.jpg',
            dictDefaultMessage: default_message,
            dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
            dictInvalidFileType: translation_strings.upload_invalid_file_type,
            dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,

            fallback: function() {
              $dropzone.remove();
              $('[data-singular]', $originalLabel).text(
                $('[data-singular]', $originalLabel).attr('data-singular')
              );
              $originalInput.show();
            },
            init: function() {
              // Add aria-label for accessibility
              // From https://github.com/dropzone/dropzone/pull/2214
              this.hiddenFileInput.setAttribute("aria-label", "hidden file upload");

              this.on("addedfile", function(file) {
                if (max_photos == 1 && prevFile) {
                    this.removeFile(prevFile);
                }
                $('input[type=submit]', $context).prop("disabled", true);
              });
              this.on("queuecomplete", function() {
                $('input[type=submit]', $context).prop('disabled', false);
              });
              this.on("success", function(file, xhrResponse) {
                var $upload_fileids = $('input[name="' + $fileid_input + '"]', $context);
                var ids = [];
                // only split if it has a value otherwise you get a spurious empty string
                // in the array as split returns the whole string if no match
                if ( $upload_fileids.val() ) {
                    ids = $upload_fileids.val().split(',');
                }
                var id = (file.server_id = xhrResponse.id),
                    l = ids.push(id);
                newstr = ids.join(',');
                $upload_fileids.val(newstr);
                if (max_photos == 1) {
                    prevFile = file;
                }
              });
              this.on("error", function(file, errorMessage, xhrResponse) {
              });
              this.on("removedfile", function(file) {
                var $upload_fileids = $('input[name="' + $fileid_input + '"]', $context);
                var ids = $upload_fileids.val().split(','),
                    newstr = $.grep(ids, function(n) { return (n!=file.server_id); }).join(',');
                $upload_fileids.val(newstr);
                if (max_photos == 1) {
                    prevFile = null;
                }
              });
              this.on("maxfilesexceeded", function(file) {
                this.removeFile(file);
                var $message = $('<div class="dz-message dz-error-message">');
                $message.text(translation_strings.upload_max_files_exceeded);
                $message.prependTo(this.element);
                setTimeout(function() {
                $message.slideUp(250, function() {
                    $message.remove();
                });
                }, 2000);
              });
            }
        });

        // Delete pictures when item is deleted on bulky waste
        $(this).closest('.bulky-item-wrapper').find('.delete-item').click(function(){
            photodrop.removeAllFiles(true);
        });

        $dropzone.on('keydown', function(e) {
            if (e.keyCode === 13 || e.keyCode === 32) {
                $dropzone.trigger('click');
            }
        });

        $.each($('input[name="' + $fileid_input + '"]', $context).val().split(','), function(i, f) {
            if (!f) {
                return;
            }
            var mockFile = { name: f, server_id: f, dataURL: '/photo/temp.' + f, status: Dropzone.SUCCESS, accepted: true };
            photodrop.emit("addedfile", mockFile);
            photodrop.createThumbnailFromUrl(mockFile,
                photodrop.options.thumbnailWidth, photodrop.options.thumbnailHeight,
                photodrop.options.thumbnailMethod, true, function(thumbnail) {
                    photodrop.emit('thumbnail', mockFile, thumbnail);
                });
            photodrop.emit("complete", mockFile);
            photodrop.files.push(mockFile);
            photodrop._updateMaxFilesReachedClass();
            prevFile = mockFile;
        });
      });
    });
  },

  report_list_filters: function() {
    // Hide the pin filter submit button. Not needed because we'll use JS
    // to refresh the map when the filter inputs are changed.
    $(".report-list-filters-wrapper [type=submit]").hide();

    // There are also other uses of this besides report list filters activated here
    $('.js-multiple').make_multi();

    // Make clicking on Everything when selected un-select everything (workaround)
    var $elt = $('#filter_categories');
    var all_label = $elt.data('all');
    $('label:contains("' + all_label + '") input[name="filter_category_presets"]').on('click', function(e) {
        var options = $elt.find('option').length;
        var selected = $elt.find('option:selected').length;
        if (selected === options) {
            $elt.val([]);
            $elt.trigger('change');
        }
    });

    // Make clicking on the legends toggle all the checkboxes underneath
    var container = $elt.next('.multi-select-container');
    container.on('click', 'legend', function(){
        var optgroup = $elt.find('optgroup[label="' + this.textContent + '"]');
        var options = optgroup.find('option');
        var options_selected = options.filter(':selected');

        if (options.length === options_selected.length) {
            // Switch them all off
            options_selected.prop('selected', false);
        } else {
            // Switch them all on
            options.not(options_selected).prop('selected', true);
        }
        $elt.trigger('change');
    });

    function update_label(id, str) {
        $(id).prevAll('label').addClass('hidden-js').attr('for', id.slice(1)).after(function(){ return $('<span>' + this.innerHTML + '</span>'); });
        $(id).next('.multi-select-container').children('.multi-select-button').attr('aria-label', str);
    }
    update_label('#statuses', translation_strings.select_status_aria_label);
    update_label('#filter_categories', translation_strings.select_category_aria_label);
  },

  has_selector_checker: function() {
    var supportsHas = CSS.supports('selector(:has(*))');

    if (!supportsHas) {
        $('.govuk-multi-select__label').each(function() {
            var label = $(this);
            var input = label.find('input[type="checkbox"], input[type="radio"]');

            if (input.attr('type') === 'checkbox') {
              label.addClass('govuk-multi-select__label--checkbox');
            } else if (input.attr('type') === 'radio') {
              label.addClass('govuk-multi-select__label--radio');
            }

            if (input.prop('checked')) {
              label.addClass('govuk-multi-select__label--checked');
            }

            input.on('change', function() {
              if (this.checked) {
                label.addClass('govuk-multi-select__label--checked');
              } else {
                label.removeClass('govuk-multi-select__label--checked');
              }
            });
          });
    }
  },

  label_accessibility_update: function() {
    // Replace unnecessary labels with a span and include a
    // proper aria-label to improve accessibility.
    function replace_label(id, sibling_class, sibling_child, str) {
        $(id).siblings(sibling_class).children(sibling_child).attr('aria-label', str);
        $(id).addClass('hidden-js').after(function(){ return $('<span class="label">' + this.innerHTML + '</span>'); });
    }
    replace_label('#photo-upload-label','.dropzone.dz-clickable', '.dz-default.dz-message', translation_strings.upload_aria_label);
  },

  // Very similar function in front.js for front page
  on_mobile_nav_click: function() {
    var html = document.documentElement;
    if (!html.classList) {
      return;
    }

    var modal = document.getElementById('js-menu-open-modal'),
        nav = document.getElementById('main-nav'),
        nav_checkbox = document.getElementById('main-nav-btn');
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
  },

  clicking_banner_begins_report: function() {
    $('.big-green-banner,.map-mobile-report-button').on('click', function(){
      if (fixmystreet.map.getCenter) {
        fixmystreet.display.begin_report( fixmystreet.map.getCenter() );
      }
    });
  },

  report_a_problem_btn: function() {
    $(fixmystreet).on('maps:update_view', fixmystreet.update_report_a_problem_btn);

    // Hide button on new report page.
    if ( fixmystreet.page === 'new' ) {
      $('.report-a-problem-btn').hide();
    }

    $('.report-a-problem-btn').on('click', function(e){
      if (e.metaKey || e.ctrlKey) {
          return;
      }
      var url = this.href;
      if ( url.indexOf('report/new') > -1 ) {
        try {
          e.preventDefault();
          fixmystreet.display.begin_report( fixmystreet.map.getCenter() );
        } catch (error) {
          window.location = url;
        }
      }
    });
  },

  map_controls: function() {
    //add links container (if its not there)
    if ($('#sub_map_links').length === 0) {
        $('<p class="sub-map-links" id="sub_map_links" />').insertAfter($('#map'));
    }

    if ($('.mobile').length) {
        // Make sure we end up with one Get updates link
        if ($('#key-tools a.js-feed').length) {
            $('#sub_map_links a.js-feed').remove();
            $('#key-tools a.js-feed').appendTo('#sub_map_links');
        }
        $('#key-tools li:empty').remove();
        $('#report-updates-data').insertAfter($('#map_box'));
        if (fixmystreet.page !== 'around' && fixmystreet.page !== 'new' && !$('#toggle-fullscreen').length) {
            $('#sub_map_links').append('<a href="#" id="toggle-fullscreen" data-expand-text="'+ translation_strings.expand_map +'" data-compress-text="'+ translation_strings.collapse_map +'" >'+ translation_strings.expand_map +'</span>');
        }
    }

    // Show/hide depending on whether it has any children to show
    if ($('#sub_map_links a').not('.hidden').length) {
        $('#sub_map_links').show();
    } else {
        $('#sub_map_links').hide();
    }

    //add open/close toggle button (if its not there)
    if ($('#map_links_toggle').length === 0) {
        $('<span>')
            .attr('id', 'map_links_toggle')
            .on('click', function() {
                var sub_map_links_css = {},
                    left_right = isR2L() ? 'left' : 'right';
                if ($(this).hasClass('closed')) {
                    $(this).removeClass('closed');
                    sub_map_links_css[left_right] = '0';
                } else {
                    $(this).addClass('closed');
                    sub_map_links_css[left_right] = -$('#sub_map_links').width();
                }
                $('#sub_map_links').animate(sub_map_links_css, 1200);
            })
            .prependTo('#sub_map_links');
    }

    $('#toggle-fullscreen').off('click').on('click', function(e) {
      e.preventDefault();
      var btnClass = $('html').hasClass('map-fullscreen') ? 'expand' : 'compress';
      var text = $(this).data(btnClass + '-text');

      // Inspector form asset changing
      if ($('html').hasClass('map-fullscreen') && $('.btn--change-asset').hasClass('asset-spot')) {
          $('.btn--change-asset').trigger('click');
      }

      $('html, body').scrollTop(0);
      $('html').toggleClass('map-fullscreen only-map');
      $(this).html(text).attr('class', btnClass);

      fixmystreet.map.updateSize();
    });
  },

  map_sidebar_key_tools: function() {
    if ($('html.mobile').length) {
        $('#council_wards').hide().removeClass('hidden-js').find('h2').hide();
        $('#key-tool-wards').off('click.wards');
        $('#key-tool-wards').on('click.wards', function(e) {
            e.preventDefault();
            $('#council_wards').slideToggle('800', function() {
              $('#key-tool-wards').toggleClass('hover');
            });
        });
    } else {
        $('#key-tool-wards').drawer('council_wards', false);
        $('#key-tool-around-updates').drawer('updates_ajax', true);
    }
    $('.js-key-tool-report-updates').each(function() {
        $(this).small_drawer('report-updates-data');
    });
  },

  ward_select_multiple: function() {
    $(".js-ward-select-multiple").on('click', function(e) {
        e.preventDefault();
        var sect = $(this).closest('section');
        sect.find(".js-ward-single").addClass("hidden");
        sect.find(".js-ward-multi").removeClass("hidden");
    });
  },

  offline_draft: function() {
    if (fixmystreet.offlineReporting) {
        fixmystreet.offlineReporting.reportNewSetup();
    }
  },

  page_controller: function() {
    // Delegation because e.g. National Highways button gets added
    $('#problem_form, #form_update_form').on('click', '.js-reporting-page .js-reporting-page--next', function(e) {
        e.preventDefault();
        var v = $(this).closest('form').validate();
        if (!v.form()) {
            v.focusInvalid();
            return;
        }
        fixmystreet.pageController.toPage('next');
    });

    $(document).on('click', '.js-back', function(e) {
        e.preventDefault();
        history.back();
    });
  },

  email_login_form: function() {
    // Password form split up
    $('.js-sign-in-password-btn').on('click', function(e) {
        if ($('.js-sign-in-password').is(':visible')) {
        } else {
            e.preventDefault();
            $('.js-sign-in-password-hide').hide();
            $('.js-sign-in-password').show().css('visibility', 'visible');
            $('#password_sign_in').trigger('focus');
        }
    });
    // This is if the password box is filled programmatically (by
    // e.g. 1Password), show it so that it will auto-submit.
    $('#password_sign_in').on('change', function() {
        $('.js-sign-in-password').show().css('visibility', 'visible');
    });

    $('[name=sign_in_by_code]').on('click', function() {
        $('#password_sign_in').removeClass('required');
    });

    var show = function(selector) {
        var deferred = $.Deferred();
        $(selector).hide().removeClass('hidden-js').slideDown(400, function(){
            $(this).css('display', '');
            deferred.resolveWith(this);
        });
        return deferred.promise();
    };

    var hide = function(selector) {
        var deferred = $.Deferred();
        $(selector).slideUp(400, function(){
            $(this).addClass('hidden-js').css('display', '');
            deferred.resolveWith(this);
        });
        return deferred.promise();
    };

    var focusFirstVisibleInput = function() {
        // Ignore logged-in form here, because it should all be pre-filled already!
        $('#form_sign_in_yes input, #form_sign_in_no input').filter(':visible').eq(0).trigger('focus');
    };

    // Display tweak
    $('.js-new-report-sign-in-hidden.form-box, .js-new-report-sign-in-shown.form-box').removeClass('form-box');

    $('.js-new-report-user-hide').on('click', function(e) {
        e.preventDefault();
        $('.js-new-report-user-shown')[0].scrollIntoView({behavior: "smooth"});
        hide('.js-new-report-user-shown');
        show('.js-new-report-user-hidden');
    });
    $('.js-new-report-user-show').on('click', function(e) {
        e.preventDefault();
        var v = $(this).closest('form').validate();
        if (!v.form()) {
            v.focusInvalid();
            return;
        }
        $('.js-new-report-user-hidden')[0].scrollIntoView({behavior: "smooth"});
        hide('.js-new-report-user-hidden');
        show('.js-new-report-user-shown').then(function(){
            $(this).find('.form-section-preview h2').trigger('focus');
        });
    });

    $('.js-new-report-show-sign-in').on('click', function(e) {
        e.preventDefault();
        $('.js-new-report-sign-in-shown').removeClass('hidden-js');
        $('.js-new-report-sign-in-hidden').addClass('hidden-js');
        focusFirstVisibleInput();
    });

    $('.js-new-report-hide-sign-in').on('click', function(e) {
        e.preventDefault();
        $('.js-new-report-sign-in-shown').addClass('hidden-js');
        $('.js-new-report-sign-in-hidden').removeClass('hidden-js');
        focusFirstVisibleInput();
    });

    $('.js-new-report-sign-in-forgotten').on('click', function(e) {
        e.preventDefault();
        $('.js-new-report-sign-in-shown').addClass('hidden-js');
        $('.js-new-report-sign-in-hidden').removeClass('hidden-js');
        $('.js-new-report-forgotten-shown').removeClass('hidden-js');
        $('.js-new-report-forgotten-hidden').addClass('hidden-js');
        focusFirstVisibleInput();
    });

    // XXX Is this still needed, should it be better done server side? Will need to spot multiple pages too
    var err = $('.form-error');
    if (err.length) {
        $('.js-sign-in-password-btn').trigger('click');
        if (err.closest(".js-new-report-sign-in-shown").length) {
            $('.js-new-report-user-shown').removeClass('hidden-js');
            $('.js-new-report-user-hidden').addClass('hidden-js');
            $('.js-new-report-sign-in-shown').removeClass('hidden-js');
            $('.js-new-report-sign-in-hidden').addClass('hidden-js');
        } else if (err.closest('.js-new-report-sign-in-hidden, .js-new-report-user-shown').length) {
            $('.js-new-report-user-shown').removeClass('hidden-js');
            $('.js-new-report-user-hidden').addClass('hidden-js');
        }
    }
  },

  toggle_visibility: function() {
      $('[data-toggle-visibility]').each(function(){
        var $target = $( $(this).attr('data-toggle-visibility') );
          if ( $(this).is(':checkbox') ){
              var input = this;
              var update = function() {
                  $target.toggleClass('hidden-js', ! input.checked );
              };
              $(this).off('change.togglevisibility').on('change.togglevisibility', update);
              update();
          } else {
              $(this).off('click.togglevisibility').on('click.togglevisibility', function(){
                  $target.toggleClass('hidden-js');
              });
          }
      });

      $('input[type="radio"][data-show], input[type="radio"][data-hide]').each(function(){
          var update = function(){
              if ( this.checked ) {
                  var $showTarget = $( $(this).attr('data-show') );
                  var $hideTarget = $( $(this).attr('data-hide') );
                  $showTarget.removeClass('hidden-js');
                  $hideTarget.addClass('hidden-js');
              }
          };
          // off/on to make sure event handler is only bound once.
          $(this).off('change.togglevisibility').on('change.togglevisibility', update);
          update.call(this); // pass DOM element as `this`
      });

      $('option[data-show], option[data-hide]').each(function(){
          var $select = $(this).parent();
          var update = function(){
              var $option = $(this).find('option:selected');
              var $showTarget = $( $option.attr('data-show') );
              var $hideTarget = $( $option.attr('data-hide') );
              $showTarget.removeClass('hidden-js');
              $hideTarget.addClass('hidden-js');
          };
          // off/on to make sure event handler is only bound once.
          $select.off('change.togglevisibility').on('change.togglevisibility', update);
          update.call($select[0]); // pass DOM element as `this`
      });
  },

  form_section_previews: function() {
    $('.js-form-section-preview').each(function(){
        var $el = $(this);
        var $source = $( $el.attr('data-source') );
        $source.on('change', function(){
            var val = $source.val();
            if ( val.length > 80 ) {
                val = val.substring(0, 80) + '…';
            }
            $el.text( val );
        });
    });
  },

  reporting_required_phone_email: function() {
    var fem = $('#form_email');
    var fem_optional = $('#js-optional-email-update-method-triggered');
    var fph = $('#form_phone');
    var fph_optional = $('#js-optional-phone-update-method-triggered');

    $('#update_method_email').on('change', function() {
      fem.prop('required', true);
      fem_optional.addClass('hidden-js');
      if (!fixmystreet.selected_category_data.phone_required) {
          fph.prop('required', false);
          fph_optional.removeClass('hidden-js');
      } else {
          fph.prop('required', true);
          fph_optional.addClass('hidden-js');
      }
    });
    $('#update_method_phone').on('change', function() {
      fph.prop('required', true);
      fph_optional.addClass('hidden-js');
      fem.prop('required', false);
      fem_optional.removeClass('hidden-js');
    });
  },

  fancybox_images: function() {
    // Fancybox fullscreen images
    if (typeof $.fancybox == 'function') {
        $('a[rel=fancy]').fancybox({
            'overlayColor': '#000000'
        });
    }
  },

  alert_page_buttons: function() {
    // Go directly to RSS feed if RSS button clicked on alert page
    // (due to not wanting around form to submit, though good thing anyway)
    $('#distance').on('change', function() {
        var dist = this.value.replace(/,/, '.');
        if (!parseFloat(dist)) {
            return;
        }
        var a = $('a.js-alert-local');
        if (!a.data('originalHref')) {
            a.data('originalHref', a.attr('href'));
        }
        a.attr('href', a.data('originalHref') + '/' + dist);
    });
    $('body').on('click', '#alert_rss_button', function(e) {
        e.preventDefault();
        var val = $('input[name=feed][type=radio]:checked').val();
        var a = document.getElementById('rss-' + val);
        var feed = a.href;
        window.location.href = feed;
    });
    $('body').on('click', '#alert_email_button', function(e) {
        e.preventDefault();

        var wrapper = this.closest('.js-alert-list');
        var emailInput = wrapper.querySelector('input[type="email"]');
        if (emailInput) {
            emailInput.required = true;

            if (!$(this).closest('form').validate().form()) {
                emailInput.focus();
                return;
            }
        }

        var form = $('<form/>').attr({ method:'post', action:"/alert/subscribe" });
        form.append($('<input name="alert" value="Subscribe me to an email alert" type="hidden" />'));

        var inputs = wrapper.querySelectorAll('textarea, input[type=email], input[type=text], input[type=hidden], input[type=radio]:checked');
        [].forEach.call(inputs, function(i) {
            $('<input/>').attr({ name:i.name, value:i.value, type:'hidden' }).appendTo(form);
        });

        $('body').append(form);
        form.trigger('submit');
    });
  },

  ajax_history: function() {
    var around_map_state = null;

    $('#map_sidebar').on('click', '.item-list--reports a', function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }

        e.preventDefault();

        var reportPageUrl = $(this).attr('href');
        var reportId = parseInt(reportPageUrl.replace(/^.*\/([0-9]+)$/, '$1'), 10);

        // If we've already selected this report
        if (reportId == window.selected_problem_id) {
            if (fixmystreet.map.setCenter) {
                // Second click, zoom in to the report on the map
                var marker = fixmystreet.maps.get_marker_by_id(reportId);
                fixmystreet.map.setCenter(
                    marker.geometry.getBounds().getCenterLonLat(),
                    fixmystreet.map.getNumZoomLevels() - 1 );
                // replaceState rather than pushState so the back button returns
                // to the zoomed-out map with all pins.
                history.replaceState({
                    reportId: reportId,
                    reportPageUrl: reportPageUrl,
                    mapState: fixmystreet.maps.get_map_state()
                }, null);
            }
            return;
        }

        if (fixmystreet.page.match(/reports|around|my/)) {
            around_map_state = fixmystreet.maps.get_map_state();
            // Preserve the current map state in the current state so we can
            // restore it if the user navigates back. This needs doing here,
            // rather than the 'fake history' replaceState call that sets the
            // initial state, because the map hasn't been loaded at that point.
            // Also, filters might be changed before a report click.
            if ('state' in history && history.state && !history.state.mapState) {
                history.state.mapState = around_map_state;
                // NB can't actually modify current state directly, needs a
                // call to replaceState()
                history.replaceState(history.state, null);
            }
        }
        fixmystreet.display.report(reportPageUrl, reportId, function() {
            // Since this navigation was the result of a user action,
            // we want to record the navigation as a state, so the user
            // can return to it later using their Back button.
            if ('pushState' in history) {
                history.pushState({
                    reportId: reportId,
                    reportPageUrl: reportPageUrl,
                    mapState: fixmystreet.maps.get_map_state()
                }, null, reportPageUrl);
            }
        });
    });

    $('#map_sidebar').on('click', '.js-back-to-report-list', function(e) {
        var report_list_url = $(this).attr('href');
        var map_state = around_map_state;
        var set_map_state = true;
        fixmystreet.back_to_reports_list(e, report_list_url, map_state, set_map_state);
    });
  },

  expandable_list_items: function(){
      $(document).on('click', '.js-toggle-expansion', function(e) {
          e.preventDefault(); // eg: prevent button from submitting parent form
          var $toggle = $(this);
          var $parent = $toggle.closest('.js-expandable');
          $parent.toggleClass('expanded');
          $toggle.text($parent.hasClass('expanded') ? $toggle.data('less') : $toggle.data('more'));
      });

      $(document).on('click', '.js-expandable', function(e) {
          var $parent = $(this);
          // Ignore parents that are already expanded.
          if ( ! $parent.hasClass('expanded') ) {
              // Ignore clicks on action buttons (clicks on the
              // .js-toggle-expansion button will be handled by
              // the more specific handler above).
              if ( ! $(e.target).is('.item-list__item--expandable__actions *') ) {
                  e.preventDefault();
                  $parent.addClass('expanded');
                  var $toggle = $parent.find('.js-toggle-expansion');
                  $toggle.text($toggle.data('less'));
              }
          }
      });
  },

  mobile_content_navigation_bar: function() {
    $("#mobile-sticky-sidebar-button").click(function () {
        $(".sticky-sidebar").toggle(300);
    });
  }

});

fixmystreet.back_to_reports_list = function(e, report_list_url, map_state, set_map_state) {
    if (e.metaKey || e.ctrlKey) {
        return;
    }
    e.preventDefault();
    fixmystreet.display.reports_list(report_list_url, function() {
        // Since this navigation was the result of a user action,
        // we want to record the navigation as a state, so the user
        // can return to it later using their Back button.
        if ('pushState' in history) {
            history.pushState({
                initial: true,
                mapState: map_state
            }, null, report_list_url);
        }
        if (set_map_state && map_state) {
            fixmystreet.maps.set_map_state(map_state);
        }
    });
};

fixmystreet.update_report_a_problem_btn = function() {
    var zoom = fixmystreet.map.getZoom();
    var center = fixmystreet.map.getCenterWGS84();
    var new_report_url = '/report/new?longitude=' + center.lon.toFixed(6) + '&latitude=' + center.lat.toFixed(6);

    var href = '/';
    var visible = true;
    var text = translation_strings.report_a_problem_btn.default;

    if (fixmystreet.page === 'new') {
        visible = false;

    } else if (fixmystreet.page === 'report') {
        text = translation_strings.report_a_problem_btn.another;
        href = new_report_url;

    } else if (fixmystreet.page === 'around' && zoom > 1) {
        text = translation_strings.report_a_problem_btn.here;
        href = new_report_url;

    } else if (fixmystreet.page === 'reports' && zoom > 12) {
        text = translation_strings.report_a_problem_btn.here;
        href = new_report_url;
    }

    $('.report-a-problem-btn').attr('href', href).text(text).toggle(visible);
};

fixmystreet.update_public_councils_text = function(text, bodies) {
    bodies = bodies.join('</strong> ' + translation_strings.or + ' <strong>');
    text = text.replace(/<strong>.*<\/strong>/, '<strong>' + bodies + '</strong>');
    $('#js-councils_text').html(text);
};

fixmystreet.update_councils_text = function(data) {
    fixmystreet.update_public_councils_text(
        data.councils_text, fixmystreet.bodies);
    $('#js-councils_text_private').html(data.councils_text_private);
    $(fixmystreet).trigger('body_overrides:change');
};

// The new location will be saved to a history state unless
// savePushState is set to false.
fixmystreet.update_pin = function(lonlat, savePushState) {
    var lonlats = fixmystreet.maps.update_pin(lonlat);

    if ($('body').hasClass('formflow')) {
        // Do nothing for form flow map page
        return;
    }

    if (savePushState !== false) {
        if ('pushState' in history) {
            var newReportUrl = '/report/new?longitude=' + lonlats.url.lon + '&latitude=' + lonlats.url.lat;
            var newState = { newReportAtLonlat: lonlats.state };
            // If we're already in the reporting place, we want to replace state, it's a pin move
            if (fixmystreet.page === 'new') {
                history.replaceState(newState, null, newReportUrl);
            } else {
                history.pushState(newState, null, newReportUrl);
            }
        }
    }

    fixmystreet.fetch_reporting_data();

    if (!$('#side-form-error').is(':visible') && !$('#side-form').is(':visible')) {
        $('#side-form').show();
        $('#map_sidebar').scrollTop(0);
    }
};

(function() { // fetch_reporting_data closure

function re_select(group, category) {
    var group_id = group.replace(/[^a-z]+/gi, '');
    var cat_in_group = $("#subcategory_" + group_id + " input[value=\"" + category + "\"]");
    // Want only the group/category name itself, not the G| H| prefixes
    if (cat_in_group.length) {
        $('#form_category_fieldset input[data-valuealone="' + group + '"]')[0].checked = true;
        cat_in_group[0].checked = true;
    } else {
        var top_level = group || category;
        var top_level_match = $("#form_category_fieldset input[data-valuealone=\"" + top_level + "\"]");
        if (top_level && top_level_match.length) {
            top_level_match[0].checked = true;
        }
    }
}

// On the new report form, does this by asking for details from the server.
fixmystreet.fetch_reporting_data = function() {
    var he_arg = window.location.href.indexOf('&he_referral=1');
    he_arg = he_arg === -1 ? 0 : 1;
    $.getJSON('/report/new/ajax', {
        w: 1,
        latitude: $('#fixmystreet\\.latitude').val(),
        longitude: $('#fixmystreet\\.longitude').val(),
        he_referral: he_arg
    }, function(data) {
        if (data.error) {
            if (!$('#side-form-error').length) {
                $('<div id="side-form-error"/>').insertAfter($('#side-form'));
            }
            $('#side-form-error').html('<h1>' + translation_strings.reporting_a_problem + '</h1><p>' + data.error + '</p>').show();
            $('#side-form').hide();
            $('body').removeClass('with-notes');
            return;
        }
        $('#side-form-error').hide();
        $('#side-form').show();
        var filter_categories = $("#filter_categories").val() || '';
        var selected = fixmystreet.reporting.selectedCategory(),
            old_category_group = selected.group || $('#filter_group').val() || '',
            old_category = selected.category || filter_categories;

        // If we have one filter category selected and no group, try and get it from filter
        if (!old_category_group && !selected.category && filter_categories.length == 1) {
            var og = $("#filter_categories option:selected").parent().attr('label');
            if (og) {
                old_category_group = og;
            }
        }

        fixmystreet.reporting_data = data;

        fixmystreet.bodies = data.bodies || [];
        if (fixmystreet.body_overrides) {
            fixmystreet.body_overrides.clear();
        }

        if (data.bodies && data.bodies.indexOf('Bristol City Council') > -1) {
            $('#category-filter-div').hide();
        }

        fixmystreet.update_councils_text(data);
        $('#js-top-message').html(data.top_message || '');

        if (fixmystreet.message_controller) {
            fixmystreet.message_controller.unregister_all_categories();
            $.each(data.by_category, function(category, details) {
                if (!details.disable_form) {
                    return;
                }
                if (details.disable_form.all) {
                    fixmystreet.message_controller.register_category({
                        category: category,
                        message: details.disable_form.all
                    });
                }
                if (details.disable_form.questions) {
                    $.each(details.disable_form.questions, function(_, question) {
                        if (question.message && question.code) {
                            question.category = category;
                            question.keep_category_extras = true;
                            fixmystreet.message_controller.register_category(question);
                        }
                    });
                }
            });
        }

        $('#form_category_row').html(data.category);
        $('#form_subcategory_row').html(data.subcategories);
        if (data.preselected && (data.preselected.category || data.preselected.subcategory)) {
            re_select(data.preselected.category, data.preselected.subcategory);
        } else {
            re_select(old_category_group, old_category);
        }
        fixmystreet.reporting.topLevelPoke();

        fixmystreet.set_up.fancybox_images(); // In case e.g. top_message has pulled in a fancybox
        fixmystreet.set_up.category_filtering(true);

        if ( data.extra_name_info && !$('#form_fms_extra_title').length ) {
            // there might be a first name field on some cobrands
            var lb = $('#form_first_name').prev();
            if ( lb.length === 0 ) { lb = $('#form_name').prev(); }
            lb.before(data.extra_name_info);
        }

        if (data.contribute_as) {
            var $select = $('.js-contribute-as');
            if (!$select.data('original')) {
                $select.data('original', $select.html());
            }
            $select.html($select.data('original'));
            if (!data.contribute_as.another_user) {
                $select.find('option[value=another_user]').remove();
            }
            if (!data.contribute_as.anonymous_user) {
                $select.find('option[value=anonymous_user]').remove();
            }
            if (!data.contribute_as.body) {
                $select.find('option[value=body]').remove();
            }
            $select.trigger('change');
            $('#js-contribute-as-wrapper').show();
        } else {
            $('#js-contribute-as-wrapper').hide();
        }
    });
};

fixmystreet.reporting = {};
fixmystreet.reporting.selectedCategory = function() {
    var $group_or_cat_input = $('#form_category_fieldset input:checked'),
        group_or_cat = $group_or_cat_input.data('valuealone') || '', // Want only the group/category name itself, not the G| H| prefix
        group_id = group_or_cat.replace(/[^a-z]+/gi, ''),
        $subcategory = $("#subcategory_" + group_id),
        $subcategory_input = $subcategory.find('input:checked'),
        category,
        category_display,
        group;
    if ($subcategory.length) {
        category = $subcategory_input.val() || '';
        category_display = $subcategory_input.data('category_display') || '';
        group = group_or_cat;
    } else {
        category = group_or_cat;
        category_display = $group_or_cat_input.data('category_display') || category;
        group = '';
    }
    return { group: group, category: category, category_display: category_display };
};

})(); // fetch_reporting_data closure

fixmystreet.display = {
  // Possibilities to get here are:
  // 1. we've clicked the button/banner/map from around page
  // 2. we've clicked/dragged pin on new page already,
  // 3. we've clicked Back from page 2 of reporting form to page 1
  // 4. we've clicked Forward from around page after having gone back to it,
  begin_report: function(lonlat, opts) {
    opts = opts || {};

    if (fixmystreet.page === 'new' && opts.popstate) {
        // We've clicked Back from page 2 of reporting form to page 1
        return;
    }

    // In case we are coming straight from an ajax-loaded report page
    window.selected_problem_id = undefined;

    lonlat = fixmystreet.maps.begin_report(lonlat);

    // Store pin location in form fields, and check coverage of point
    fixmystreet.update_pin(lonlat, opts.saveHistoryState);

    $('html').addClass('map-with-crosshairs2');
    $('html').removeClass('map-with-crosshairs1 map-with-crosshairs3');
    fixmystreet.map.getControl('fms_reposition').activate();

    // It's possible to invoke this multiple times in a row
    // (eg: by clicking on the map multiple times, to
    // reposition your report). But there is some stuff we
    // only want to happen the first time you switch from
    // the "around" view to the "new" report view. So, here
    // we check whether we've already transitioned into the
    // "new" report view, and if so, we return from the
    // callback early, skipping the remainder of the setup
    // stuff.
    if (fixmystreet.page == 'new') {
        if (fixmystreet.map.panTo && !opts.noPan) {
            fixmystreet.map.panTo(lonlat);
        }
        return;
    }

    // If there are notes to be displayed, add the .with-notes class
    // to make the sidebar wider.
    if ($('#report-a-problem-sidebar').length) {
        $('body').addClass('with-notes');
    }

    /* For some reason on IOS5 if you use the jQuery show method it
     * doesn't display the JS validation error messages unless you do this
     * or you cause a screen redraw by changing the phone orientation.
     * NB: This has to happen after the call to show() in fixmystreet.update_pin */
    if ( navigator.userAgent.match(/like Mac OS X/i)) {
        document.getElementById('side-form').style.display = 'block';
    }
    $('#side').hide();
    $('#map_box .big-green-banner').hide();
    $('#side-report').remove();
    $('.two_column_sidebar').remove();
    $('body').removeClass('with-actions');

    if (fixmystreet.map.updateSize) {
        fixmystreet.map.updateSize(); // required after changing the size of the map element
    }
    if (fixmystreet.map.panTo) {
        fixmystreet.map.panTo(lonlat);
    }

    $('#sub_map_links').hide();
    $('.map-pins-toggle').hide();
    if ($('html').hasClass('mobile')) {
        fixmystreet.pageController.mapStepButtons();
    }

    fixmystreet.page = 'new';
    document.title = translation_strings.reporting_a_problem;

    fixmystreet.update_report_a_problem_btn();
  },

  report: function(reportPageUrl, reportId, callback) {
    $.ajax(reportPageUrl, { cache: false }).done(function(html, textStatus, jqXHR) {
        var $reportPage = $(html),
            $twoColReport = $reportPage.find('.two_column_sidebar'),
            $sideReport = $reportPage.find('#side-report');

        // Set this from report page in case change asset used and therefore relevant() function
        fixmystreet.bodies = fixmystreet.utils.csv_to_array($reportPage.find('#js-map-data').data('bodies'))[0];

        if ($sideReport.length) {
            $('#side').hide(); // Hide the list of reports
            $('#side-form').hide(); // And the form
            $('body').removeClass('with-notes');
            $('#map_box .big-green-banner').hide();
            // Remove any existing report page content from sidebar
            $('#side-report').remove();
            $('.two_column_sidebar').remove();

            fixmystreet.mobile_reporting.remove_ui();

            // Insert this report's content
            if ($twoColReport.length) {
                $twoColReport.appendTo('#map_sidebar');
                $('body').addClass('with-actions');
            } else {
                $sideReport.appendTo('#map_sidebar');
            }

            if (fixmystreet.map.updateSize && ($twoColReport.length || $('html').hasClass('mobile'))) {
                fixmystreet.map.updateSize();
            }

            $('#map_sidebar').scrollTop(0);
            if ($("html").hasClass("mobile")) {
                $(document).scrollTop(0);
            }

            var found = html.match(/<title>([\s\S]*?)<\/title>/);
            // Unencode HTML entities so it's suitable for document.title. We
            // only care about the ones encoded by the template's html_filter.
            var map = {
                '&amp;': '&',
                '&gt;': '>',
                '&lt;': '<',
                '&quot;': '"',
                '&#39;': "'"
            };
            var page_title = found[1].replace(/&(amp|lt|gt|quot|#39);/g, function(m) {
                return map[m];
            });

            fixmystreet.page = 'report';

            $('.map-pins-toggle').hide();

            // If this is the first individual report we've loaded, remove the
            // "all reports" sub_map_links but store them in a global variable
            // so we can reinsert them when the user returns to the all reports
            // view.
            if (!fixmystreet.original.sub_map_links) {
                fixmystreet.original.sub_map_links = $('#sub_map_links').detach();
            }
            // With #sub_map_links detached from the DOM, we set up the
            // individual report's sub_map_links using map_controls().
            fixmystreet.set_up.map_controls();

            // Set the Back link to know where to go back to.
            // TODO: If you e.g. filter before selecting a report, this URL is
            // wrong (but what is shown is correct).
            $('.js-back-to-report-list').attr('href', fixmystreet.original.href);

            // Problems nearby on /my should go to the around page,
            // otherwise show reports within the current map view.
            if (fixmystreet.original.page === 'around' || fixmystreet.original.page === 'reports') {
                $sideReport.find('#key-tool-problems-nearby').on('click', function(e) {
                    var report_list_url = fixmystreet.original.href;
                    var map_state = fixmystreet.maps.get_map_state();
                    fixmystreet.back_to_reports_list(e, report_list_url, map_state);
                });
            }
            fixmystreet.set_up.map_sidebar_key_tools();
            fixmystreet.set_up.form_validation();
            fixmystreet.set_up.email_login_form();
            fixmystreet.set_up.form_section_previews();
            fixmystreet.set_up.fancybox_images();
            fixmystreet.set_up.dropzone($sideReport);
            fixmystreet.set_up.toggle_visibility();
            $(fixmystreet).trigger('display:report');

            fixmystreet.update_report_a_problem_btn();

            window.selected_problem_id = reportId;
            var marker = fixmystreet.maps.get_marker_by_id(reportId);
            var el = document.querySelector('input[name=triage]');
            if (el) {
                fixmystreet.map.setCenter(
                    marker.geometry.getBounds().getCenterLonLat(),
                    fixmystreet.map.getNumZoomLevels() - 1 );
            } else if (fixmystreet.map.panTo && ($('html').hasClass('mobile') || !marker.onScreen())) {
                fixmystreet.map.panTo(
                    marker.geometry.getBounds().getCenterLonLat()
                );
            }
            if (fixmystreet.maps.markers_resize) {
                fixmystreet.maps.markers_resize(); // force a redraw so the selected marker gets bigger
            }

            // We disabled this upon first touch to prevent it taking effect, re-enable now
            if (fixmystreet.maps.click_control) {
                fixmystreet.maps.click_control.activate();
            }

            if (fixmystreet.maps.setup_inspector) {
                fixmystreet.maps.setup_inspector();
            }


            if (typeof callback === 'function') {
                callback();
            }
            document.title = page_title;

        } else {
            window.location.href = reportPageUrl;
        }

    }).fail(function(jqXHR, textStatus, errorThrown) {
        window.location.href = reportPageUrl;

    });
  },

  // This could be an /around page or a /reports page
  reports_list: function(reportListUrl, callback) {
    // If the report list is already in the DOM,
    // just reveal it, rather than loading new page.
    var side = document.getElementById('side');
    if (side) {
        if (side.style.display !== 'none') {
            return;
        }
        side.style.display = '';
        $('#map_box .big-green-banner').show();
        $('#side-form').hide();
        // Report page may have been one or two columns, remove either
        $('#side-report').remove();
        $('.two_column_sidebar').remove();
        $('body').removeClass('with-actions');
        $('body').removeClass('with-notes');

        fixmystreet.page = fixmystreet.original.page;
        document.title = translation_strings.viewing_a_location;
        if ($('html').hasClass('mobile') && fixmystreet.page == 'around') {
            $('#mob_sub_map_links').remove();
            $('html').removeClass('map-page');
            fixmystreet.mobile_reporting.apply_ui();
        }

        if (fixmystreet.original.sub_map_links) {
            $('#sub_map_links').replaceWith(fixmystreet.original.sub_map_links);
            delete fixmystreet.original.sub_map_links;
        }
        $('.map-pins-toggle').show();
        fixmystreet.set_up.map_controls();

        fixmystreet.map.getControl('fms_reposition').deactivate();

        fixmystreet.update_report_a_problem_btn();

        window.selected_problem_id = undefined;

        // Perform vendor-specific map setup steps,
        // to get map back into "around" mode.
        fixmystreet.maps.display_around();

        if (typeof callback === 'function') {
            callback();
        }
        document.title = fixmystreet.original.title;

    } else {
        window.location.href = reportListUrl;
    }
  }
};


$(function() {
    fixmystreet.original = {
        'href': location.href,
        'title': document.title,
        'page': fixmystreet.page
    };

    $.each(fixmystreet.set_up, function(setup_name, setup_func) {
        setup_func();
    });

    // We only do popstate things on normal map pages, which set this variable
    if (!fixmystreet.page) {
        return;
    }
    // The replaceState below means that normal browser behaviour with POSTed
    // pages stops working (because the replaceState turns the POST into a
    // GET), e.g. clicking back in a multi-page form reloads the page and
    // takes you back to the start, so avoid that on the form-based flow.
    if ($('body').hasClass('formflow')) {
        return;
    }

    // Have a fake history entry so we can cover all eventualities.
    if ('replaceState' in history) {
        history.replaceState({ initial: true }, null);
    }

    if (document.readyState === 'complete') {
        setup_popstate();
    } else {
        $(window).on('load', setup_popstate);
    }
});

window.addEventListener('pagehide', function(e) {
    // If we are leaving a page, and we're not being persisted, reset
    // subcategory selection on new report form. A subcategory may trigger a
    // stopper message that also disables the form; if the user presses the
    // back button, we want to re-enable the form.
    var $subcats = $('input[name^="category."]:checked');
    if (!e.persisted && $subcats.length) {
        $subcats.prop('checked', false);
    }
});

function setup_popstate() {
    setTimeout(function () {
        if (!window.addEventListener) { return; }
        window.addEventListener('popstate', function(e) {
            // The user has pressed the Back or Forward button, and there
            // is a stored History state for them to return to.

            // Note: no pushState callbacks in these display_* calls,
            // because we're already inside a popstate: We want to roll
            // back to a previous state, not create a new one!

            var location = window.history.location || window.location;
            var page;

            if (e.state === null) {
                // Hashchange or whatever, we don't care.
                return;
            }

            // Reset subcategory selection on new report form. A subcategory
            // may trigger a stopper message that also disables the form; if
            // the user presses the back button, we want to re-enable the
            // form.
            var $subcats = $('input[name^="category."]:checked');
            var $curr = $('.js-reporting-page--active');
            if ($curr.data('pageName') == 'subcategory' && $subcats.length) {
                $subcats.prop('checked', false).trigger('change');
            }

            var reports_list_trigger;
            if ('initial' in e.state) {
                if (fixmystreet.original.page === 'new') {
                    // Started at /report/new, so go back to first 'page' there
                    fixmystreet.pageController.toPage('first', {
                        popstate: true,
                        forceMapShow: true
                    });
                    return;
                }

                // User has navigated Back from a pushStated state, presumably to
                // see the list of all reports (which was shown on pageload). By
                // this point, the browser has *already* updated the URL bar so
                // location.href is something like foo.com/around?pc=abc-123,
                // which we pass into fixmystreet.display.reports_list() as a fallback
                // in case the list isn't already in the DOM.
                var filters = $('#filter_categories').add('#statuses').add('#sort');
                filters.find('option').prop('selected', function() { return this.defaultSelected; });
                filters.trigger('change.multiselect');
                if (fixmystreet.utils && fixmystreet.utils.parse_query_string) {
                    var qs = fixmystreet.utils.parse_query_string();
                    page = qs.p || 1;
                    $('#show_old_reports').prop('checked', qs.show_old_reports || '');
                    if (fixmystreet.markers.protocol) {
                        fixmystreet.markers.protocol.use_page = true;
                    }
                    $('.pagination').first().data('page', page);
                }
                reports_list_trigger = $('.pagination').first();
            } else if ('reportId' in e.state) {
                fixmystreet.display.report(e.state.reportPageUrl, e.state.reportId);
            } else if ('newReportAtLonlat' in e.state) {
                fixmystreet.pageController.toPage('first', {
                    popstate: true,
                    forceMapShow: true
                });
                fixmystreet.display.begin_report(e.state.newReportAtLonlat, {
                    popstate: true,
                    saveHistoryState: false
                });
            } else if ('page_change' in e.state) {
                if (fixmystreet.markers.protocol) {
                    fixmystreet.markers.protocol.use_page = true;
                }
                $('#show_old_reports').prop('checked', e.state.page_change.show_old_reports);
                $('.pagination').first().data('page', e.state.page_change.page);
                reports_list_trigger = $('.pagination').first();
            } else if ('filter_change' in e.state) {
                $('#filter_categories').val(e.state.filter_change.filter_categories);
                $('#statuses').val(e.state.filter_change.statuses);
                $('#sort').val(e.state.filter_change.sort);
                $('#show_old_reports').prop('checked', e.state.filter_change.show_old_reports);
                $('#filter_categories').add('#statuses').trigger('change.multiselect');
                reports_list_trigger = $('#filter_categories');
            // } else if ('hashchange' in e.state) {
                // This popstate was just here because the hash changed.
                // (eg: mobile nav click.) We want to ignore it.
            } else if ('reportingPage' in e.state) {
                page = e.state.reportingPage;
                fixmystreet.pageController.toPage(page, {
                    popstate: true
                });
            }

            if (reports_list_trigger) {
                if (fixmystreet.page.match(/reports|around|my/)) {
                    reports_list_trigger.trigger('change.filters');
                } else {
                    fixmystreet.display.reports_list(location.href);
                }
            }

            if ('mapState' in e.state) {
                fixmystreet.maps.set_map_state(e.state.mapState);
            }
        });
    }, 0);
}
