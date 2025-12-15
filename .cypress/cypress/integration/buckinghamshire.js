describe('buckinghamshire cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('**mapserver/bucks*WinterRoutes*', 'fixture:roads.xml').as('winter-routes');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.route('/around/nearby*').as('around-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
  });

  it('sets the site_code correctly', function() {
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Parks');
    cy.get('[name=site_code]').should('have.value', '7300268');
    cy.nextPageReporting();
    cy.get('span').contains('Photo').should('be.visible');
  });

  it('uses the label "Full name" for the name field', function() {
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Flytipping');
    cy.wait('@around-ajax');

    cy.nextPageReporting();
    cy.get('#form_road-placement').select('off-road');
    cy.nextPageReporting();
    cy.nextPageReporting(); // No photo
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.nextPageReporting();
    cy.get('label[for=form_name]').should('contain', 'Full name');
  });

  it('shows gritting message', function() {
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Snow and ice problem/winter salting');
    cy.wait('@winter-routes');
    cy.nextPageReporting();
    cy.contains('The road you have selected is on a regular gritting route').should('be.visible');
  });
});

describe("Parish grass cutting category speed limit question", function() {
  var speedGreaterThan30 = '#form_speed_limit_greater_than_30';

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('**mapserver/bucks*WinterRoutes*', 'fixture:roads.xml').as('winter-routes');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.route('/around/nearby*').as('around-ajax');
  });

  function parishGrassCuttingSetup(fixtureFile, callback) {
    cy.route('/arcgis/services/Transport/OS_Highways_Speed/MapServer/WFSServer**', 'fixture:' + fixtureFile).as('speed-limits');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Grass, hedges and weeds');
    cy.nextPageReporting();
    cy.pickSubcategory('Grass hedges and weeds', 'Grass cutting');
    cy.wait('@around-ajax');
    cy.wait('@speed-limits');
    callback();
  }

  it('displays the parish name if answer is "no"', function() {
    parishGrassCuttingSetup('bucks_speed_limits_30.xml', function() {
      cy.get(speedGreaterThan30).should('have.value', 'no');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Adstock Parish Council and also published online').should('be.visible');
    });
  });

  it('displays the council name if answer is "yes"', function() {
    parishGrassCuttingSetup('bucks_speed_limits_60.xml', function() {
      cy.get(speedGreaterThan30).should('have.value', 'yes');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Buckinghamshire Council and also published online').should('be.visible');
    });
  });

  it('displays the council name if answer is "dont_know"', function() {
    parishGrassCuttingSetup('bucks_speed_limits_none.xml', function() {
      cy.get(speedGreaterThan30).should('have.value', 'dont_know');
      cy.nextPageReporting();
      cy.nextPageReporting();
      cy.contains('sent to Buckinghamshire Council and also published online').should('be.visible');
    });
  });
});

describe("Correct body showing depending on category", function() {
  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('**mapserver/bucks*WinterRoutes*', 'fixture:roads.xml').as('winter-routes');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.route('/around/nearby*').as('around-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
  });

  it('displays only the parish name for other parish categories', function() {
    cy.pickCategory('Grass, hedges and weeds');
    cy.nextPageReporting();
    cy.pickSubcategory('Grass, hedges and weeds', 'Hedge problem');
    cy.wait('@around-ajax');
    cy.nextPageReporting();
    cy.nextPageReporting();
    cy.contains('These will be sent to Adstock Parish Council and also published online');
  });

  it("doesn't show the parish name for Buckinghamshire categories", function() {
    cy.pickCategory('Roads');
    cy.wait('@around-ajax');
    cy.nextPageReporting();
    cy.nextPageReporting();
    cy.contains('These will be sent to Buckinghamshire Council and also published online');
  });
});

describe('buckinghamshire roads handling', function() {
  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();

    cy.get('.map-mobile-report-button').click();
    cy.wait('@report-ajax');
    cy.get('#mob_ok').should('be.visible').click();
  });

  it('makes you move the pin if not on a road', function() {
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Roads & Pavements', 'Parks');
    cy.nextPageReporting();
    cy.contains('Please select a road on which to make a report.').should('be.visible');
  });

  it('asks you to move the pin for grass cutting reports', function() {
    cy.pickCategory('Grass, hedges and weeds');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.pickSubcategory('Grass hedges and weeds', 'Grass cutting');
    cy.nextPageReporting();
    cy.contains('Please select a road on which to make a report.').should('be.visible');
  });
});

describe('Abandoned vehicle behaviour', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Abandoned/Nuisance vehicle');
    cy.nextPageReporting();
    cy.pickSubcategory('Abandoned/Nuisance vehicle', 'A vehicle blocking a footpath');
    cy.nextPageReporting();
  });

  it('No reg plate', function() {
    cy.get('.js-reporting-page--active').contains('No').click();
    cy.nextPageReporting();
    cy.get('[name=VEHICLE_REGISTRATION]').should('have.value', 'Not known');
  });

  it('Said yes but no reg plate', function() {
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.nextPageReporting();
    cy.contains('This field is required');
  });

  it('Gave an okay reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_ok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('G00D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.contains('White Audi car, Petrol, 2016');
    cy.contains('that are taxed or have a valid MOT');
  });

  it('Gave an untaxed reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_notok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('B4D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.get('[name=VEHICLE_REGISTRATION]').should('have.value', 'B4D');
    cy.get('[name=ABANDONED_VEHICLE_TAXED]').should('have.value', 'No');
    cy.get('[name=ABANDONED_SELECT_TYPE]').should('have.value', 'Motorbike');
    cy.get('[name="MAKE_/_COLOUR_OF_THE_VEHI"]').should('have.value', 'Kawasaki / Black');
  });
});
