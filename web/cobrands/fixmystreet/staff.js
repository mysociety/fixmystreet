fixmystreet.staff_set_up = {
  action_scheduled_raise_defect: function() {
    $("#report_inspect_form").find('[name=state]').on('change', function() {
        if ($(this).val() !== "action scheduled") {
            $("#js-inspect-action-scheduled").addClass("hidden");
            $('#raise_defect_yes').prop('required', false);
            $('#defect_type').prop('required', false);
        } else {
            $("#js-inspect-action-scheduled").removeClass("hidden");
            $('#raise_defect_yes').prop('required', true);
            var dt_required = $('#defect_type')[0].length > 1 && $('input[name=raise_defect]:checked').val();
            $('#defect_type').prop('required', dt_required ? true : false);
        }
    });
    $('input[name=raise_defect]').change(function() {
        var dt_required = $('#defect_type')[0].length > 1 && this.value;
        $('#defect_type').prop('required', dt_required ? true : false);
    });
  },

  list_item_actions: function() {
    $('#js-reports-list').on('click', ':submit', function(e) {
      e.preventDefault();

      var $submitButton = $(this);
      var whatUserWants = $submitButton.prop('name');
      var data;
      var $item;
      var $list;
      var $hiddenInput;
      var report_id;
      if (fixmystreet.page === 'around') {
          // Deal differently because one big form
          var parts = whatUserWants.split('-');
          whatUserWants = parts[0] + '-' + parts[1];
          report_id = parts[2];
          var token = $('meta[name="csrf-token"]').attr('content');
          data = whatUserWants + '=1&token=' + token + '&id=' + report_id;
      } else {
          var $form = $(this).parents('form');
          $item = $form.parent('.item-list__item');
          $list = $item.parent('.item-list');

          // The server expects to be told which button/input triggered the form
          // submission. But $form.serialize() doesn't know that. So we inject a
          // hidden input into the form, that can pass the name and value of the
          // submit button to the server, as it expects.
          $hiddenInput = $('<input>').attr({
            type: 'hidden',
            name: whatUserWants,
            value: $submitButton.prop('value')
          }).appendTo($form);
          data = $form.serialize() + '&ajax=1';
      }

      // Update UI while the ajax request is sent in the background.
      if ('shortlist-down' === whatUserWants) {
        $item.insertAfter( $item.next() );
      } else if ('shortlist-up' === whatUserWants) {
        $item.insertBefore( $item.prev() );
      } else if ('shortlist-remove' === whatUserWants) {
          fixmystreet.utils.toggle_shortlist($submitButton, 'add', report_id);
      } else if ('shortlist-add' === whatUserWants) {
          fixmystreet.utils.toggle_shortlist($submitButton, 'remove', report_id);
      }

      // Items have moved around. We need to make sure the "up" button on the
      // first item, and the "down" button on the last item, are disabled.
      fixmystreet.update_list_item_buttons($list);

      $.ajax({
        url: '/my/planned/change',
        type: 'POST',
        data: data
      }).fail(function() {
        // Undo the UI changes we made.
        if ('shortlist-down' === whatUserWants) {
          $item.insertBefore( $item.prev() );
        } else if ('shortlist-up' === whatUserWants) {
          $item.insertAfter( $item.next() );
        } else if ('shortlist-remove' === whatUserWants) {
          fixmystreet.utils.toggle_shortlist($submitButton, 'remove', report_id);
        } else if ('shortlist-add' === whatUserWants) {
          fixmystreet.utils.toggle_shortlist($submitButton, 'add', report_id);
        }
        fixmystreet.update_list_item_buttons($list);
      }).complete(function() {
        if ($hiddenInput) {
          $hiddenInput.remove();
        }
      });
    });
  },

  contribute_as: function() {
    $('.content').on('change', '.js-contribute-as', function(){
        var opt = this.options[this.selectedIndex],
            val = opt.value,
            txt = opt.text;
        var $emailInput = $('input[name=username]');
        var $emailOptionalLabel = $('label[for=form_username] span');
        var $nameInput = $('input[name=name]');
        var $phoneInput = $('input[name=phone]');
        var $showNameCheckbox = $('input[name=may_show_name]');
        var $addAlertCheckbox = $('#form_add_alert');
        if (val === 'myself') {
            $emailInput.val($emailInput.prop('defaultValue')).prop('disabled', true);
            $emailOptionalLabel.addClass('hidden');
            $nameInput.val($nameInput.prop('defaultValue')).prop('disabled', false);
            $phoneInput.val($phoneInput.prop('defaultValue')).prop('disabled', false);
            $showNameCheckbox.prop('checked', false).prop('disabled', false);
            $addAlertCheckbox.prop('checked', true).prop('disabled', false);
        } else if (val === 'another_user') {
            $emailInput.val('').prop('disabled', false);
            if (!$phoneInput.length) {
                // Cobrand may have disabled collection of phone numbers.
                $emailOptionalLabel.addClass('hidden');
                $emailInput.addClass('required');
            } else {
                $emailOptionalLabel.removeClass('hidden');
                $emailInput.removeClass('required');
            }
            $nameInput.val('').prop('disabled', false);
            $phoneInput.val('').prop('disabled', false);
            $showNameCheckbox.prop('checked', false).prop('disabled', true);
            $addAlertCheckbox.prop('checked', true).prop('disabled', false);
        } else if (val === 'anonymous_user') {
            $emailInput.val('-').prop('disabled', true);
            $emailOptionalLabel.addClass('hidden');
            $nameInput.val('-').prop('disabled', true);
            $phoneInput.val('-').prop('disabled', true);
            $showNameCheckbox.prop('checked', false).prop('disabled', true);
            $addAlertCheckbox.prop('checked', false).prop('disabled', true);
        } else if (val === 'body') {
            $emailInput.val('-').prop('disabled', true);
            $emailOptionalLabel.addClass('hidden');
            $nameInput.val(txt).prop('disabled', true);
            $phoneInput.val('-').prop('disabled', true);
            $showNameCheckbox.prop('checked', true).prop('disabled', true);
            $addAlertCheckbox.prop('checked', false).prop('disabled', true);
        }
    });
    $('.js-contribute-as').change();
  },

  report_page_inspect: function() {
    var $inspect_form = $('form#report_inspect_form'),
        $templates = $('#templates_for_public_update');

    if (!$inspect_form.length) {
        return;
    }

    // Focus on form
    if (!fixmystreet.inspect_form_no_scroll_on_load) {
        document.getElementById('side-inspect').scrollIntoView();
    }

    function updateTemplates(opts) {
        opts.category = opts.category || $inspect_form.find('[name=category]').val();
        opts.state = opts.state || $inspect_form.find('[name=state]').val();
        var selector = "[data-category='" + opts.category + "']";
        var data = $inspect_form.find(selector).data('templates') || [];
        if (data.constructor !== Array) {
          return;
        }
        data = $.grep(data, function(d, i) {
            if (!d.state || d.state == opts.state) {
                return true;
            }
            return false;
        });
        populateSelect($templates, data, 'templates_format');
    }

    function populateSelect($select, data, label_formatter) {
      $select.find('option:gt(0)').remove();
      if (data.constructor !== Array) {
        return;
      }
      $.each(data, function(k,v) {
        var label = window.fixmystreet.utils[label_formatter](v);
        var $opt = $('<option></option>').attr('value', v.id).text(label);
        if (v.state) {
            $opt.attr('data-problem-state', v.state);
        }
        $select.append($opt);
      });
    }

    // On the manage/inspect report form, we already have all the extra inputs
    // in the DOM, we just need to hide/show them as appropriate.
    $inspect_form.find('[name=category]').change(function() {
        var category = $(this).val(),
            selector = "[data-category='" + category + "']",
            entry = $inspect_form.find(selector),
            $priorities = $('#problem_priority'),
            $defect_types = $('#defect_type'),
            defect_types_data = entry.data('defect-types') || [],
            priorities_data = entry.data('priorities') || [],
            curr_pri = $priorities.val();

        $inspect_form.find("[data-category]:not(" + selector + ")").addClass("hidden");
        entry.removeClass("hidden");

        populateSelect($priorities, priorities_data, 'priorities_type_format');
        populateSelect($defect_types, defect_types_data, 'defect_type_format');
        updateTemplates({'category': category});
        $priorities.val(curr_pri);
    });

    function state_change(state) {
        // The inspect form submit button can change depending on the selected state
        var $submit = $inspect_form.find("input[type=submit][name=save]");
        var value = $submit.attr('data-value-' + state);
        $submit.val(value || $submit.data('valueOriginal'));

        updateTemplates({'state': state});
    }
    var $state_dropdown = $inspect_form.find("[name=state]");
    state_change($state_dropdown.val());
    $state_dropdown.change(function(){
        var state = $(this).val();
        state_change(state);
        // We might also have a response template to preselect for the new state
        var $select = $inspect_form.find("select.js-template-name");
        var $option = $select.find("option[data-problem-state='"+state+"']").first();
        if ($option.length) {
            $select.val($option.val()).change();
        }
    });

    $('.js-toggle-public-update').each(function() {
        var $checkbox = $(this);
        var toggle_public_update = function() {
            if ($checkbox.prop('checked')) {
                $('#public_update').parents('p').show();
            } else {
                $('#public_update').parents('p').hide();
            }
        };
        $checkbox.on('change', function() {
            toggle_public_update();
        });
        toggle_public_update();
    });

    if ($('#detailed_information').data('max-length')) {
        $('#detailed_information').on('keyup', function() {
            var $this = $(this),
            counter = $('#detailed_information_length');
            var chars_left = $this.data('max-length') - $this.val().length;
            counter.html(chars_left);
            if (chars_left < 0) {
                counter.addClass('error');
            } else {
                counter.removeClass('error');
            }
        });
    }

    if ('geolocation' in navigator) {
        var el = document.querySelector('.btn--geolocate');
        fixmystreet.geolocate(el, function(pos) {
            var latlon = new OpenLayers.LonLat(pos.coords.longitude, pos.coords.latitude);
            var bng = latlon.clone().transform(
                new OpenLayers.Projection("EPSG:4326"),
                new OpenLayers.Projection("EPSG:27700") // TODO: Handle other projections
            );
            $("#problem_northing").text(bng.lat.toFixed(1));
            $("#problem_easting").text(bng.lon.toFixed(1));
            $("#problem_latitude").text(latlon.lat.toFixed(6));
            $("#problem_longitude").text(latlon.lon.toFixed(6));
            $inspect_form.find("input[name=latitude]").val(latlon.lat);
            $inspect_form.find("input[name=longitude]").val(latlon.lon);
        });
    }

    // Make the "Provide an update" form toggleable, hidden by default.
    // (Inspectors will normally just use the #public_update box instead).
    $('.js-provide-update').on('click', function(e) {
        e.preventDefault();
        $(this).next().toggleClass('hidden-js');
    });
  },

  moderation: function() {
      function toggle_original ($input, revert) {
          $input.prop('disabled', revert);
          if (revert) {
              $input.data('currentValue', $input.val());
          }
          $input.val($input.data(revert ? 'originalValue' : 'currentValue'));
      }

      function add_handlers (elem, word) {
          elem.each( function () {
              var $elem = $(this);
              $elem.find('.js-moderate').on('click', function(e) {
                  e.preventDefault();
                  $elem.toggleClass('show-moderation');
                  $('#map_sidebar').scrollTop(word === 'problem' ? 0 : $elem[0].offsetTop);
              });

              $elem.find('.revert-title').change( function () {
                  toggle_original($elem.find('input[name=problem_title]'), $(this).prop('checked'));
              });

              $elem.find('.revert-textarea').change( function () {
                  toggle_original($elem.find('textarea'), $(this).prop('checked'));
              });

              var hide_document = $elem.find('.hide-document');
              hide_document.change( function () {
                  $elem.find('input[name=problem_title]').prop('disabled', $(this).prop('checked'));
                  $elem.find('textarea').prop('disabled', $(this).prop('checked'));
                  $elem.find('input[type=checkbox]').prop('disabled', $(this).prop('checked'));
                  $(this).prop('disabled', false); // in case disabled above
              });

              $elem.find('.cancel').click( function () {
                  $elem.toggleClass('show-moderation');
                  $('.js-moderation-error').hide();
                  $('#map_sidebar').scrollTop(word === 'problem' ? 0 : $elem[0].offsetTop);
              });

              $elem.find('form').submit( function () {
                  if (hide_document.prop('checked')) {
                      return confirm('This will hide the ' + word + ' completely!  (You will not be able to undo this without contacting support.)');
                  }
                  return true;
              });
          });
      }
      add_handlers( $('.problem-header'), 'problem' );
      add_handlers( $('.item-list__item--updates'), 'update' );
  },

  response_templates: function() {
    // If the user has manually edited the contents of an update field,
    // mark it as dirty so it doesn't get clobbered if we select another
    // response template. If the field is empty, it's not considered dirty.
    $('.js-template-name').each(function() {
        var $input = $('#' + $(this).data('for'));
        $input.change(function() { $(this).data('dirty', !/^\s*$/.test($(this).val())); });
    });

    $('.js-template-name').change(function() {
        var $this = $(this);
        var $input = $('#' + $this.data('for'));
        if (!$input.data('dirty')) {
            $input.val($this.val());
        }
    });
  },

  shortlist_listener: function() {
    $('#fms_shortlist_all').on('click', function() {
      var features = [];
      var csrf = $('meta[name="csrf-token"]').attr('content');

      for (var i = 0; i < fixmystreet.markers.features.length; i++) {
        var feature = fixmystreet.markers.features[i];
        if (feature.onScreen()) {
          features.push(feature.data.id);
        }
      }

      fixmystreet.maps.shortlist_multiple(features, csrf);
    });
  }

};

