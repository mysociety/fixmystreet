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
  it('does not allow typing >255 chars', function() {
    cy.get('@evidence').type('a'.repeat(260));
    cy.get('@evidence').invoke('val').then(function(val){
        expect(val.length).to.be.at.most(255);
    });
    cy.nextPageReporting();
});
it('does not allow user to continue if value is >255', function() {
    cy.get('@evidence').invoke('val', 'a'.repeat(260));
    cy.get('@evidence').invoke('val').then(function(val){
        expect(val.length).to.equal(260);
    });
    cy.nextPageReporting();
    cy.contains("Please enter no more than 255 characters.");
});
});
