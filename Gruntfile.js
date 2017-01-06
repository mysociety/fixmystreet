module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),

    jekyll: { site: {} },

    connect: {
      server: {
        options: {
          base: "_site",
          port: 4000,
          livereload: true
        }
      }
    },

    uglify: {
      library: {
        files: {
          'assets/scripts/lib.min.js': [
            'bower_components/jquery/jquery.js',
            'bower_components/jquery/jquery-migrate.js',
            'bower_components/owlcarousel/owl-carousel/owl.carousel.js'
          ],
        }
      },
      main: {
        files: {
          'assets/scripts/app.min.js': 'assets/scripts/app.js'
        }
      },
    },

    sass: {
      global: {
        options: { style: 'compressed' },
        files: {
          'assets/css/fixmystreet-org.css': 'assets/sass/fixmystreet-org.scss'
        }
      }
    },

    watch: {
      options: { atBegin: true, },
      css: {
        files: [
          'assets/**/*.scss',
          'theme/**/*.scss',
        ],
        tasks: [ 'sass' ],
      },
      js: {
        files: [
          'assets/scripts/app.js'
        ],
        tasks: [ 'uglify' ],
      },
      jekyll: {
        files: [ 'assets/**', '**/*.html', '**/*.md', '!node_modules/**', '!bower_components/**', '!_site/**' ],
        tasks: [ 'jekyll' ],
      },
      livereload: {
        options: { atBegin: false, livereload: true, },
        // Look for Jekyll file changes, and changes to static assets
        // Ignore SCSS so that live CSS update can work properly
        files: [ 'assets/**', '**/*.html', '**/*.md', '!node_modules/**', '!bower_components/**', '!_site/**', '!assets/**/*.scss' ],
      },
    },

  });

  // Load plugins
  grunt.loadNpmTasks('grunt-contrib-sass');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-jekyll');
  grunt.loadNpmTasks('grunt-contrib-connect');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Default task(s).
  grunt.registerTask('default', [ 'connect', 'watch' ]);

};
