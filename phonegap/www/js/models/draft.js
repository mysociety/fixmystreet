(function(FMS, Backbone, _, $, moment) {
    _.extend( FMS, {
        Draft: Backbone.Model.extend({
            localStorage: new Backbone.LocalStorage(CONFIG.NAMESPACE + '-drafts'),

            defaults: {
                lat: 0,
                lon: 0,
                title: '',
                details: '',
                may_show_name: '',
                category: '',
                phone: '',
                pc: '',
                file: '',
                created: moment.utc()
            },

            description: function() {
                var desc = '';
                if ( this.get('title') ) {
                    desc += this.get('title');
                } else {
                    desc += 'Untitled draft';
                }
                desc += ', ' + this.createdDate();

                return desc;
            },

            createdDate: function() {
                return moment.utc( this.get('created') ).format( 'H:m Do MMM' );
            }
        })
    });
})(FMS, Backbone, _, $, moment);

(function(FMS, Backbone, _, $) {
    _.extend( FMS, {
        Drafts: Backbone.Collection.extend({
            model: FMS.Draft,
            localStorage: new Backbone.LocalStorage(CONFIG.NAMESPACE + '-drafts')
        })
    });
})(FMS, Backbone, _, $);
