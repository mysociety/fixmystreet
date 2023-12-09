// jshint esversion: 8

fixmystreet.offlineReporting = (function() {
    function updateDraftSavedTimestamp(ts) {
        if (ts) {
            var b = ts.split(/\D+/);
            var d = new Date(Date.UTC(b[0], --b[1], b[2], b[3], b[4], b[5], b[6]));
            ts = new Intl.DateTimeFormat(undefined, { timeStyle: 'short', dateStyle: 'long' }).format(d);
            $("#draft_save_message").removeClass("hidden").find("span").text(ts);
        } else {
            $("#draft_save_message").addClass("hidden").find("span").text("");
        }
    }

    function blobToBase64(blob) {
        return new Promise((resolve, _) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result);
            reader.readAsDataURL(blob);
        });
    }

    function updateDraftList() {
        loadDrafts().then(async function(drafts) {
            $("#offline_drafts").toggleClass("hidden", drafts.length < 1);
            var tpl = $('#draft-item').html();
            if (!tpl) {
                // confirmation page?
                return;
            }
            var $list = $('#offline_draft_list').clone();
            $list.empty();
            for (var i=0; i<drafts.length; i++) {
                var draft = drafts[i];
                var loc = draft.latitude ? '(' + draft.latitude + ',' + draft.longitude + '), ' : '';
                var b = draft.saved.split(/\D+/);
                var d = new Date(Date.UTC(b[0], --b[1], b[2], b[3], b[4], b[5], b[6]));
                var ts = new Intl.DateTimeFormat(undefined, { timeStyle: 'short', dateStyle: 'long' }).format(d);

                var $entry = $(tpl);
                $entry.find('[data-template-field="title"]').text(draft.title);
                $entry.find('[data-template-field="location"]').text(loc);
                $entry.find('[data-template-field="date"]').text(ts);
                $entry.attr('data-id', i);

                var photo_keys = Object.keys(draft.photos);
                if (photo_keys.length) {
                    var blob = draft.photos[photo_keys[0]].blob;
                    var base64data = await blobToBase64(blob);
                    $entry.find('[data-template-field="photo"]').attr('src', base64data).removeClass('hidden');
                }
                $list.append($entry);
            }
            $('#offline_draft_list').replaceWith($list);
        });
    }

    function dropzoneSetup() {
        if ('Dropzone' in window) {
            Dropzone.autoDiscover = false;
        } else {
            return;
        }

        var default_message = translation_strings.upload_default_message;
        if ($("html").hasClass("mobile")) {
            default_message = translation_strings.upload_default_message_mobile;
        }
        const MAX_FILES = 3;
        var dz = new Dropzone('#form_photos', {
            url: '/photo/upload/offline',
            paramName: 'photo',
            maxFiles: MAX_FILES,
            addRemoveLinks: true,
            thumbnailHeight: 256,
            thumbnailWidth: 256,
            resizeHeight: 2048,
            resizeWidth: 2048,
            resizeQuality: 0.6,
            acceptedFiles: 'image/jpeg,image/pjpeg,image/gif,image/tiff,image/png,.png,.tiff,.tif,.gif,.jpeg,.jpg',
            dictDefaultMessage: default_message,
            dictCancelUploadConfirmation: translation_strings.upload_cancel_confirmation,
            dictInvalidFileType: translation_strings.upload_invalid_file_type,
            dictMaxFilesExceeded: translation_strings.upload_max_files_exceeded,
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
        dz.on("reset", function() {
            // the call to dropzone.removeAllFiles() can leave Dropzone in a confused
            // state - dropzone.files is empty, the image thumbnails get
            // left behind, and maxFiles can be negative.
            // We manually tidy up here to ensure a known-good state.
            $(dz.element).find(".dz-preview").remove();
            dz.options.maxFiles = MAX_FILES;
        });
    }

    function storeDraftPhoto(file, blob) {
        loadDraft().then(function(draft) {
            draft.photos[file.name] = {
                name: file.name,
                type: file.type,
                blob: blob
            };

            return storeDraft(undefined, draft);
        });
    }

    function removeDraftPhoto(file) {
        loadDraft().then(function(draft) {
            if (file.name in draft.photos) {
                delete draft.photos[file.name];
            }

            return storeDraft(undefined, draft);
        });
    }

    function loadDrafts() {
        return idbKeyval.get('draftOfflineReports').then(function (drafts) {
            return drafts || [];
        });
    }

    /* Loads the provided draft from the list, or if no ID provided,
     * the draft of the report form, or if that's blank, starts a new
     * one at the end of the list */
    function loadDraft(draft_id) {
        if (draft_id === undefined) {
            draft_id = $('input[name=id]').val();
        }
        return loadDrafts().then(function(drafts) {
            var draft = {
                latitude: "",
                longitude: "",
                title: "",
                detail: "",
                photos: {},
                saved: null
            };
            if (draft_id === '') {
                drafts.push(draft);
                $('input[name=id]').val(drafts.length-1);
                return draft;
            } else {
                return drafts[draft_id];
            }
        });
    }

    function storeDraft(draft_id, draft) {
        var ts = (new Date()).toISOString();
        draft.saved = ts;

        if (draft_id === undefined) {
            draft_id = $('input[name=id]').val();
        }

        loadDrafts().then(function(drafts) {
            drafts[draft_id] = draft;
            return idbKeyval.set('draftOfflineReports', drafts).then(function() {
                updateDraftSavedTimestamp(ts);
                updateDraftList();
            });
        });
    }

    function updateDraft() {
        loadDraft().then(function(draft) {
            draft.latitude = $("input[name=latitude]").val();
            draft.longitude = $("input[name=longitude]").val();
            draft.title = $("input[name=title]").val();
            draft.detail = $("textarea[name=detail]").val();

            return storeDraft(undefined, draft);
        });
    }

    function validateDraftForm() {
        // Don't want to save a totally empty report so consider
        // form invalid if none of the following elements have a value.
        return [
            $("input[name=latitude]").val(),
            $("input[name=longitude]").val(),
            $("input[name=title]").val(),
            $("textarea[name=detail]").val()
        ].reduce((acc, curr) => {
            return acc || !!curr;
        }, false);
    }

    function restoreDraft(id, draft) {
        $("input[name=id]").val(id);
        $("input[name=latitude]").val(draft.latitude);
        $("input[name=longitude]").val(draft.longitude);
        if (draft.longitude || draft.latitude) {
            $("#offline_geolocate span").text("Update location");
            $('#offline_geolocate_location').text('Location stored: (' + draft.latitude + ',' + draft.longitude + ')');
        } else {
            $('#offline_geolocate_location').text('');
            $("#offline_geolocate span").text("Use my location");
        }
        $("input[name=title]").val(draft.title);
        $("textarea[name=detail]").val(draft.detail);
        updateDraftSavedTimestamp(draft.saved);
        restoreDraftPhotos(draft.photos);
    }

    function resetDraftForm() {
        $("input[name=id]").val('');
        $("input[name=latitude]").val('');
        $("input[name=longitude]").val('');
        $('#offline_geolocate_location').text('');
        $("#offline_geolocate span").text("Use my location");
        $("input[name=title]").val('');
        $("textarea[name=detail]").val('');
        updateDraftSavedTimestamp(null);
        restoreDraftPhotos({});
    }

    function restoreDraftPhotos(photos) {
        var $dropzone = $('#form_photos');
        if (!$dropzone.length) {
            return;
        }

        var dropzone =$dropzone.get(0).dropzone;
        dropzone.removeAllFiles();
        dropzone.emit("reset");
        Object.values(photos).map(function (file) {
            var reader = new FileReader();
            reader.onload = function(e) {
                var mockFile = { name: file.name, dataURL: e.target.result };
                addDropzoneThumbnail(mockFile, dropzone);
            };
            reader.readAsDataURL(file.blob);
        });
    }

    function uploadDraftPhotos(draft_id, photos) {
        var $dropzone = $('.dropzone');
        if (!$dropzone.length) {
            return;
        }

        var dropzone =$dropzone.get(0).dropzone;
        dropzone.on("complete", function(file) {
            // Photo was sent to server so store its server_id so we don't have
            // to upload it again
            updateDraftPhotoServerID(draft_id, file);
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

    function updateDraftPhotoServerID(draft_id, file) {
        if (!file.server_id || !file.name) {
            return;
        }
        loadDraft(draft_id).then(function(draft) {
            if (draft.photos[file.name]) {
                draft.photos[file.name].server_id = file.server_id;
            }
            return storeDraft(draft_id, draft);
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

    function deleteDraft(i) {
        loadDrafts().then(function(drafts) {
            drafts.splice(i, 1);
            return idbKeyval.set('draftOfflineReports', drafts).then(function() {
                resetDraftForm();
                updateDraftList();
            });
        });
    }

    function setCurrentDraftID(draft_id) {
        return idbKeyval.set('currentOfflineDraftID', draft_id);
    }

    // Wraps a function to ensure it's only called at most once every
    // <limit> milliseconds. We use it here to limit the per-keystroke draft
    // saving which is a bit slow on some mobile devices. Once per second is
    // reasonable enough.
    function throttle(fn, limit) {
        var wait = false;
        var that, args;

        var throttled = function() {
            if (args == null) {
                wait = false;
            } else {
                fn.apply(that, args);
                args = null;
                setTimeout(throttled, limit);
            }
        };

        return function () {
            if (wait) {
                that = this;
                args = arguments;
            } else {
                fn.apply(that, args);
                wait = true;
                setTimeout(throttled, limit);
            }
        };
    }

    return {
        offlineFormSetup: function() {
            dropzoneSetup();

            $(document).on('click', '.js-continue-draft', function() {
                var id = parseInt(this.parentNode.parentNode.getAttribute('data-id'), 10);
                loadDraft(id).then(function(d) {
                    if (!d.longitude || !d.latitude) {
                        location.href = "/?setDraftLocation=" + id + '&draftName=' + d.title;
                    } else {
                        location.href = "/report/new?restoreDraft=" + id + "&latitude=" + d.latitude + "&longitude=" + d.longitude;
                    }
                });
            });
            $(document).on('click', ".js-edit-draft", function() {
                var id = parseInt(this.parentNode.parentNode.getAttribute('data-id'), 10);
                loadDraft(id).then(function(d) {
                    restoreDraft(id, d);
                    window.scroll(0, document.querySelector('#offline_form').offsetTop);
                });
            });
            $(document).on('click', ".js-delete-draft", function(e) {
                e.preventDefault();
                if (confirm(this.getAttribute('data-confirm'))) {
                    deleteDraft(this.parentNode.parentNode.getAttribute('data-id'));
                }
            });
            $('.js-save-draft').on('click', function() {
                if (validateDraftForm()) {
                    updateDraft();
                    resetDraftForm();
                    scrollTo(0,0);
                }
            });

            $("form#offline_report").find("input, textarea").on("input", throttle(function () {
                updateDraft();
            }, 1000));

            updateDraftList();
        },

        deleteCurrentDraft: function() {
            return idbKeyval.get('currentOfflineDraftID').then(function(draft_id) {
                deleteDraft(draft_id);
            });
        },

        geolocate: function(pos) {
            var lat = pos.coords.latitude.toFixed(6);
            var lon = pos.coords.longitude.toFixed(6);
            $("input[name=latitude]").val(lat);
            $("input[name=longitude]").val(lon);
            $("#offline_geolocate span").text("Update location");
            $('#offline_geolocate_location').text('Location stored: (' + lat + ',' + lon + ')');
            updateDraft();
         },

        reportNewSetup: function() {
            var params = new URLSearchParams(location.search);
            var draft_id = params.get('restoreDraft');
            if (draft_id) {
                loadDraft(draft_id).then(function(draft) {
                    $("input[name=title]").val(draft.title);
                    $("textarea[name=detail]").val(draft.detail);

                    // We're online so try and send up photos
                    uploadDraftPhotos(draft_id, draft.photos);

                    $("input[name=title], textarea[name=detail]").on("input", throttle(function () {
                        updateDraft(draft_id);
                    }, 1000));
                    setCurrentDraftID(draft_id);
                });
            }
         },
    };
})();

(function(){

var link = document.getElementById('offline_geolocate');
if (fixmystreet.geolocate && link) {
    fixmystreet.geolocate(link, fixmystreet.offlineReporting.geolocate);
}

if (document.getElementById('offline_draft_list')) {
    fixmystreet.offlineReporting.offlineFormSetup();
}

if (document.querySelector('.confirmation-header')) {
    fixmystreet.offlineReporting.deleteCurrentDraft();
}

})();
