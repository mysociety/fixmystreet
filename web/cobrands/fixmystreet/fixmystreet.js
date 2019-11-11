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
        var $this = $(this), d = $('#' + id);
        this.toggle(function() {
            if (opened) {
                opened.click();
            }
            if (!$this.addClass('hover').data('setup')) {
                d.hide().removeClass('hidden-js').css({
                padding: '1em',
                background: '#fff'
                });
                $this.data('setup', true);
            }
            d.slideDown();
            opened = $this;
        }, function(e) {
            $this.removeClass('hover');
            d.slideUp();
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
        this.toggle(function() {
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
                var drawer_top = $(window).height() - $sw.height();
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

            // Animate the drawer into place, enitrely covering the sidebar.
            var sidebar_top_px = $sidebar.position().top;
            $drawer.show().animate({ top: sidebar_top_px }, 1000);

        }, function(e) {
            // Slide the drawer down, move the .shadow-wrap back to its
            // original parent, and hide the drawer for potential re-use later.
            $this.removeClass('hover');
            var drawer_top = $(window).height() - $sw.height();

            $drawer.animate({ top: drawer_top }, 1000, function() {
                $sw.removeClass('static').appendTo($swparent);
                $drawer.hide();
            });
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

        if ( $select.data('all') ) {
            settings.allText = $select.data('all');
            settings.noneText = settings.noneText || settings.allText;
            settings.presets = [];
            settings.presets.push({
                name: settings.allText,
                options: $select.data('all-options') || []
            });
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
    }

  });
})(jQuery);

