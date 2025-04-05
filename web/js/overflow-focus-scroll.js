/*
 * If you tab to something entirely out of view, the browser scrolls to include it,
 * but if it is half in view (say a row of photos with overflow-x: scroll), it does
 * not. This custom element will make sure anything scrolls into view on focus.
 */

// jshint esversion: 6

function focused(e) {
    e.target.scrollIntoView({ block: "nearest", inline: "nearest" });
}

class OverflowFocusScroll extends HTMLElement {
  constructor() {
    super();
    this.addEventListener('focus', focused, true);
  }
}

window.customElements.define('overflow-focus-scroll', OverflowFocusScroll);
