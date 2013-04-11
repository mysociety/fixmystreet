(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        ExistingView: FMS.FMSView.extend({
            template: 'existing',
            id: 'existing',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click #use_report': 'useReport',
                'click #discard': 'discardReport'
            },

            useReport: function() {
                localStorage.currentDraftID = FMS.currentDraft.id;
                this.navigate('around');
            },

            discardReport: function() {
                var uri = FMS.currentDraft.get('file');
                FMS.allDrafts.remove(FMS.currentDraft);
                FMS.currentDraft.destroy();
                localStorage.currentDraftID = null;
                FMS.currentDraft = new FMS.Draft();

                if ( uri ) {
                    var del = FMS.files.deleteURI( uri );

                    var that = this;
                    del.done( function() { that.navigate( 'around' ); } );

                } else {
                    this.navigate( 'around', 'left' );
                }
            }
        })
    });
})(FMS, Backbone, _, $);
