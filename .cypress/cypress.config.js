// jshint esversion: 6

const { defineConfig } = require("cypress");

module.exports = defineConfig({
  allowCypressEnv: false,

  projectId: "y8vvs1",
  blockHosts: ["gaze.mysociety.org", "*.openstreetmap.org", "portal.roadworks.org", "tilma.mysociety.org", "tilma.staging.mysociety.org", "isharemaps.bathnes.gov.uk", "consent.cookiebot.com", "assets.adobedtm.com", "www.googletagmanager.com", "www.googleadservices.com", "*.virtualearth.net", "feedback.happy-or-not.com"],
  expose: {
     postcode: "BS10 5EE"
  },
  hosts: {
      "*.localhost": "127.0.0.1"
  },

  e2e: {
    baseUrl: "http://fixmystreet.localhost:3001",
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
  },
});