fixmystreet.mobile_reporting = {
  apply_ui: function() {
    // Creates the "app-like" mobile reporting UI with full screen map
    // and special "OK/Cancel" buttons etc.
    $('html').addClass('map-fullscreen only-map map-reporting');
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
    $('html').removeClass('map-fullscreen only-map map-reporting');
    $('#map_box').css({ width: "", height: "", position: "" });
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
    if (typeof fixmystreet !== 'undefined' && fixmystreet.page == 'around') {
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

fixmystreet.set_up = fixmystreet.set_up || {};
$.extend(fixmystreet.set_up, {
  basics: function() {
    // Preload the new report pin
    if ( typeof fixmystreet !== 'undefined' && typeof fixmystreet.pin_prefix !== 'undefined' ) {
        document.createElement('img').src = fixmystreet.pin_prefix + 'pin-' + fixmystreet.pin_new_report_colour + '.png';
    } else {
        document.createElement('img').src = '/i/pin-green.png';
    }

    $('a[href*="around"]').each(function() {
        this.href = this.href + (this.href.indexOf('?') > -1 ? '&js=1' : '?js=1');
    });
    $('input[name="js"]').val(1);
    $('form[action*="around"]').each(function() {
        $('<input type="hidden" name="js" value="1">').prependTo(this);
    });

    // Focus on postcode box on front page
    $('#pc').focus();

    // In case we've come here by clicking back to a form that disabled a submit button
    $('form.validate input[type=submit]').removeAttr('disabled');

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
            return this.optional(element) || value != '-- Pick a category --'; }, translation_strings.category );
        jQuery.validator.addMethod('js-password-validate', function(value, element) {
            return !value || value.length >= fixmystreet.password_minimum_length;
        }, translation_strings.password_register.short);
        jQuery.validator.addMethod('notEmail', function(value, element) {
            return this.optional(element) || !/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:\S{1,63})$/.test( value ); }, translation_strings.title );
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
            element.before( error );
        },
        submitHandler: function(form) {
            if (form.submit_problem) {
                $('input[type=submit]', form).prop("disabled", true);
            }
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
    $('.js-submit_sign_in').click( function(e) {
        $('.js-form-name').removeClass('required');
    } );

    $('.js-submit_register').click( function(e) {
        $('.js-form-name').addClass('required');
    } );

    $('#facebook_sign_in, #twitter_sign_in, #oidc_sign_in').click(function(e){
        $('#username, #form_username_register, #form_username_sign_in').removeClass('required');
    });

    $('#planned_form').submit(function(e) {
        if (e.metaKey || e.ctrlKey) {
            return;
        }
        e.preventDefault();
        var $form = $(this),
            $submit = $form.find("input[type='submit']" ),
            $labels = $('label[for="' + $submit.attr('id') + '"]'),
            problemId = $form.find("input[name='id']").val(),
            data = $form.serialize() + '&ajax=1',
            changeValue,
            buttonLabel,
            buttonValue,
            classToAdd,
            classToRemove;

        $.post(this.action, data, function(data) {
            if (data.outcome == 'add') {
                $form.find("input[name='shortlist-add']" ).attr('name', 'shortlist-remove');
                buttonLabel = $submit.data('label-remove');
                buttonValue = $submit.data('value-remove');
                classToAdd = $submit.data('class-remove');
                classToRemove = $submit.data('class-add');
                $('.shortlisted-status').remove();
                $(document).trigger('shortlist-add', problemId);
            } else if (data.outcome == 'remove') {
                $form.find("input[name='shortlist-remove']" ).attr('name', 'shortlist-add');
                buttonLabel = $submit.data('label-add');
                buttonValue = $submit.data('value-add');
                $(document).trigger('shortlist-remove', problemId);
                classToAdd = $submit.data('class-add');
                classToRemove = $submit.data('class-remove');
            }
            $submit.val(buttonValue).attr('aria-label', buttonLabel).removeClass(classToRemove).addClass(classToAdd);
            $labels.text(buttonValue).attr('aria-label', buttonLabel).removeClass(classToRemove).addClass(classToAdd);
        });
    });
  },

  autocomplete: function() {
    $('.js-autocomplete').each(function() {
        accessibleAutocomplete.enhanceSelectElement({
            selectElement: this,
            displayMenu: 'overlay',
            required: true,
            // showAllValues: true, // Currently undismissable on iOS
            defaultValue: ''
        });
    });
  },

  category_change: function() {
    // Deal with changes to report category.

    // On the new report form, does this by asking for details from the server.
    // Delegation is necessary because #form_category may be replaced during the lifetime of the page
    $("#problem_form").on("change.category", "select#form_category", function(){
	// If we haven't got any reporting data (e.g. came straight to
	// /report/new), fetch it first. That will then automatically call this
	// function again, due to it calling change() on the category if set.
        if (!fixmystreet.reporting_data) {
            if (fixmystreet.page === 'new') {
                fixmystreet.fetch_reporting_data();
            }
            return;
        }

        var category = $(this).val(),
            data = fixmystreet.reporting_data.by_category[category],
            $category_meta = $('#category_meta');

        if (data) {
            fixmystreet.bodies = data.bodies || [];
        } else {
            fixmystreet.bodies = fixmystreet.reporting_data.bodies || [];
        }
        if (fixmystreet.body_overrides) {
            fixmystreet.body_overrides.clear();
        }

        if (data && data.councils_text) {
            fixmystreet.update_councils_text(data);
        } else {
            // Use the original returned texts
            fixmystreet.update_councils_text(fixmystreet.reporting_data);
        }
        if (data && data.category_extra) {
            if ( $category_meta.length ) {
                $category_meta.replaceWith( data.category_extra );
                var $new_category_meta = $('#category_meta');
                // Preserve any existing values
                $category_meta.find("[name]").each(function() {
                    $new_category_meta.find("[name="+this.name+"]").val(this.value);
                });
            } else {
                $('#js-post-category-messages').prepend( data.category_extra );
            }
        } else {
            $category_meta.empty();
        }
        if (data && data.non_public) {
            $(".js-hide-if-private-category").hide();
            $(".js-hide-if-public-category").show();
        } else {
            $(".js-hide-if-private-category").show();
            $(".js-hide-if-public-category").hide();
        }

        if (fixmystreet.message_controller && data && data.disable_form && data.disable_form.answers) {
            $('#form_' + data.disable_form.code).on('change.category', function() {
                $(fixmystreet).trigger('report_new:category_change');
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

        $(fixmystreet).trigger('report_new:category_change', { check_duplicates_dismissal: true });
    });
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
            }
        });
  },

  // no_event makes sure no change event is fired (so we don't end up in an infinite loop)
  // and also only sets up the main group dropdown, assuming the subs are left alone
  category_groups: function(old_group, no_event) {
    var $category_select = $("select#form_category");
    if (!$category_select.hasClass('js-grouped-select')) {
        if (!no_event && $category_select.val() !== '-- Pick a category --') {
            $category_select.change();
        }
        return;
    }

    var $group_select = $("<select></select>").addClass("form-control validCategory").attr('id', 'category_group');
    var $category_label = $("#form_category_label");
    var $subcategory_label = $("#form_subcategory_label");
    var $empty_option = $category_select.find("option").first();

    $group_select.change(function() {
        var subcategory_id = $(this).find(":selected").data("subcategory_id");
        $(".js-subcategory").hide();
        if (subcategory_id === undefined) {
            $subcategory_label.addClass("hidden");
            $category_select.val($(this).val()).change();
        } else {
            $("#" + subcategory_id).show().change();
            $subcategory_label.removeClass("hidden").attr('for', subcategory_id);
        }
    });

    var subcategory_change = function() {
        $category_select.val($(this).val()).change();
    };

    var add_option = function(el) {
        $group_select.append($(el).clone());
        if (el.selected) {
            $group_select.val(el.value);
        }
    };

    var add_optgroup = function(el) {
        var $el = $(el);
        var $options = $el.find("option");

        if ($options.length === 0) {
            /// Pass empty optgroups
        } else if ($options.length == 1) {
            add_option($options.get(0));
        } else {
            var label = $el.attr("label");
            var subcategory_id = "subcategory_" + label.replace(/[^a-zA-Z]+/g, '');
            var $opt = $("<option></option>").text(label).val(label);
            $opt.data("subcategory_id", subcategory_id);
            $group_select.append($opt);

            if (no_event) {
                $options.each(function() {
                    // Make sure any preselected value is preserved in the new UI:
                    if (this.selected) {
                        $group_select.val(label);
                    }
                });
                return;
            }

            var $sub_select = $("<select></select>").addClass("form-control js-subcategory validCategory");
            $sub_select.attr("id", subcategory_id);
            $sub_select.append($empty_option.clone());
            $options.each(function() {
                $sub_select.append($(this).clone());
                // Make sure any preselected value is preserved in the new UI:
                if (this.selected) {
                    $group_select.val(label);
                    $sub_select.val(this.value);
                }
            });
            $sub_select.hide().insertAfter($subcategory_label).change(subcategory_change);
        }
    };

    $category_select.hide();
    $group_select.insertAfter($category_select);
    $category_label.attr('for', 'category_group');
    $category_select.find("optgroup, > option").each(function() {
        if (this.tagName.toLowerCase() === 'optgroup') {
            add_optgroup(this);
        } else if (this.tagName.toLowerCase() === 'option') {
            add_option(this);
        }
    });
    // Sort elements in place, but leave the first 'pick a category' option alone
    $group_select.find("option").slice(1).sort(function(a, b) {
        // 'Other' should always be at the end.
        if (a.label === 'Other') {
            return 1;
        }
        if (b.label === 'Other') {
            return -1;
        }
        return a.label > b.label ? 1 : -1;
    }).appendTo($group_select);

    if (old_group !== '-- Pick a category --' && $category_select.val() == '-- Pick a category --') {
        $group_select.val(old_group);
    }
    if (!no_event) {
        $group_select.change();
    }
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
        var type = Modernizr.mq('(min-width: 48em)') || $('html.ie8').length ? 'desktop' : 'mobile';
        if (last_type == type) { return; }
        if (type == 'mobile') {
            fixmystreet.resize_to.mobile_page();
        } else {
            fixmystreet.resize_to.desktop_page();
        }
        last_type = type;
    }).resize();
  },

  dropzone: function($context) {

    // Pass a jQuery element, eg $('.foobar'), into this function
    // to limit all the selectors to that element. Handy if you want
    // to only bind/detect Dropzones in a particular part of the page,
    // or if your selectors (eg: "#form_photo") aren't unique across
    // the whole page.
    if (typeof $context === undefined) {
        $context = $(document);
    }

    if ('Dropzone' in window) {
      Dropzone.autoDiscover = false;
    } else {
      return;
    }

    var forms = $('[for="form_photo"], .js-photo-label', $context).closest('form');
    forms.each(function() {
      // Internal $context is the individual form with the photo upload inside
      var $context = $(this);
      var $originalLabel = $('[for="form_photo"], .js-photo-label', $context);
      var $originalInput = $('#form_photos, .js-photo-fields', $context);
      var $dropzone = $('<div tabindex=0>').addClass('dropzone');

      $originalLabel.removeAttr('for');
      $('[data-plural]', $originalLabel).text(
          $('[data-plural]', $originalLabel).attr('data-plural')
      );
      $originalInput.hide();

      $dropzone.insertAfter($originalInput);
      var photodrop = new Dropzone($dropzone[0], {
        url: '/photo/upload',
        paramName: 'photo',
        maxFiles: 3,
        addRemoveLinks: true,
        thumbnailHeight: 150,
        thumbnailWidth: 150,
        resizeWidth: 2048,
        resizeHeight: 2048,
        resizeQuality: 0.6,
        acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png',
        dictDefaultMessage: translation_strings.upload_default_message,
        dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
        dictInvalidFileType: translation_strings.upload_invalid_file_type,
        dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,

        fallback: function() {
          $dropzone.remove();
          $originalLabel.attr('for', 'form_photo');
          $('[data-singular]', $originalLabel).text(
              $('[data-singular]', $originalLabel).attr('data-singular')
          );
          $originalInput.show();
        },
        init: function() {
          this.on("addedfile", function(file) {
            $('input[type=submit]', $context).prop("disabled", true).removeClass('green-btn');
          });
          this.on("queuecomplete", function() {
            $('input[type=submit]', $context).removeAttr('disabled').addClass('green-btn');
          });
          this.on("success", function(file, xhrResponse) {
            var ids = $('input[name=upload_fileid]', $context).val().split(','),
                id = (file.server_id = xhrResponse.id),
                l = ids.push(id),
                newstr = ids.join(',');
            $('input[name=upload_fileid]', $context).val(newstr);
          });
          this.on("error", function(file, errorMessage, xhrResponse) {
          });
          this.on("removedfile", function(file) {
            var ids = $('input[name=upload_fileid]', $context).val().split(','),
                newstr = $.grep(ids, function(n) { return (n!=file.server_id); }).join(',');
            $('input[name=upload_fileid]', $context).val(newstr);
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

      $dropzone.on('keydown', function(e) {
          if (e.keyCode === 13 || e.keyCode === 32) {
              $dropzone.click();
          }
      });

      $.each($('input[name=upload_fileid]', $context).val().split(','), function(i, f) {
        if (!f) {
            return;
        }
        var mockFile = { name: f, server_id: f, dataURL: '/photo/temp.' + f };
        photodrop.emit("addedfile", mockFile);
        photodrop.createThumbnailFromUrl(mockFile,
            photodrop.options.thumbnailWidth, photodrop.options.thumbnailHeight,
            photodrop.options.thumbnailMethod, true, function(thumbnail) {
                photodrop.emit('thumbnail', mockFile, thumbnail);
            });
        photodrop.emit("complete", mockFile);
        photodrop.options.maxFiles -= 1;
      });
    });
  },

  report_list_filters: function() {
    // Hide the pin filter submit button. Not needed because we'll use JS
    // to refresh the map when the filter inputs are changed.
    $(".report-list-filters [type=submit]").hide();

    $('.js-multiple').make_multi();
  },

  mobile_ui_tweaks: function() {
    //move 'skip this step' link on mobile
    $('.mobile #skip-this-step').addClass('chevron').wrap('<li>').parent().appendTo('#key-tools');
  },

  on_mobile_nav_click: function() {
    $('.mobile').on('click', '#nav-link', function(e) {
        e.preventDefault();
        var offset = $('#main-nav').offset().top;
        $('html, body').animate({scrollTop:offset}, 1000);

        // Registering a pushState here means that mobile users can
        // press their browser's Back button to return out of the
        // mobile menu (easier than scrolling all the way back up
        // the page). However, to show the map page popstate listener
        // that this was a special state, we set hashchange to true in
        // the event state, so we can detect it, and ignore it, later.
        if ('pushState' in history) {
            history.pushState({
                hashchange: true
            }, null);
        }
    });
  },

  clicking_banner_begins_report: function() {
    $('.big-green-banner').on('click', function(){
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
    if (fixmystreet.cobrand != 'zurich') {
        if ($('#sub_map_links').length === 0) {
            $('<p class="sub-map-links" id="sub_map_links" />').insertAfter($('#map'));
        }
    }

    if ($('.mobile').length) {
        // Make sure we end up with one Get updates link
        if ($('#key-tools a.js-feed').length) {
            $('#sub_map_links a.js-feed').remove();
            $('#key-tools a.js-feed').appendTo('#sub_map_links');
        }
        $('#key-tools li:empty').remove();
        $('#report-updates-data').insertAfter($('#map_box'));
        if (fixmystreet.page !== 'around' && !$('#toggle-fullscreen').length) {
            $('#sub_map_links').append('<a href="#" id="toggle-fullscreen" class="expand" data-expand-text="'+ translation_strings.expand_map +'" data-compress-text="'+ translation_strings.collapse_map +'" >'+ translation_strings.expand_map +'</span>');
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

    $('#toggle-fullscreen').off('click').on('click', function() {
      var btnClass = $('html').hasClass('map-fullscreen') ? 'expand' : 'compress';
      var text = $(this).data(btnClass + '-text');

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
    $('#key-tool-report-updates').small_drawer('report-updates-data');
    $('#key-tool-report-share').small_drawer('report-share');
  },

  ward_select_multiple: function() {
    $(".js-ward-select-multiple").click(function(e) {
        e.preventDefault();
        $(".js-ward-single").addClass("hidden");
        $(".js-ward-multi").removeClass("hidden");
    });
  },

  email_login_form: function() {
    // Password form split up
    $('.js-sign-in-password-btn').click(function(e) {
        if ($('.js-sign-in-password').is(':visible')) {
        } else {
            e.preventDefault();
            $('.js-sign-in-password-hide').hide();
            $('.js-sign-in-password').show().css('visibility', 'visible');
            $('#password_sign_in').focus();
        }
    });
    // This is if the password box is filled programmatically (by
    // e.g. 1Password), show it so that it will auto-submit.
    $('#password_sign_in').change(function() {
        $('.js-sign-in-password').show().css('visibility', 'visible');
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
        $('#form_sign_in_yes input, #form_sign_in_no input').filter(':visible').eq(0).focus();
    };

    // Display tweak
    $('.js-new-report-sign-in-hidden.form-box, .js-new-report-sign-in-shown.form-box').removeClass('form-box');

    $('.js-new-report-user-hide').click(function(e) {
        e.preventDefault();
        $('.js-new-report-user-shown')[0].scrollIntoView({behavior: "smooth"});
        hide('.js-new-report-user-shown');
        show('.js-new-report-user-hidden');
    });
    $('.js-new-report-user-show').click(function(e) {
        e.preventDefault();
        var v = $(this).closest('form').validate();
        if (!v.form()) {
            v.focusInvalid();
            return;
        }
        $('.js-new-report-user-hidden')[0].scrollIntoView({behavior: "smooth"});
        hide('.js-new-report-user-hidden');
        show('.js-new-report-user-shown').then(function(){
            focusFirstVisibleInput();
        });
    });

    $('.js-new-report-show-sign-in').click(function(e) {
        $('.js-new-report-sign-in-shown').removeClass('hidden-js');
        $('.js-new-report-sign-in-hidden').addClass('hidden-js');
        focusFirstVisibleInput();
    });

    $('.js-new-report-hide-sign-in').click(function(e) {
        e.preventDefault();
        $('.js-new-report-sign-in-shown').addClass('hidden-js');
        $('.js-new-report-sign-in-hidden').removeClass('hidden-js');
        focusFirstVisibleInput();
    });

    $('.js-new-report-sign-in-forgotten').click(function() {
        $('.js-new-report-sign-in-shown').addClass('hidden-js');
        $('.js-new-report-sign-in-hidden').removeClass('hidden-js');
        $('.js-new-report-forgotten-shown').removeClass('hidden-js');
        $('.js-new-report-forgotten-hidden').addClass('hidden-js');
        focusFirstVisibleInput();
    });

    var err = $('.form-error');
    if (err.length) {
        $('.js-sign-in-password-btn').click();
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

  reporting_hide_phone_email: function() {
    $('#form_username_register').on('keyup change', function() {
        var username = $(this).val();
        if (/^[^a-z]+$/i.test(username)) {
            $('#js-hide-if-username-phone').hide();
            $('#js-hide-if-username-email').show();
        } else {
            $('#js-hide-if-username-phone').show();
            $('#js-hide-if-username-email').hide();
        }
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
    $('body').on('click', '#alert_rss_button', function(e) {
        e.preventDefault();
        var feed = $('input[name=feed][type=radio]:checked').parent().prevAll('a').attr('href');
        window.location.href = feed;
    });
    $('body').on('click', '#alert_email_button', function(e) {
        e.preventDefault();
        var form = $('<form/>').attr({ method:'post', action:"/alert/subscribe" });
        form.append($('<input name="alert" value="Subscribe me to an email alert" type="hidden" />'));
        $(this).closest('.js-alert-list').find('input[type=email], input[type=text], input[type=hidden], input[type=radio]:checked').each(function() {
            var $v = $(this);
            $('<input/>').attr({ name:$v.attr('name'), value:$v.val(), type:'hidden' }).appendTo(form);
        });
        $('body').append(form);
        form.submit();
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

    if (savePushState !== false) {
        if ('pushState' in history) {
            var newReportUrl = '/report/new?longitude=' + lonlats.url.lon + '&latitude=' + lonlats.url.lat;
            history.pushState({
                newReportAtLonlat: lonlats.state
            }, null, newReportUrl);
        }
    }

    fixmystreet.fetch_reporting_data();

    if (!$('#side-form-error').is(':visible')) {
        $('#side-form').show();
        $('#map_sidebar').scrollTop(0);
    }
};

fixmystreet.fetch_reporting_data = function() {
    $.getJSON('/report/new/ajax', {
        latitude: $('#fixmystreet\\.latitude').val(),
        longitude: $('#fixmystreet\\.longitude').val()
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
        $('#side-form').show();
        var old_category_group = $('#category_group').val() || $('#filter_group').val(),
            old_category = $("#form_category").val(),
            filter_category = $("#filter_categories").val();

        fixmystreet.reporting_data = data;

        fixmystreet.bodies = data.bodies || [];
        if (fixmystreet.body_overrides) {
            fixmystreet.body_overrides.clear();
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
                if (details.disable_form.answers) {
                    details.disable_form.category = category;
                    details.disable_form.keep_category_extras = true;
                    fixmystreet.message_controller.register_category(details.disable_form);
                }
            });
        }

        $('#form_category_row').html(data.category);
        if ($("#form_category option[value=\"" + old_category + "\"]").length) {
            $("#form_category").val(old_category);
        } else if (filter_category !== undefined && $("#form_category option[value='" + filter_category + "']").length) {
            // If the category filter appears on the map and the user has selected
            // something from it, then pre-fill the category field in the report,
            // if it's a value already present in the drop-down.
            $("#form_category").val(filter_category);
        }

        fixmystreet.set_up.category_groups(old_category_group);

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
            $select.change();
            $('#js-contribute-as-wrapper').show();
        } else {
            $('#js-contribute-as-wrapper').hide();
        }
    });
};

fixmystreet.display = {
  begin_report: function(lonlat, saveHistoryState) {
    lonlat = fixmystreet.maps.begin_report(lonlat);

    // Store pin location in form fields, and check coverage of point
    fixmystreet.update_pin(lonlat, saveHistoryState);

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
        if (fixmystreet.map.panTo) {
            fixmystreet.map.panDuration = 100;
            fixmystreet.map.panTo(lonlat);
            fixmystreet.map.panDuration = 50;
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
        fixmystreet.map.panDuration = 100;
        fixmystreet.map.panTo(lonlat);
        fixmystreet.map.panDuration = 50;
    }

    $('#sub_map_links').hide();
    $('.big-hide-pins-link').hide();
    if ($('html').hasClass('mobile')) {
        var $map_box = $('#map_box'),
            width = $map_box.width(),
            height = $map_box.height();
        $map_box.append(
            '<p class="sub-map-links" id="mob_sub_map_links">' +
            '<a href="#" id="try_again">' +
                translation_strings.try_again +
            '</a>' +
            '<a href="#ok" id="mob_ok">' +
                translation_strings.ok +
            '</a>' +
            '</p>')
        .addClass('above-form') // Stop map being absolute, so reporting form doesn't get hidden
        .css({
            width: width,
            height: height
        });
        $('#try_again').click(function(e){
            e.preventDefault();
            history.back();
        });

        $('.mobile-map-banner span').text(translation_strings.right_place);

        // mobile user clicks 'ok' on map
        $('#mob_ok').toggle(function(){
            //scroll the height of the map box instead of the offset
            //of the #side-form or whatever as we will probably want
            //to do this on other pages where #side-form might not be
            $('html, body').animate({ scrollTop: height-60 }, 1000, function(){
                $('html').removeClass('only-map');
                $('#mob_sub_map_links').addClass('map_complete');
                $('#mob_ok').text(translation_strings.map);
            });
        }, function(){
            $('html, body').animate({ scrollTop: 0 }, 1000, function(){
                $('html').addClass('only-map');
                $('#mob_sub_map_links').removeClass('map_complete');
                $('#mob_ok').text(translation_strings.ok);
                if (fixmystreet.duplicates) {
                    fixmystreet.duplicates.hide();
                }
            });
        });
    }

    fixmystreet.page = 'new';

    fixmystreet.update_report_a_problem_btn();
  },

  report: function(reportPageUrl, reportId, callback) {
    $.ajax(reportPageUrl, { cache: false }).done(function(html, textStatus, jqXHR) {
        var $reportPage = $(html),
            $twoColReport = $reportPage.find('.two_column_sidebar'),
            $sideReport = $reportPage.find('#side-report');

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

            $('.big-hide-pins-link').hide();

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
                $sideReport.find('#key-tool-problems-nearby').click(function(e) {
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
        if ($('html').hasClass('mobile') && fixmystreet.page == 'around') {
            $('#mob_sub_map_links').remove();
            fixmystreet.mobile_reporting.apply_ui();
        }

        if (fixmystreet.original.sub_map_links) {
            $('#sub_map_links').replaceWith(fixmystreet.original.sub_map_links);
            delete fixmystreet.original.sub_map_links;
        }
        $('.big-hide-pins-link').show();
        fixmystreet.set_up.map_controls();

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

    // Have a fake history entry so we can cover all eventualities.
    if ('replaceState' in history) {
        history.replaceState({ initial: true }, null);
    }

    $(window).on('load', function () {
        setTimeout(function () {
            if (!window.addEventListener) { return; }
            window.addEventListener('popstate', function(e) {
                // The user has pressed the Back button, and there is a
                // stored History state for them to return to.

                // Note: no pushState callbacks in these display_* calls,
                // because we're already inside a popstate: We want to roll
                // back to a previous state, not create a new one!

                if (!fixmystreet.page) {
                    // Only care about map pages, which set this variable
                    return;
                }

                var location = window.history.location || window.location;

                if (e.state === null) {
                    // Hashchange or whatever, we don't care.
                    return;
                }

                if ('initial' in e.state) {
                    // User has navigated Back from a pushStated state, presumably to
                    // see the list of all reports (which was shown on pageload). By
                    // this point, the browser has *already* updated the URL bar so
                    // location.href is something like foo.com/around?pc=abc-123,
                    // which we pass into fixmystreet.display.reports_list() as a fallback
                    // in case the list isn't already in the DOM.
                    $('#filter_categories').add('#statuses').add('#sort').find('option')
                        .prop('selected', function() { return this.defaultSelected; })
                        .trigger('change.multiselect');
                    if (fixmystreet.utils && fixmystreet.utils.parse_query_string) {
                        var qs = fixmystreet.utils.parse_query_string();
                        var page = qs.p || 1;
                        $('#show_old_reports').prop('checked', qs.show_old_reports || '');
                        $('.pagination:first').data('page', page)
                            .trigger('change.filters');
                    }
                    fixmystreet.display.reports_list(location.href);
                } else if ('reportId' in e.state) {
                    fixmystreet.display.report(e.state.reportPageUrl, e.state.reportId);
                } else if ('newReportAtLonlat' in e.state) {
                    fixmystreet.display.begin_report(e.state.newReportAtLonlat, false);
                } else if ('page_change' in e.state) {
                    fixmystreet.markers.protocol.use_page = true;
                    $('#show_old_reports').prop('checked', e.state.page_change.show_old_reports);
                    $('.pagination:first').data('page', e.state.page_change.page) //;
                        .trigger('change.filters');
                    if ( fixmystreet.page != 'reports' ) {
                        fixmystreet.display.reports_list(location.href);
                    }
                } else if ('filter_change' in e.state) {
                    $('#filter_categories').val(e.state.filter_change.filter_categories);
                    $('#statuses').val(e.state.filter_change.statuses);
                    $('#sort').val(e.state.filter_change.sort);
                    $('#show_old_reports').prop('checked', e.state.filter_change.show_old_reports);
                    $('#filter_categories').add('#statuses')
                        .trigger('change.filters').trigger('change.multiselect');
                    fixmystreet.display.reports_list(location.href);
                // } else if ('hashchange' in e.state) {
                    // This popstate was just here because the hash changed.
                    // (eg: mobile nav click.) We want to ignore it.
                }
                if ('mapState' in e.state) {
                    fixmystreet.maps.set_map_state(e.state.mapState);
                }

            });
        }, 0);
    });

});
