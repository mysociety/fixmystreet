;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        HomeView: FMS.FMSView.extend({
            template: 'home',
            tag: 'div',
            id: 'front-page'
        })
    });
})(FMS, Backbone, _, $);
