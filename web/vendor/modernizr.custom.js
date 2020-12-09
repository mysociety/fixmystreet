/*
 modernizr 3.11.4 (Custom Build) | MIT *
 https://modernizr.com/download/?-mq-dontmin !*/
(function(d,e,k){function m(b,n,a,l){var f=e.createElement("div");var c=e.body;c||(c=e.createElement("body"),c.fake=!0);if(parseInt(a,10))for(;a--;){var d=e.createElement("div");d.id=l?l[a]:"modernizr"+(a+1);f.appendChild(d)}a=e.createElement("style");a.type="text/css";a.id="smodernizr";(c.fake?c:f).appendChild(a);c.appendChild(f);a.styleSheet?a.styleSheet.cssText=b:a.appendChild(e.createTextNode(b));f.id="modernizr";if(c.fake){c.style.background="";c.style.overflow="hidden";var g=h.style.overflow;
h.style.overflow="hidden";h.appendChild(c)}b=n(f,b);c.fake?(c.parentNode.removeChild(c),h.style.overflow=g,h.offsetHeight):f.parentNode.removeChild(f);return!!b}k={_version:"3.11.4"};var g=function(){};g.prototype=k;g=new g;var h=e.documentElement,p=function(){var b=d.matchMedia||d.msMatchMedia;return b?function(d){return(d=b(d))&&d.matches||!1}:function(b){var a=!1;m("@media "+b+" { #modernizr { position: absolute; } }",function(b){a="absolute"===("getComputedStyle"in d?getComputedStyle(b):b.currentStyle).position});
return a}}();k.mq=p;d.Modernizr=g})(window,document);
