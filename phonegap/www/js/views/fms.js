(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        FMSView: Backbone.View.extend({
            tag: 'div',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext'
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                var args = null;
                if ( this.options.msg ) {
                    args = { msg: this.options.msg };
                }
                if ( this.model ) {
                    if ( args ) {
                        args.model = this.model.toJSON();
                    } else {
                        args = this.model.toJSON();
                    }
                }
                this.$el.html(template(args));
                this.afterRender();
                return this;
            },

            fixPageHeight: function() {
                var screen = $(window).height(),
                header = $('[data-role=header]').height(),
                footer = $('[data-role=footer]').height(),
                content = screen - header - footer;
                $('[data-role=content]').css({'height': content });
            },

            afterRender: function() {},

            beforeDisplay: function() {
                this.fixPageHeight();
            },

            afterDisplay: function() {},

            navigate: function( route, direction ) {
                if ( !direction ) {
                    direction = 'left';
                }

                FMS.router.navigate( route, { trigger: true } );
            },

            onClickButtonPrev: function() {
                this.navigate( this.prev, 'right' );
            },

            onClickButtonNext: function() {
                this.navigate( this.next, 'left' );
            },

            displayError: function(msg) {
                alert(msg);
            },

            validationError: function( id, error ) {
                var el_id = '#' + id;
                var el = $(el_id);
                var err = '<div for="' + id + '" class="form-error">' + error + '</div>';
                if ( $('div[for='+id+']').length === 0 ) {
                    el.before(err);
                    el.addClass('form-error');
                }
            },

            clearValidationErrors: function() {
                $('div.form-error').remove();
                $('.form-error').removeClass('form-error');
            },

            destroy: function() { console.log('destory for ' + this.id); this._destroy(); this.remove(); },

            _destroy: function() {}
        })
    });
    _.extend( FMS.FMSView, Backbone.Events );
})(FMS, Backbone, _, $);
