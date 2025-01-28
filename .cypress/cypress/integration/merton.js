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

describe('stoppers for park category', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
  });
  it('does not allow reporting park category not on a park layer', function() {
    cy.visit('http://merton.localhost:3001/report/new?latitude=51.400975&longitude=-0.19655');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.get('.pre-button-messaging').contains('Please select a Merton-owned park from the map');
    cy.get('.pre-button-messaging').contains('To report an issue at Morden Hall Park').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Mitcham Common').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Wimbledon Common').should('not.exist');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
  });

  it('allows reporting a park category on a merton owned park layer', function() {
    cy.route('**mapserver/merton*all_parks*', 'fixture:merton-lavendar.xml').as('merton-parks');
    cy.visit('http://merton.localhost:3001/report/new?longitude=-0.170620&latitude=51.411907');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.wait('@merton-parks');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('does not allow reporting on Morden Hall Park with appropriate message', function() {
    cy.route('**mapserver/merton*all_parks*', 'fixture:merton-morden-hall.xml').as('merton-parks');
    cy.visit('http://merton.localhost:3001/report/new?longitude=-0.186162&latitude=51.403673');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.wait('@merton-parks');
    cy.get('.pre-button-messaging').contains('Please select a Merton-owned park from the map').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Morden Hall Park');
    cy.get('.pre-button-messaging').contains('To report an issue at Mitcham Common').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Wimbledon Common').should('not.exist');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
  });

  it('does not allow reporting on Mitcham Common with appropriate message', function() {
    cy.route('**mapserver/merton*all_parks*', 'fixture:merton-mitcham.xml').as('merton-parks');
    cy.visit('http://merton.localhost:3001/report/new?longitude=-0.137502&latitude=51.393623');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.wait('@merton-parks');
    cy.get('.pre-button-messaging').contains('Please select a Merton-owned park from the map').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Morden Hall Park').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Mitcham Common');
    cy.get('.pre-button-messaging').contains('To report an issue at Wimbledon Common').should('not.exist');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
  });

  it('does not allow reporting on Wimbledon Common with appropriate message', function() {
    cy.route('**mapserver/merton*all_parks*', 'fixture:merton-wimbledon.xml').as('merton-parks');
    cy.visit('http://merton.localhost:3001/report/new?longitude=-0.253360&latitude=51.429054');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.wait('@merton-parks');
    cy.get('.pre-button-messaging').contains('Please select a Merton-owned park from the map').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Morden Hall Park').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Mitcham Common').should('not.exist');
    cy.get('.pre-button-messaging').contains('To report an issue at Wimbledon Common');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
  });

  it('allows reporting on Commons Extension Sports Ground outside Merton and only reports to Merton', function() {
    cy.route('**mapserver/merton*all_parks*', 'fixture:merton-wimbledon.xml').as('merton-parks');
    cy.visit('http://merton.localhost:3001/report/new?longitude=-0.254369&latitude=51.427796');
    cy.wait('@report-ajax');
    cy.pickCategory('Parks');
    cy.wait('@merton-parks');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.nextPageReporting();
    cy.nextPageReporting();
    cy.contains('These will be sent to Merton Council and also published').should('be.visible');
  });
});
