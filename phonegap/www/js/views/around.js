;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        AroundView: FMS.FMSView.extend({
            template: 'around',
            tag: 'div',
            id: 'around-page',

            afterDisplay: function() {
                console.log( 'around after display');
                fixmystreet.latitude = 56.33182;
                fixmystreet.longitude = -2.79483;

                show_map();
                console.log('map shown');
            }
        })
    });
})(FMS, Backbone, _, $);
