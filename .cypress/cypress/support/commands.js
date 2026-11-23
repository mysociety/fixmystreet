// jshint esversion: 6
Cypress.Commands.add('pickCategory', function(option) {
    cy.get('#form_category_fieldset label').contains(option).click();
});
Cypress.Commands.add('pickSubcategory', function(categoryId, subCategory) {
    cy.get('#subcategory_' + categoryId.replace(/[^a-zA-Z]+/g, '') + ' label').contains(subCategory).click();
});
Cypress.Commands.add('pickSubcatExtraInfo', function(option, selector) {
    cy.get(selector).select(option);
});
Cypress.Commands.add('nextPageReporting', function() {
    cy.get('.js-reporting-page--active:visible .js-reporting-page--next').click();
});

Cypress.Commands.add('uploadPhoto', function(filename, selector, lastModified) {
    var dropEvent = { dataTransfer: { files: [] } };
    cy.fixture('../fixtures/' + filename).then(function(picture) {
      let blob = Cypress.Blob.base64StringToBlob(picture, 'image/jpeg');
      if (lastModified) {
          blob = new File([blob], filename, { type: 'image/jpeg', lastModified: lastModified });
      }
      dropEvent.dataTransfer.files.push(blob);
    });
    cy.get(selector).trigger('drop', dropEvent);
    cy.wait('@photo-upload');
});
