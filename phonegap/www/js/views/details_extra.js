(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        DetailsExtraView: FMS.FMSView.extend({
            template: 'details_extra',
            id: 'details-extra-page',
            prev: 'details',
            next: 'submit-start',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick .ui-btn-left': 'onClickButtonPrev',
                'vclick .ui-btn-right': 'onClickButtonNext',
                'blur textarea': 'updateCurrentReport',
                'change select': 'updateCurrentReport',
                'blur input': 'updateCurrentReport'
            },

            afterRender: function() {
                console.log(this.model);
                this.populateFields();
            },

            onClickButtonPrev: function() {
                this.updateCurrentReport();
                this.navigate( this.prev, true );
            },

            onClickButtonNext: function() {
                this.clearValidationErrors();
                var valid = 1;
                var that = this;

                var isRequired = function(index) {
                    var el = $(this);
                    if ( el.attr('required') && el.val() === '' ) {
                        valid = 0;
                        that.validationError(el.attr('id'), FMS.strings.required);
                    }
                };
                // do validation
                $('input').each(isRequired);
                $('textarea').each(isRequired);
                $('select').each(isRequired);

                if ( valid ) {
                    this.clearValidationErrors();
                    this.updateCurrentReport();
                    this.navigate( this.next );
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

            updateSelect: function() {
                this.updateCurrentReport();
            },

            updateCurrentReport: function() {
                var fields = [];
                var that = this;
                var update = function(index) { 
                    var el = $(this);
                    if ( el.val() !== '' ) {
                        that.model.set(el.attr('name'), el.val());
                        fields.push(el.attr('name'));
                    } else {
                        that.model.set(el.attr('name'), '');
                    }

                };

                $('input').each(update);
                $('select').each(update);
                $('textarea').each(update);

                this.model.set('extra_details', fields);
                FMS.saveCurrentDraft();
            },

            populateFields: function() {
                var that = this;
                var populate = function(index) {
                    console.log(that.$(this).attr('name'));
                    that.$(this).val(that.model.get(that.$(this).attr('name')));
                };
                this.$('input').each(populate);
                this.$('select').each(populate);
                this.$('textarea').each(populate);
            }
        })
    });
})(FMS, Backbone, _, $);
