var variation = cxApi.chooseVariation(),
    docElement = document.documentElement,
    className = docElement.className;

if (!/about\/council/.test(location.pathname)) {
    docElement.className = className + ' variant' + variation;
}
