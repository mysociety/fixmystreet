$.extend(fixmystreet.set_up, {
  manage_duplicates: function() {
      // Deal with changes to report state by inspector/other staff, specifically
      // displaying nearby reports if it's changed to 'duplicate'.
      function refresh_duplicate_list() {
          var report_id = $("#report_inspect_form .js-report-id").text();
          var args = {
              filter_category: $("#report_inspect_form select#category").val(),
              latitude: $('input[name="latitude"]').val(),
              longitude: $('input[name="longitude"]').val()
          };
          $("#js-duplicate-reports ul").html("<li>Loading...</li>");
          var nearby_url = '/report/'+report_id+'/nearby.json';
          $.getJSON(nearby_url, args, function(data) {
              var duplicate_of = $("#report_inspect_form [name=duplicate_of]").val();
              var $reports = $(data.current)
                              .filter("li")
                              .not("[data-report-id="+report_id+"]")
                              .slice(0, 5);
              $reports.filter("[data-report-id="+duplicate_of+"]").addClass("item-list--reports__item--selected");

              (function() {
                  var timeout;
                  $reports.on('mouseenter', function(){
                      clearTimeout(timeout);
                      fixmystreet.maps.markers_highlight(parseInt($(this).data('reportId'), 10));
                  }).on('mouseleave', function(){
                      timeout = setTimeout(fixmystreet.maps.markers_highlight, 50);
                  });
              })();

              $("#js-duplicate-reports ul").empty().prepend($reports);

              $reports.find("a").click(function() {
                  var report_id = $(this).closest("li").data('reportId');
                  $("#report_inspect_form [name=duplicate_of]").val(report_id);
                  $("#js-duplicate-reports ul li").removeClass("item-list--reports__item--selected");
                  $(this).closest("li").addClass("item-list--reports__item--selected");
                  return false;
              });

              show_nearby_pins(data, report_id);
          });
      }

      function show_nearby_pins(data, report_id) {
          var markers = fixmystreet.maps.markers_list( data.pins, true );
          // We're replacing all the features in the markers layer with the
          // possible duplicates, but the list of pins from the server doesn't
          // include the current report. So we need to extract the feature for
          // the current report and include it in the list of features we're
          // showing on the layer.
          var report_marker = fixmystreet.maps.get_marker_by_id(parseInt(report_id, 10));
          if (report_marker) {
              markers.unshift(report_marker);
          }
          fixmystreet.markers.removeAllFeatures();
          fixmystreet.markers.addFeatures( markers );
      }

      function state_change() {
          // The duplicate report list only makes sense when state is 'duplicate'
          if ($(this).val() !== "duplicate") {
              $("#js-duplicate-reports").addClass("hidden");
              return;
          } else {
              $("#js-duplicate-reports").removeClass("hidden");
          }
          // If this report is already marked as a duplicate of another, then
          // there's no need to refresh the list of duplicate reports
          var duplicate_of = $("#report_inspect_form [name=duplicate_of]").val();
          if (!!duplicate_of) {
              return;
          }

          refresh_duplicate_list();
      }

      $("#report_inspect_form").on("change.state", "select#state", state_change);
      $("#js-change-duplicate-report").click(refresh_duplicate_list);
  },

  list_item_actions: function() {
    function toggle_shortlist(btn, sw, id) {
        btn.attr('class', 'item-list__item__shortlist-' + sw);
        btn.attr('title', btn.data('label-' + sw));
        if (id) {
            sw += '-' + id;
        }
        btn.attr('name', 'shortlist-' + sw);
    }

    $('.item-list--reports').on('click', ':submit', function(e) {
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
          var token = $('[name=token]').val();
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
          toggle_shortlist($submitButton, 'add', report_id);
      } else if ('shortlist-add' === whatUserWants) {
          toggle_shortlist($submitButton, 'remove', report_id);
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
          toggle_shortlist($submitButton, 'remove', report_id);
        } else if ('shortlist-add' === whatUserWants) {
          toggle_shortlist($submitButton, 'add', report_id);
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
        var $emailInput = $('input[name=email]').add('input[name=rznvy]');
        var $nameInput = $('input[name=name]');
        var $showNameCheckbox = $('input[name=may_show_name]');
        var $addAlertCheckbox = $('#form_add_alert');
        if (val === 'myself') {
            $emailInput.val($emailInput.prop('defaultValue')).prop('disabled', true);
            $nameInput.val($nameInput.prop('defaultValue')).prop('disabled', false);
            $showNameCheckbox.prop('checked', false).prop('disabled', false);
            $addAlertCheckbox.prop('checked', true).prop('disabled', false);
        } else if (val === 'another_user') {
            $emailInput.val('').prop('disabled', false);
            $nameInput.val('').prop('disabled', false);
            $showNameCheckbox.prop('checked', false).prop('disabled', true);
            $addAlertCheckbox.prop('checked', true).prop('disabled', false);
        } else if (val === 'body') {
            $emailInput.val('-').prop('disabled', true);
            $nameInput.val(txt).prop('disabled', true);
            $showNameCheckbox.prop('checked', true).prop('disabled', true);
            $addAlertCheckbox.prop('checked', false).prop('disabled', true);
        }
    });
    $('.js-contribute-as').change();
  },

  report_page_inspect: function() {
    if (!$('form#report_inspect_form').length) {
        return;
    }

    // Focus on form
    $('html,body').scrollTop($('#report_inspect_form').offset().top);

    // On the manage/inspect report form, we already have all the extra inputs
    // in the DOM, we just need to hide/show them as appropriate.
    $('form#report_inspect_form [name=category]').change(function() {
        var category = $(this).val(),
            selector = "[data-category='" + category + "']";
        $("form#report_inspect_form [data-category]:not(" + selector + ")").addClass("hidden");
        $("form#report_inspect_form " + selector).removeClass("hidden");
        // And update the associated priority list
        var priorities = $("form#report_inspect_form " + selector).data('priorities');
        var $select = $('#problem_priority'),
            curr_pri = $select.val();
        $select.find('option:gt(0)').remove();
        $.each(priorities.split('&'), function(i, kv) {
            if (!kv) {
                return;
            }
            kv = kv.split('=', 2);
            $select.append($('<option>', { value: kv[0], text: decodeURIComponent(kv[1]) }));
        });
        $select.val(curr_pri);
    });

    // The inspect form submit button can change depending on the selected state
    $("#report_inspect_form [name=state]").change(function(){
        var state = $(this).val();
        var $inspect_form = $("#report_inspect_form");
        var $submit = $inspect_form.find("input[type=submit]");
        var value = $submit.attr('data-value-'+state);
        if (value !== undefined) {
            $submit.val(value);
        } else {
            $submit.val($submit.data('valueOriginal'));
        }

        // We might also have a response template to preselect for the new state
        var $select = $inspect_form.find("select.js-template-name");
        var $option = $select.find("option[data-problem-state='"+state+"']").first();
        if ($option.length) {
            $select.val($option.val()).change();
        }
    }).change();

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

    if (geo_position_js.init()) {
        fixmystreet.geolocate.setup(function(pos) {
            var latlon = new OpenLayers.LonLat(pos.coords.longitude, pos.coords.latitude);
            var bng = latlon.clone().transform(
                new OpenLayers.Projection("EPSG:4326"),
                new OpenLayers.Projection("EPSG:27700") // TODO: Handle other projections
            );
            $("#problem_northing").text(bng.lat.toFixed(1));
            $("#problem_easting").text(bng.lon.toFixed(1));
            $("#problem_latitude").text(latlon.lat.toFixed(6));
            $("#problem_longitude").text(latlon.lon.toFixed(6));
            $("form#report_inspect_form input[name=latitude]").val(latlon.lat);
            $("form#report_inspect_form input[name=longitude]").val(latlon.lon);
        });
    }
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
              $elem.find('.js-moderate').on('click', function () {
                  $elem.find('.moderate-display').hide();
                  $elem.find('.moderate-edit').show();
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
                  $elem.find('.moderate-display').show();
                  $elem.find('.moderate-edit').hide();
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
  }
});