$(function() {
    $.each(fixmystreet.staff_set_up, function(setup_name, setup_func) {
        setup_func();
    });
});

$(fixmystreet).on('display:report', function() {
    fixmystreet.staff_set_up.moderation();
    fixmystreet.staff_set_up.response_templates();
    if ($("#report_inspect_form").length) {
        fixmystreet.staff_set_up.report_page_inspect();
        fixmystreet.staff_set_up.action_scheduled_raise_defect();
    }
});

$(fixmystreet).on('report_new:category_change', function(evt, $this) {
    var category = $this.val();
    var prefill_reports = $this.data('prefill');
    var body = $this.data('body');

    if (prefill_reports) {
        var title = 'A ' + category + ' problem has been found';
        var description = 'A ' + category + ' problem has been found by ' + body;

        var $title_field = $('#form_title');
        var $description_field = $('#form_detail');

        if ($title_field.val().length === 0 || $title_field.data('autopopulated') === true) {
            $title_field.val(title);
            $title_field.data('autopopulated', true);
        }

        if ($description_field.val().length === 0 || $description_field.data('autopopulated') === true) {
            $description_field.val(description);
            $description_field.data('autopopulated', true);
        }

        $('#form_title, #form_detail').on('keyup', function() {
            $(this).data('autopopulated', false);
        });
    }
});

