/* Based on https://github.com/jakearchibald/idb-keyval/blob/main/src/index.ts, cut down */

var idbKeyval = function(e) {
    "use strict";

    const dbName = "keyval-store",
          storeName = "keyval";

    function promisifyRequest(request) {
        return new Promise(function(resolve, reject) {
            request.oncomplete = request.onsuccess = function() { return resolve(request.result) },
                request.onabort = request.onerror = function() { return reject(request.error) }
        });
    }

    var dbp;
    function getDB() {
        if (dbp) return dbp;
        var request = indexedDB.open(dbName);
        request.onupgradeneeded = function() { return request.result.createObjectStore(storeName) };
        dbp = promisifyRequest(request);
        dbp.then(
            (function(db) { db.onclose = function() { return dbp = undefined } }),
            (function(){})
        );
        return dbp;
    }

    function createStore(txMode, callback) {
        return getDB().then(function(db) { 
            return callback(db.transaction(storeName, txMode).objectStore(storeName))
        })
    }

    e.get = function(key) {
        return createStore("readonly", (function(store) {
            return promisifyRequest(store.get(key));
        }));
    };

    e.set = function(key, value) {
        return createStore("readwrite", (function(store) {
            store.put(value, key);
            return promisifyRequest(store.transaction);
        }));
    };

    e.del = function(key) {
        return createStore("readwrite", (function(store) {
            store.delete(key);
            return promisifyRequest(store.transaction);
        }));
    };

    e.close = function() {
        return getDB().then(function(n) { n.close(); dbp = null; })
    };

    return e;
}({});
