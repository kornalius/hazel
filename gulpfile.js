'use strict';

var config = {
  production: false
};

var gulp        = require('gulp');
var run         = require('gulp-load-plugins')();
var del         = require('del');

var out         = 'dist/';

var _out = '!' + out + '**/*';
var _bower = '!bower_components/**/*';
var _node = '!node_modules/**/*';

gulp.task('clean', function (cb) {
  del([out], cb);
});

gulp.task('scripts', function () {
  return gulp.src(['**/*.coffee', _out, _bower, _node])
    .pipe(run.plumber({errorHandler: run.notify.onError('Error: <%= error.message %>')}))
    .pipe(run.if(config.production, run.sourcemaps.init()))
    .pipe(run.coffee({ bare: true }))
    .pipe(run.concat(config.production ? 'hazel.min.js' : 'hazel.js'))
    .pipe(run.if(config.production, run.uglify({ mangle: true })))
    .pipe(run.if(config.production, run.sourcemaps.write()))
    .pipe(gulp.dest(out));
});

gulp.task('notify', function () {
  return gulp.src('')
    .pipe(run.notify({
      title: 'Finished',
      message: 'Build finished!',
      sound: false,
      icon: false,
      onLast: true
    }));
});

gulp.task('set:production', function () {
  config.production = true;
});

gulp.task('build', function (cb) {
  run.sequence('scripts', 'notify')(cb);
});

gulp.task('prod', function (cb) {
  run.sequence('set:production', 'clean', 'build')(cb);
});

gulp.task('dev', function (cb) {
  run.sequence('clean', 'build')(cb);
});

gulp.task('default', ['dev']);
