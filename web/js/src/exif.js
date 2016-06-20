/* Cut down version of https://github.com/exif-js/exif-js
 * only looking for orientation EXIF data. MIT. */

(function() {
    var EXIF = {};
    window.EXIF = EXIF;

    function readEXIFData(file, start) {
        var str = "";
        for (var n = start; n < start+4; n++) {
            str += String.fromCharCode(file.getUint8(n));
        }
        if (str != "Exif") {
            return false;
        }

        var bigEnd,
            tiffOffset = start + 6;

        // test for TIFF validity and endianness
        if (file.getUint16(tiffOffset) == 0x4949) {
            bigEnd = false;
        } else if (file.getUint16(tiffOffset) == 0x4D4D) {
            bigEnd = true;
        } else {
            return false;
        }

        if (file.getUint16(tiffOffset+2, !bigEnd) != 0x002A) {
            return false;
        }

        var firstIFDOffset = file.getUint32(tiffOffset+4, !bigEnd);
        if (firstIFDOffset < 0x00000008) {
            return false;
        }

        var dirStart = tiffOffset + firstIFDOffset,
            entries = file.getUint16(dirStart, !bigEnd),
            tags = {},
            entryOffset,
            i;

        for (i=0;i<entries;i++) {
            entryOffset = dirStart + i*12 + 2;
            if (file.getUint16(entryOffset, !bigEnd) == 0x0112) {
                return parseInt(file.getUint16(entryOffset + 8, !bigEnd), 10);
            }
        }
        return false;
    }

    EXIF.getData = function(img) {
        if ((img instanceof Image || img instanceof HTMLImageElement) && !img.complete) {
            return false;
        }

        var base64 = img.src.replace(/^data\:([^\;]+)\;base64,/gmi, '');
        var binary = atob(base64);
        var len = binary.length;
        var file = new ArrayBuffer(len);
        var view = new Uint8Array(file);
        for (var i = 0; i < len; i++) {
            view[i] = binary.charCodeAt(i);
        }

        var dataView = new DataView(file);
        if ((dataView.getUint8(0) != 0xFF) || (dataView.getUint8(1) != 0xD8)) {
            return false; // not a valid jpeg
        }

        var offset = 2,
            length = file.byteLength,
            marker;

        while (offset < length) {
            if (dataView.getUint8(offset) != 0xFF) {
                return false; // not a valid marker, something is wrong
            }

            marker = dataView.getUint8(offset + 1);

            // we could implement handling for other markers here,
            // but we're only looking for 0xFFE1 for EXIF data
            if (marker == 225) {
                return readEXIFData(dataView, offset + 4);
                // offset += 2 + file.getShortAt(offset+2, true);
            } else {
                offset += 2 + dataView.getUint16(offset+2);
            }
        }
    };

})();
