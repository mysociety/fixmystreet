;(function (FMS, Backbone, _, $) {
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

            initialize: function() {
                this.model.on('sync', this.onReportSync, this );
                this.model.on('error', this.onReportError, this );
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                if ( this.model ) {
                    this.$el.html(template({ model: this.model.toJSON(), user: FMS.currentUser }));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            },

            onClickSubmit: function(e) {
                this.model.set( 'submit_clicked', $(e.target).attr('id') );

                this.model.save();
            },

            onReportSync: function(model, resp, options) {
                this.navigate( 'sent', 'left' );
            },

            onReportError: function(model, err, options) {
                alert( FMS.strings.sync_error + ': ' + err.errors);
            },

            _destroy: function() {
                this.model.off('sync');
                this.model.off('error');
            }
        })
    });
})(FMS, Backbone, _, $);