fixmystreet.maps = fixmystreet.maps || {};

$.extend(fixmystreet.maps, {
  shortlist_multiple: function(ids, token, count) {
    var retryCount = (typeof count !== 'undefined') ?  count : 0;
    $.post("/my/planned/change_multiple", { ids: ids, token: token })
    .done(function() {
      var $itemList = $('.item-list'),
          items = [];

      for (var i = 0; i < ids.length; i++) {
        var problemId = ids[i],
            $item = $itemList.find('#report-'+ problemId),
            $form = $item.find('form'),
            $submit = $form.find("input[type='submit']" );

        fixmystreet.utils.toggle_shortlist($submit, 'remove', problemId);

        items.push({
          'url': '/report/' + $item.data('report-id'),
          'lastupdate': $item.data('lastupdate')
        });
      }
      $(document).trigger('shortlist-all', { items: items});
    })
    .fail(function(response) {
      if (response.status == 400 && retryCount < 4) {
        // If the response is 400, then get a new CSRF token and retry
        var csrf = response.responseText.match(/content="([^"]*)" name="csrf-token"/)[1];
        fixmystreet.maps.shortlist_multiple(ids, csrf, retryCount + 1);
      } else {
        alert("We appear to be having problems. Please try again later.");
      }
    });
  },

  show_shortlist_control: function() {
    var $shortlistButton = $('#fms_shortlist_all');
    if ($shortlistButton === undefined || fixmystreet.page != "reports" ) {
      return;
    }

    if (fixmystreet.map.getZoom() >= 14) {
      $shortlistButton.removeClass('hidden');
    } else {
      $shortlistButton.addClass('hidden');
    }
  }
});

$(fixmystreet).on('map:zoomend', function() {
    fixmystreet.maps.show_shortlist_control();
});

fixmystreet.utils = fixmystreet.utils || {};

$.extend(fixmystreet.utils, {
    defect_type_format: function(data) {
        return data.name;
    },
    priorities_type_format: function(data) {
        return data.name;
    },
    templates_format: function(data) {
        return data.name;
    },
    toggle_shortlist: function(btn, sw, id) {
        btn.attr('class', 'item-list__item__shortlist-' + sw);
        btn.attr('title', btn.data('label-' + sw));
        if (id) {
            sw += '-' + id;
        }
        btn.attr('name', 'shortlist-' + sw);
    }
});
