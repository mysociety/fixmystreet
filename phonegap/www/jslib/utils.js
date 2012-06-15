/*
 * utils.js
 * Useful javascript functions, shared between mySociety sites.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: utils.js,v 1.3 2006-10-10 15:53:05 matthew Exp $
 * 
 */

mySociety = { 
    /* Returns an XMLHTTP object, if available.
     * Returns false if XMLHTTP not supported. */
    getXMLHTTP : function() {
        var xmlhttp=false;
        /*@cc_on @*/
        /*@if (@_jscript_version >= 5)
        // JScript gives us Conditional compilation, we can cope with old IE versions.
        // and security blocked creation of the objects.
        try { xmlhttp = new ActiveXObject("Msxml2.XMLHTTP"); }
        catch (e) {
            try { xmlhttp = new ActiveXObject("Microsoft.XMLHTTP"); }
            catch (E) { xmlhttp = false; }
        }
        @end @*/
        if (!xmlhttp && typeof XMLHttpRequest!='undefined') {
            try { xmlhttp = new XMLHttpRequest(); }
            catch (e) { xmlhttp=false; }
        }
        if (!xmlhttp && window.createRequest) {
            try { xmlhttp = window.createRequest(); }
            catch (e) { xmlhttp=false; }
        }
        return xmlhttp;
    },

    asyncRequest : function(url, func) {
        var xmlhttp = mySociety.getXMLHTTP();
        if (!xmlhttp) 
            return false;
        xmlhttp.open('GET', url, true);
        xmlhttp.onreadystatechange = function() {
            func(xmlhttp);
        }
        xmlhttp.send(null);
        return xmlhttp;
    }
}

