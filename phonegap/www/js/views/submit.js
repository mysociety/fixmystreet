(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitView: FMS.FMSView.extend({
            template: 'submit',
            id: 'submit-page',
            prev: 'details',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext',
                'click #submit_signed_in': 'onClickSubmit',
                'click #submit_sign_in': 'onClickSubmit',
                'click #submit_register': 'onClickSubmit'
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                if ( this.model ) {
                    this.$el.html(template({ model: this.model.toJSON(), user: FMS.currentUser.toJSON() }));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            },

            onClickSubmit: function(e) {
                this.beforeSubmit();

                if ( this.validate() ) {
                    this.model.set('user', FMS.currentUser);
                    this.report = new FMS.Report( this.model.toJSON() );
                    this.listenTo( this.report, 'sync', this.onReportSync );
                    this.listenTo( this.report, 'error', this.onReportError );
                    this.report.save();
                }
            },

            onReportSync: function(model, resp, options) {
                this.stopListening();
                if ( FMS.currentUser ) {
                    FMS.currentUser.save();
                }
                var reset = FMS.removeDraft( FMS,currentDraftID, true);
                var that = this;
                reset.done( function() { that.onRemoveDraft(); } );
            },

            onRemoveDraft: function() {
                FMS.currentDraft = new FMS.Draft();
                localStorage.currentDraftID = null;
                FMS.createdReport = this.report;
                this.navigate( 'sent', 'left' );
            },

            onReportError: function(model, err, options) {
                alert( FMS.strings.sync_error + ': ' + err.errors);
            },

            beforeSubmit: function() {},

            _destroy: function() {
                this.stopListening();
            }
        })
    });
})(FMS, Backbone, _, $);


(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitEmailView: FMS.SubmitView.extend({
            template: 'submit_email',
            id: 'submit-email-page',
            prev: 'details',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #have_password': 'onClickPassword',
                'click #email_confirm': 'onClickConfirm'
            },

            validate: function() {
                this.clearValidationErrors();
                var isValid = 1;

                var email = $('#form_email').val();
                if ( !email ) {
                    isValid = 0;
                    this.validationError('form_email', FMS.validationStrings.email.required);
                // regexp stolen from jquery validate module
                } else if ( ! /^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))$/i.test(email) ) {
                    isValid = 0;
                    this.validationError('form_email', FMS.validationStrings.email.email);
                }

                return isValid;
            },

            onClickPassword: function() {
                if ( this.validate() ) {
                    FMS.currentUser.set('email', $('#form_email').val());
                    this.navigate( 'submit-password' );
                }
            },

            onClickConfirm: function() {
                if ( this.validate() ) {
                    FMS.currentUser.set('email', $('#form_email').val());
                    this.navigate( 'submit-name' );
                }
            },

            _destroy: function() {}
        })
    });
})(FMS, Backbone, _, $);

(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitNameView: FMS.SubmitView.extend({
            template: 'submit_name',
            id: 'submit-name-page',
            prev: 'submit-email',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #send_confirm': 'onClickSubmit',
                'click #set_password': 'onClickPassword'
            },

            initialize: function() {
                console.log('submit name initalize');
                this.listenTo(this.model, 'sync', this.onReportSync );
                this.listenTo( this.model, 'error', this.onReportError );
            },

            validate: function() {
                this.clearValidationErrors();
                var isValid = 1;

                var name = $('#form_name').val();
                if ( !name ) {
                    isValid = 0;
                    this.validationError('form_name', FMS.validationStrings.name.required );
                } else {
                    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
                    if ( name.length < 6 || !name.match( /\S/ ) || name.match( validNamePat ) ) {
                        isValid = 0;
                        this.validationError('form_name', FMS.validationStrings.name.validName);
                    }
                }

                return isValid;
            },

            onClickPassword: function() {
                if ( this.validate() ) {
                    this.model.set('submit_clicked', 'submit_register');
                    FMS.currentUser.set('name', $('#form_name').val());
                    FMS.currentUser.set('phone', $('#form_phone').val());
                    this.navigate( 'submit-password' );
                }
            },

            beforeSubmit: function() {
                FMS.currentUser.set('name', $('#form_name').val());
                FMS.currentUser.set('phone', $('#form_phone').val());
            }
        })
    });
})(FMS, Backbone, _, $);

(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitPasswordView: FMS.SubmitView.extend({
            template: 'submit_password',
            id: 'submit-password-page',
            prev: 'submit-email',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #report': 'onClickSubmit',
                'click #confirm_name': 'onClickSubmit'
            },

            initialize: function() {
                this.listenTo(this.model, 'sync', this.onReportSync );
                this.listenTo( this.model, 'error', this.onReportError );
            },

            validate: function() {
                var isValid = 1;

                if ( !$('#form_password').val() ) {
                    isValid = 0;
                    this.validationError('form_password', FMS.validationStrings.password );
                }

                return isValid;
            },

            beforeSubmit: function() {
                if ( $('#form_name').val() ) {
                    this.model.set('submit_clicked', '');
                    FMS.currentUser.set('name', $('#form_name').val());
                } else {
                    // if this is set then we are registering a password
                    if ( ! this.model.get('submit_clicked') ) {
                        this.model.set('submit_clicked', 'submit_sign_in');
                    }
                    FMS.currentUser.set('password', $('#form_password').val());
                }
            },

            onReportError: function(model, err, options) {
                if ( err.check_name ) {
                    $('#form_name').val(err.check_name);
                    $('#password_row').hide();
                    $('#check_name').show();
                } else {
                    if ( err.errors && err.errors.password ) {
                        this.validationError('form_password', err.errors.password );
                    }
                }
            }

        })
    });
})(FMS, Backbone, _, $);

