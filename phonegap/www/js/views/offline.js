(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        OfflineView: FMS.LocatorView.extend({
            template: 'offline',
            id: 'offline',
            prev: 'home',
            next: 'reports',
            skipLocationCheck: true,

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'toggleNextButton',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext',
                'click #id_photo_button': 'takePhoto',
                'click #id_existing': 'addPhoto',
                'click #id_del_photo_button': 'deletePhoto',
                'click #locate': 'locate',
                'blur input': 'toggleNextButton',
                'blur textarea': 'toggleNextButton'
            },

            draftHasContent: function() {
                var hasContent = false;

                if ( $('#form_title').val() || $('#form_detail').val() ||
                     this.model.get('lat') || this.model.get('file') ) {
                    hasContent = true;
                }

                return hasContent;
            },

            toggleNextButton: function() {
                if ( this.draftHasContent() ) {
                    $('#offline-next-btn .ui-btn-text').text('Save');
                } else {
                    $('#offline-next-btn .ui-btn-text').text('Skip');
                }
            },

            failedLocation: function(details) {
                this.finishedLocating();
                this.locateCount = 21;

                $('#locate_result').html('Could not get position');
            },

            gotLocation: function(info) {
                this.finishedLocating();

                this.model.set('lat', info.coordinates.latitude);
                this.model.set('lon', info.coordinates.longitude);

                $('#locate_result').html('Got position (' + info.coordinates.latitude.toFixed(2) + ', ' + info.coordinates.longitude.toFixed(2) + ')');
            },

            takePhoto: function() {
                var that = this;
                navigator.camera.getPicture( function(imgURI) { that.addPhotoSuccess(imgURI); }, function(error) { that.addPhotoFail(error); }, { saveToPhotoAlbum: true, quality: 49, destinationType: Camera.DestinationType.FILE_URI, sourceType: navigator.camera.PictureSourceType.CAMERA, correctOrientation: true });
            },

            addPhoto: function() {
                var that = this;
                navigator.camera.getPicture( function(imgURI) { that.addPhotoSuccess(imgURI); }, function(error) { that.addPhotoFail(error); }, { saveToPhotoAlbum: false, quality: 49, destinationType: Camera.DestinationType.FILE_URI, sourceType: navigator.camera.PictureSourceType.PHOTOLIBRARY, correctOrientation: true });
            },

            addPhotoSuccess: function(imgURI) {
                var move = FMS.files.moveURI( imgURI );

                var that = this;
                move.done( function( file ) {
                    $('#photo').attr('src', file.toURL());
                    that.model.set('file', file.toURL());
                    FMS.saveCurrentDraft();

                    $('#photo-next-btn .ui-btn-text').text('Next');
                    $('#display_photo').show();
                    $('#add_photo').hide();
                });

                move.fail( function() { that.addPhotoFail(); } );
            },

            addPhotoFail: function() {
                if ( message != 'no image selected' &&
                    message != 'Selection cancelled.' &&
                    message != 'Camera cancelled.' ) {
                    this.displayError(FMS.strings.photo_failed);
                }
            },

            deletePhoto: function() {
                var that = this;
                var del = FMS.files.deleteURI( this.model.get('file') );

                del.done( function() {
                    that.model.set('file', '');
                    FMS.saveCurrentDraft();
                    $('#photo').attr('src', '');

                    $('#photo-next-btn .ui-btn-text').text('Skip');
                    $('#display_photo').hide();
                    $('#add_photo').show();
                });
            },

            onClickButtonNext: function() {
                this.updateCurrentReport();
                if ( !this.draftHasContent() && this.model.id ) {
                    var del = FMS.removeDraft( this.model.id );

                    var that = this;
                    del.done( function() { that.draftDeleted(); } );
                } else {
                    FMS.clearCurrentDraft();
                    this.navigate( this.next, 'left' );
                }
            },

            draftDeleted: function() {
                FMS.clearCurrentDraft();
                this.navigate( this.next, 'left' );
            },

            updateCurrentReport: function() {
                this.model.set('title', $('#form_title').val());
                this.model.set('details', $('#form_detail').val());
                FMS.saveCurrentDraft();
            }
        })
    });
})(FMS, Backbone, _, $);
