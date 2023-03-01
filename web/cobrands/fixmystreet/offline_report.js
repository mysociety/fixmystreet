fixmystreet.offlineReporting = (function() {
    function updateDraftSavedTimestamp(ts) {
        if (ts) {
            $("#draft_save_message").removeClass("hidden").find("span").text(ts);
        } else {
            $("#draft_save_message").addClass("hidden").find("span").text("");
        }
    }

    function dropzoneSetup() {
        if ('Dropzone' in window) {
            Dropzone.autoDiscover = false;
        } else {
            return;
        }

        var dz = new Dropzone('#form_photos', {
            url: '/photo/upload/offline',
            paramName: 'photo',
            maxFiles: 3,
            addRemoveLinks: true,
            thumbnailHeight: 256,
            thumbnailWidth: 256,
            resizeHeight: 2048,
            resizeWidth: 2048,
            resizeQuality: 0.6,
            acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png,.png,.tiff,.tif,.gif,.jpeg,.jpg',
            transformFile: function(file, done) {
                // We have to intercept this as it seems the only place the
                // resized image is available, and a good place to store it
                // in IndexedDB.
                return this.resizeImage(file, this.options.resizeWidth, this.options.resizeHeight, this.options.resizeMethod, function(blob) {
                    storeDraftPhoto(file, blob);
                    return done(blob);
                });
            }
        });
        dz.on("removedfile", function(file) {
            removeDraftPhoto(file);
        });
    }

    function storeDraftPhoto(file, blob) {
        loadDraft().then(function(draft) {
            draft.photos[file.name] = {
                name: file.name,
                type: file.type,
                blob: blob
            };

            return storeDraft(draft);
        });
    }

    function removeDraftPhoto(file) {
        loadDraft().then(function(draft) {
            if (file.name in draft.photos) {
                delete draft.photos[file.name];
            }

            return storeDraft(draft);
        });
    }

    function loadDraft() {
        return idbKeyval.get('draftOfflineReports').then(function(drafts) {
            var draft = {
                latitude: "",
                longitude: "",
                title: "",
                detail: "",
                photos: {},
                saved: null
            };

            if (drafts && drafts.length) {
                draft = drafts[0];
            }

            return draft;
        });
    }

    function storeDraft(draft) {
        var ts = (new Date()).toISOString();
        draft.saved = ts;

        return idbKeyval.set('draftOfflineReports', [draft]).then(function() {
            updateDraftSavedTimestamp(ts);
        });
    }

    function updateDraft() {
        loadDraft().then(function(draft) {
            draft.latitude = $("input[name=latitude]").val();
            draft.longitude = $("input[name=longitude]").val();
            draft.title = $("input[name=title]").val();
            draft.detail = $("textarea[name=detail]").val();

            return storeDraft(draft);
        });
    }

    function restoreDraft() {
        loadDraft().then(function(draft) {
            $("input[name=latitude]").val(draft.latitude);
            $("input[name=longitude]").val(draft.longitude);
            if (draft.longitude || draft.latitude) {
                $("#geolocate span").text("Update location");
            } else {
                $("#geolocate span").text("Use my location");
            }
            $("input[name=title]").val(draft.title);
            $("textarea[name=detail]").val(draft.detail);
            updateDraftSavedTimestamp(draft.saved);
            restoreDraftPhotos(draft.photos);
        });
     }

    function restoreDraftPhotos(photos) {
        var dropzone = $("#form_photos").get(0).dropzone;
        dropzone.removeAllFiles();
        Object.values(photos).map(function (file) {
            var reader = new FileReader();
            reader.onload = function(e) {
                var mockFile = { name: file.name, dataURL: e.target.result };
                addDropzoneThumbnail(mockFile, dropzone);
            };
            reader.readAsDataURL(file.blob);
        });
    }

    function uploadDraftPhotos(photos) {
        var dropzone = $('.dropzone').get(0).dropzone;
        dropzone.on("complete", function(file) {
            // Photo was sent to server so store its server_id so we don't have
            // to upload it again
            updateDraftPhotoServerID(file);
        });
        Object.values(photos).map(function (photo) {
            if (photo.server_id) {
                // Has already been saved on server, only need to display thumbnail
                // and chuck server_id in upload_fileid field
                addDropzoneThumbnail({name: photo.name, server_id: photo.server_id, dataURL: '/photo/temp.' + photo.server_id}, dropzone);
                var $input = $("[name=upload_fileid]");
                var ids = ($input.val() || "").split(",").filter(function(v){ return v; });
                ids.push(photo.server_id);
                $input.val(ids.join(","));
            } else {
                var file = photo.blob;
                file.name = photo.name;
                dropzone.addFile(file);
            }
        });
    }

    function updateDraftPhotoServerID(file) {
        if (!file.server_id || !file.name) {
            return;
        }
        loadDraft().then(function(draft) {
            if (draft.photos[file.name]) {
                draft.photos[file.name].server_id = file.server_id;
            }
            return storeDraft(draft);
        });
    }

    function addDropzoneThumbnail(photo, dropzone) {
        dropzone.emit("addedfile", photo);
        dropzone.createThumbnailFromUrl(photo,
            dropzone.options.thumbnailWidth, dropzone.options.thumbnailHeight,
            dropzone.options.thumbnailMethod, true, function(thumbnail) {
                dropzone.emit('thumbnail', photo, thumbnail);
            });
        dropzone.emit("complete", photo);
        dropzone.options.maxFiles -= 1;
    }

    function deleteDrafts() {
        return idbKeyval.set('draftOfflineReports', []).then(function() {
            return restoreDraft();
        });
    }

    return {
        offlineFormSetup: function() {
            dropzoneSetup();
            $(".js-delete-drafts").on("click", function() {
                if (confirm(this.getAttribute('data-confirm'))) {
                    deleteDrafts();
                }
            });

            $("form#offline_report").find("input, textarea").on("input", function() {
                updateDraft();
            });
            restoreDraft();
        },

        geolocate: function(pos) {
            $("input[name=latitude]").val(pos.coords.latitude.toFixed(6));
            $("input[name=longitude]").val(pos.coords.longitude.toFixed(6));
            $("#geolocate span").text("Update location");
            updateDraft();
         },

         reportNewSetup: function() {
            if (location.search.indexOf("restoreDraft=1") > 0) {
                loadDraft().then(function(draft) {
                    $("input[name=title]").val(draft.title);
                    $("textarea[name=detail]").val(draft.detail);

                    // We're online so try and send up photos
                    uploadDraftPhotos(draft.photos);

                    $("input[name=title], textarea[name=detail]").on("input", function() {
                        updateDraft();
                    });
                });
            }
         },

         frontPageSetup: function() {
            if (!window.idbKeyval) {
                return;
            }
            idbKeyval.get('draftOfflineReports').then(function(drafts) {
                if (drafts && drafts.length) {
                    var d = drafts[0];
                    document.querySelector(".js-continue-draft").className = "";
                    var lk = document.querySelector('a.continue-draft-btn');
                    lk.href = "/report/new?restoreDraft=1&latitude=" + d.latitude + "&longitude=" + d.longitude;
                }
            });

         },
    };
})();

(function(){

var link = document.getElementById('geolocate');
if (fixmystreet.geolocate && link) {
    fixmystreet.geolocate(link, fixmystreet.offlineReporting.geolocate);
}

if (document.getElementById('offline_report')) {
    fixmystreet.offlineReporting.offlineFormSetup();
}
})();