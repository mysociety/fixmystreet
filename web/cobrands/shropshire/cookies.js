/*function getCookie(name) {
    var cookie, c;
    cookies = document.cookie.split(';');
    for (var i=0; i < cookies.length; i++) {
        c = cookies[i].split('=');
        if (c[0] == name) {
            return c[1];
        }
    }
    return "";
}*/

function findCookies(name) {
    var r = [];
    document.cookie.replace(new RegExp("("+name + "[^= ]*) *(?=\=)", "g"), function(a, b, ix){if(/[ ;]/.test(document.cookie.substr(ix-1, 1))) r.push(a.trim());});
    return r;
}

function getCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}

function setCookie(name,value,days) {
    if(findCookies(name).length != 0) {
        document.cookie = name + "=" + (value || "");
    } else {
        var expires = "";
        if (days) {
            var date = new Date();
            date.setTime(date.getTime() + (days*24*60*60*1000));
            expires = "; expires=" + date.toUTCString();
        }
        document.cookie = name + "=" + (value || "")  + expires + "; path=/";
    }
}

function removeCookie(name) {
    var cookiesToRemove = (findCookies(name) || []);
    for(var i = 0; i < cookiesToRemove.length; i++) {
        document.cookie = cookiesToRemove[i] +'=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';
    }
}

function acceptCookies() {
    setCookie("cookies_accepted", "yes", 20);
    removeCookie("test");
    // gtag start
    window.dataLayer = window.dataLayer || []; 
    function gtag(){dataLayer.push(arguments);} 
    gtag('js', new Date()); 
    
    gtag('config', 'G-1EJP6Q9PMT'); 
    // gtag end

    document.querySelectorAll("div.cookie-warning")[0].style.display = "none";
}

function declineCookies() {
    var cookiesToDelete = [
        "_ga",
        "_gid",
        "_ga_",
        "_gac_gb_",
        "_gac_",
        "AMP_TOKEN",
        "_gat"
    ];
    setCookie("cookies_accepted", "no", 20);
    for(var i = 0; i < cookiesToDelete.length; i++) {
        removeCookie(cookiesToDelete[i]);
    }
    document.querySelectorAll("div.cookie-warning")[0].style.display = "none";
}

// fallback
if(getCookie("cookies_accepted") === undefined) {
    document.querySelectorAll("div.cookie-warning")[0].style.display = "block";
}

if(getCookie("cookies_accepted") === "no") {
    declineCookies();
}

if(getCookie("cookies_accepted") === "yes") {
    acceptCookies();
}

document.getElementsByClassName("cookieaccept")[0].addEventListener('click', function(event) {
    event.preventDefault();
    acceptCookies();
    return false;
});

document.getElementsByClassName("cookiedeny")[0].addEventListener('click', function(event) {
    event.preventDefault();
    declineCookies();
    return false;
});
