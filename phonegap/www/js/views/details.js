;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        DetailsView: FMS.FMSView.extend({
            template: 'details',
            id: 'details-page',
            prev: 'photo'
        })
    });
})(FMS, Backbone, _, $);
