describe('Adding a photo', function() {
  it('starts off a new problem', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('/');
    cy.contains('Go');
    cy.get('[name=pc]').type(Cypress.env('postcode'));
    cy.get('[name=pc]').parents('form').submit();
    cy.url().should('include', '/around');
    cy.get('#map_box').click(200, 200);
    cy.wait('@report-ajax');
    cy.pickCategory('Flyposting');
    cy.nextPageReporting();
  });
  it('uploads a photo', function() {
    cy.server();
    cy.route('POST', '/photo/upload').as('photo-upload');
    cy.uploadPhoto('photo.jpeg', '.dropzone');
    cy.nextPageReporting();
  });
  it('finishes creating the report, and redacts the photo', function() {
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.nextPageReporting();
    cy.get('.js-new-report-show-sign-in').should('be.visible').click();
    cy.get('#form_username_sign_in').type('cs@example.org');
    cy.get('[name=password_sign_in]').type('password');
    cy.get('[name=password_sign_in]').parents('form').submit();
    cy.get('#map_sidebar').should('contain', 'check and confirm your details');
    cy.get('#map_sidebar').parents('form').submit();
    cy.get('body').should('contain', 'Thank you for reporting this issue');
    cy.contains('Title').click();
    cy.contains('Moderate').click();
    cy.contains('Redact').click();
    cy.get('canvas')
      .trigger('mousedown', { which: 1, pageX: 200, pageY: 200 })
      .trigger('mousemove', { which: 1, pageX: 300, pageY: 300 })
      .trigger('mouseup');
    cy.contains('Undo').click();
    cy.get('canvas').should('have.length', 1);
    cy.get('canvas')
      .trigger('mousedown', { which: 1, pageX: 300, pageY: 200 })
      .trigger('mousemove', { which: 1, pageX: 400, pageY: 300 })
      .trigger('mouseup');
    cy.get('canvas').should('have.length', 2);
    cy.get('canvas').last()
      .trigger('mousedown', { which: 1, pageX: 500, pageY: 200 })
      .trigger('mousemove', { which: 1, pageX: 600, pageY: 300 })
      .trigger('mouseup');
    cy.contains('Done').click();
    cy.contains('Redact (2)');
    cy.get('[name=redact_0]').invoke('val').should('contain', '"w":100');
    cy.get('[name=size_0]').invoke('val').should('contain', '"width":640');
    cy.contains('Save').click();
    // ImageMagick not on for tests, otherwise could check image had changed
    // Now remove the report so other tests don't fail
    cy.contains('Moderate').click();
    cy.contains('Hide entire report').click();
    cy.contains('Save').click();
  });
});
