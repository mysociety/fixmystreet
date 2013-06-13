(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        DetailsView: FMS.FMSView.extend({
            template: 'details',
            id: 'details-page',
            prev: 'photo',
            next: 'submit-start',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick .ui-btn-left': 'onClickButtonPrev',
                'vclick .ui-btn-right': 'onClickButtonNext',
                'blur textarea': 'updateCurrentReport',
                'change select': 'updateSelect',
                'blur input': 'updateCurrentReport'
            },

            afterRender: function() {
                this.$('#form_category').attr('data-role', 'none');

                if ( this.model.get('category') ) {
                    this.$('#form_category').val( this.model.get('category') );
                }
                this.setSelectClass();

            },

            afterDisplay: function() {
                var header = $("div[data-role='header']:visible"),
                detail = this.$('#form_detail'),
                top = detail.position().top,
                viewHeight = $(window).height(),
                contentHeight = viewHeight - header.outerHeight();

                detail.height( contentHeight - top );
            },

            onClickButtonPrev: function() {
                this.updateCurrentReport();
                this.navigate( this.prev, true );
            },

            onClickButtonNext: function() {
                this.clearValidationErrors();
                var valid = 1;

                if ( !$('#form_title').val() ) {
                    valid = 0;
                    this.validationError( 'form_title', FMS.validationStrings.title );
                }

                if ( !$('#form_detail').val() ) {
                    valid = 0;
                    this.validationError( 'form_detail', FMS.validationStrings.detail );
                }

                var cat = $('#form_category').val();
                if ( cat == '-- Pick a category --' ) {
                    valid = 0;
                    this.validationError( 'form_category', FMS.validationStrings.category );
                }

                if ( valid ) {
                    this.clearValidationErrors();
                    this.updateCurrentReport();
                    if ( FMS.isOffline ) {
                        this.navigate( 'save_offline' );
                    } else {
                        this.navigate( this.next );
                    }
                }
            },

            validationError: function(id, error) {
                var el_id = '#' + id;
                var el = $(el_id);

                el.addClass('error');
                if ( el.val() === '' ) {
                    el.attr('orig-placeholder', el.attr('placeholder'));
                    el.attr('placeholder', error);
                }
            },

            clearValidationErrors: function() {
                $('.error').removeClass('error');
                $('.error').each(function(el) { if ( el.attr('orig-placeholder') ) { el.attr('placeholder', el.attr('orig-placeholder') ); } } );
            },

            setSelectClass: function() {
                var cat = this.$('#form_category');
                if ( cat.val() !== "" && cat.val() !== '-- Pick a category --' ) {
                    cat.removeClass('noselection');
                } else {
                    cat.addClass('noselection');
                }
            },

            updateSelect: function() {
                this.updateCurrentReport();
                this.setSelectClass();
            },

            updateCurrentReport: function() {
                if ( $('#form_category').val() && $('#form_title').val() && $('#form_detail').val() ) {
                    $('#next').addClass('page_complete_btn');
                } else {
                    $('#next').removeClass('page_complete_btn');
                }
                this.model.set('category', $('#form_category').val());
                this.model.set('title', $('#form_title').val());
                this.model.set('details', $('#form_detail').val());
                FMS.saveCurrentDraft();
            }
        })
    });
})(FMS, Backbone, _, $);
