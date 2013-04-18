(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SaveOfflineView: FMS.FMSView.extend({
            template: 'save_offline',
            id: 'save_offline',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #save_report': 'saveReport',
                'click #discard': 'discardReport'
            },

            saveReport: function() {
                this.navigate('reports');
            },

            discardReport: function() {
                var reset = FMS.removeDraft(FMS.currentDraft.id, true);
                var that = this;
                reset.done( function() { that.onDraftRemove(); } );
            },

            onDraftRemove: function() {
                this.navigate( 'around', 'left' );
            }
        })
    });
})(FMS, Backbone, _, $);
