;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SentView: FMS.FMSView.extend({
            template: 'sent',
            id: 'sent-page',
            prev: 'around',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'vclick .ui-btn-left': 'onClickButtonPrev'
            }
        })
    });
})(FMS, Backbone, _, $);
