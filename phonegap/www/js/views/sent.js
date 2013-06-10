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
                'vclick .ui-btn-left': 'onClickButtonPrev',
                'vclick #rate_app': 'onClickRateApp'
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
            },

            onClickRateApp: function(e) {
                e.preventDefault();
                var el = $('#rate_app');
                var href = el.attr('href');
                window.open(href, '_system');
                return false;
            }
        })
    });
})(FMS, Backbone, _, $);
