// jshint esversion: 6

const us = document.getElementById('page-refresh');
const every = us.dataset.every || 2;

function update() {
    const url = new URL(window.location.href);
    url.searchParams.append('page_loading', 1);
    fetch(url, { headers: { 'x-requested-with': 'fetch' } })
        .then(resp => resp.text())
        .then(html => {
            const parser = new DOMParser();
            const doc = parser.parseFromString('<div>' + html + '</div>', 'text/html').body.firstChild;

            const fragment = new DocumentFragment();
            takeChildrenFor(fragment, doc);

            if (fragment.querySelector('#loading-indicator')) {
                return setTimeout(update, every * 1000);
            }

            normalizeScriptTags(fragment);
            const content = document.querySelector('.content');
            swapInnerHTML(content, fragment);
        });
}

setTimeout(update, every * 1000);

// Based upon the HTMX functions

function takeChildrenFor(fragment, elt) {
    while (elt.childNodes.length > 0) {
        fragment.append(elt.childNodes[0]);
    }
}

function swapInnerHTML(target, fragment) {
    const firstChild = target.firstChild;
    while (fragment.childNodes.length > 0) {
        target.insertBefore(fragment.firstChild, firstChild);
    }
    if (firstChild) {
        while (firstChild.nextSibling) {
            firstChild.nextSibling.remove();
        }
        firstChild.remove();
    }
}

function normalizeScriptTags(fragment) {
    Array.from(fragment.querySelectorAll('script')).forEach((script) => {
        const newScript = duplicateScript(script);
        try {
            script.before(newScript);
        } finally {
            script.remove();
        }
    });
}

function duplicateScript(script) {
    const newScript = document.createElement('script');
    [].forEach.call(script.attributes, function(attr) {
        newScript.setAttribute(attr.name, attr.value);
    });
    newScript.textContent = script.textContent;
    newScript.async = false;
    return newScript;
}
