module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),

    concat: {
      library: {
        options: {
          separator: ';'
        },
        src: [
          'bower_components/jquery/jquery.js',
          'bower_components/jquery/jquery-migrate.js',
          'bower_components/owlcarousel/owl-carousel/owl.carousel.js'
        ],
        dest: 'assets/scripts/lib.js'
      }

    },

    uglify: {
      library: {
        options: {
          banner: '/*! <%= pkg.name %> library - v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %> */\n'
        },
        files: {
          'assets/scripts/lib.min.js': 'assets/scripts/lib.js'
        }
      },

      main: {
        options: {
          banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %> */\n'
        },
        files: {
          'assets/scripts/app.min.js': 'assets/scripts/app.js'
        }
      },

    },

    watch: {
      files: [
        'assets/scripts/utils.js',
        'assets/scripts/api.js',
        'assets/scripts/app.js'
      ],
      tasks: ['concat','uglify'],
    },
  });

  // Load plugins
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Default task(s).
  grunt.registerTask('default', ['concat','uglify']);

};
