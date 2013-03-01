;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        FMSView: Backbone.View.extend({
            tag: 'div',

            events: {
                'pagehide': 'destroy',
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
                if ( this.model ) {
                    this.$el.html(template(this.model.toJSON()));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            },

            afterRender: function() {},

            afterDisplay: function() {},

            navigate: function( route, direction ) {
                if ( !direction ) {
                    direction == 'left';
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
