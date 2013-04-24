(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        LoginView: FMS.FMSView.extend({
            template: 'login',
            id: 'login',
            next: 'home',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #login': 'onClickLogin',
                'click #logout': 'onClickLogout',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext'
            },

            onClickLogin: function() {
                if ( this.validate() ) {
                    var that = this;
                    $.ajax( {
                        url: CONFIG.FMS_URL + '/auth/ajax/sign_in',
                        type: 'POST',
                        data: {
                            email: $('#form_email').val(),
                            password_sign_in: $('#form_password').val()
                        },
                        dataType: 'json',
                        timeout: 30000,
                        success: function( data, status ) {
                            if ( data.name ) {
                                that.model.set('password', $('#form_password').val());
                                that.model.set('email', $('#form_email').val());
                                that.model.set('name', data.name);
                                that.model.save();
                                $('#password_row').hide();
                                $('#success_row').show();
                            } else {
                                that.validationError('form_email', FMS.strings.login_error);
                            }
                        },
                        error: function() {
                            alert('boo :(');
                        }
                    } );
                }
            },

            onClickLogout: function() {
                this.model.set('password', '');
                this.model.save();
                $('#signed_in_row').hide();
                $('#password_row').show();
            },

            validate: function() {
                var isValid = 1;

                if ( !$('#form_password').val() ) {
                    isValid = 0;
                    this.validationError('form_password', FMS.validationStrings.password );
                }

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
            }
        })
    });
})(FMS, Backbone, _, $);
