module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),

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
          'assets/css/global.min.css': 'assets/sass/global.scss'
        }
      }
    },

    watch: {
      css: {
        files: [
          'assets/**/*.scss',
        ],
        tasks: [ 'sass' ],
      },
      js: {
        files: [
          'assets/scripts/app.js'
        ],
        tasks: [ 'uglify' ],
      },
    },
  });

  // Load plugins
  grunt.loadNpmTasks('grunt-contrib-sass');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Default task(s).
  grunt.registerTask('default', [ 'uglify', 'sass' ]);

};
