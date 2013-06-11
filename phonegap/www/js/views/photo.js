(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        PhotoView: FMS.FMSView.extend({
            template: 'photo',
            id: 'photo-page',
            prev: 'around',
            next: 'details',

            events: {
                'pagehide': 'destroy',
                'pagebeforeshow': 'beforeDisplay',
                'pageshow': 'afterDisplay',
                'vclick .ui-btn-left': 'onClickButtonPrev',
                'vclick .ui-btn-right': 'onClickButtonNext',
                'vclick #id_photo_button': 'takePhoto',
                'vclick #id_existing': 'addPhoto',
                'vclick #id_del_photo_button': 'deletePhoto'
            },

            beforeDisplay: function() {
                this.fixPageHeight();
                if ( this.model.get('file') ) {
                    $('#id_photo_button').parents('.ui-btn').hide();
                    $('#id_existing').parents('.ui-btn').hide();
                } else {
                    this.$('#id_del_photo_button').parents('.ui-btn').hide();
                }
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
                    $('#id_del_photo_button').parents('.ui-btn').show();
                    $('#id_photo_button').parents('.ui-btn').hide();
                    $('#id_existing').parents('.ui-btn').hide();
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
                    $('#photo').attr('src', 'images/placeholder-photo.png');

                    $('#photo-next-btn .ui-btn-text').text('Skip');
                    $('#id_del_photo_button').parents('.ui-btn').hide();
                    $('#id_photo_button').parents('.ui-btn').show();
                    $('#id_existing').parents('.ui-btn').show();
                });

            }
        })
    });
})(FMS, Backbone, _, $);
