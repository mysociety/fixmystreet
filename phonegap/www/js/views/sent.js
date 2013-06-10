(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SentView: FMS.FMSView.extend({
            template: 'sent',
            id: 'sent-page',
            prev: 'around',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick .ui-btn-left': 'onClickButtonPrev'
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                this.$el.html(template(FMS.createdReport.toJSON()));
                this.afterRender();
                return this;
            }
        })
    });
})(FMS, Backbone, _, $);
