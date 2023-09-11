it('loads the Merton FMS Pro front page', function() {
    cy.visit('http://merton.localhost:3001/');
    cy.contains('Merton Council');
});

describe('additional question fields maximum length', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://merton.localhost:3001/report/new?latitude=51.400975&longitude=-0.19655');
    cy.wait('@report-ajax');
    cy.pickCategory('Flytipping');
    cy.nextPageReporting();
    cy.get('input#form_evidence').as('evidence');
  });
  it('does not allow typing >100 chars', function() {
    cy.get('@evidence').type('a'.repeat(110));
    cy.get('@evidence').invoke('val').then(function(val){
        expect(val.length).to.be.at.most(100);
    });
    cy.nextPageReporting();
  });
  it('does not allow user to continue if value is >100', function() {
    cy.get('@evidence').invoke('val', 'a'.repeat(110));
    cy.get('@evidence').invoke('val').then(function(val){
        expect(val.length).to.equal(110);
    });
    cy.nextPageReporting();
    cy.contains("Please enter no more than 100 characters.");
  });
});

describe('anonymous reporting per category', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://merton.localhost:3001/report/new?latitude=51.400975&longitude=-0.19655');
    cy.wait('@report-ajax');
  });
  it('allows anonymous reporting on Flytipping', function() {
    cy.pickCategory('Flytipping');
    cy.nextPageReporting();
    cy.get('[name=evidence]').type('Evidence');
    cy.nextPageReporting();
    cy.nextPageReporting(); // No photo
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.get('.js-show-if-anonymous').should('be.visible');
  });
  it('does not allow anonymous reporting on Flyposting', function() {
    cy.pickCategory('Flyposting');
    cy.nextPageReporting();
    cy.nextPageReporting(); // No photo
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.get('.js-show-if-anonymous').should('not.be.visible');
  });
});
