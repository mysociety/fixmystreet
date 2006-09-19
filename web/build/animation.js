/*
Copyright (c) 2006 Yahoo! Inc. All rights reserved.
version 0.9.0
*/

/**
 *
 * Base class for animated DOM objects.
 * @class Base animation class that provides the interface for building animated effects.
 * <p>Usage: var myAnim = new YAHOO.util.Anim(el, { width: { from: 10, to: 100 } }, 1, YAHOO.util.Easing.easeOut);</p>
 * @requires YAHOO.util.AnimMgr
 * @requires YAHOO.util.Easing
 * @requires YAHOO.util.Dom
 * @requires YAHOO.util.Event
 * @constructor
 * @param {HTMLElement | String} el Reference to the element that will be animated
 * @param {Object} attributes The attribute(s) to be animated.
 * Each attribute is an object with at minimum a "to" or "by" member defined.
 * Additional optional members are "from" (defaults to current value), "units" (defaults to "px").
 * All attribute names use camelCase.
 * @param {Number} duration (optional, defaults to 1 second) Length of animation (frames or seconds), defaults to time-based
 * @param {Function} method (optional, defaults to YAHOO.util.Easing.easeNone) Computes the values that are applied to the attributes per frame (generally a YAHOO.util.Easing method)
 */

YAHOO.util.Anim = function(el, attributes, duration, method)
{
   if (el) {
      this.init(el, attributes, duration, method);
   }
};

YAHOO.util.Anim.prototype = {
   /**
    * Returns the value computed by the animation's "method".
    * @param {String} attribute The name of the attribute.
    * @param {Number} start The value this attribute should start from for this animation.
    * @param {Number} end  The value this attribute should end at for this animation.
    * @return {Number} The Value to be applied to the attribute.
    */
   doMethod: function(attribute, start, end) {
      return this.method(this.currentFrame, start, end - start, this.totalFrames);
   },

   /**
    * Applies a value to an attribute
    * @param {String} attribute The name of the attribute.
    * @param {Number} val The value to be applied to the attribute.
    * @param {String} unit The unit ('px', '%', etc.) of the value.
    */
   setAttribute: function(attribute, val, unit) {
      YAHOO.util.Dom.setStyle(this.getEl(), attribute, val + unit);
   },

   /**
    * Returns current value of the attribute.
    * @param {String} attribute The name of the attribute.
    * @return {Number} val The current value of the attribute.
    */
   getAttribute: function(attribute) {
      return parseFloat( YAHOO.util.Dom.getStyle(this.getEl(), attribute));
   },

   /**
    * Per attribute units that should be used by default.
    * @type {Object}
    */
   defaultUnits: {
      opacity: ' '
   },

   /**
    * The default unit to use for all attributes if not defined per attribute.
    * @type {String}
    */
   defaultUnit: 'px',

   /**
    * @param {HTMLElement | String} el Reference to the element that will be animated
    * @param {Object} attributes The attribute(s) to be animated.
    * Each attribute is an object with at minimum a "to" or "by" member defined.
    * Additional optional members are "from" (defaults to current value), "units" (defaults to "px").
    * All attribute names use camelCase.
    * @param {Number} duration (optional, defaults to 1 second) Length of animation (frames or seconds), defaults to time-based
    * @param {Function} method (optional, defaults to YAHOO.util.Easing.easeNone) Computes the values that are applied to the attributes per frame (generally a YAHOO.util.Easing method)
    */
   init: function(el, attributes, duration, method) {

      /**
       * Whether or not the animation is running.
       * @private
       * @type {Boolen}
       */
      var isAnimated = false;

      /**
       * A Date object that is created when the animation begins.
       * @private
       * @type {Date}
       */
      var startTime = null;

      /**
       * A Date object that is created when the animation ends.
       * @private
       * @type {Date}
       */
      var endTime = null;

      /**
       * The number of frames this animation was able to execute.
       * @private
       * @type {Int}
       */
      var actualFrames = 0;

      /**
       * The attribute values that will be used if no "from" is supplied.
       * @private
       * @type {Object}
       */
      var defaultValues = {};

      /**
       * The element to be animated.
       * @private
       * @type {HTMLElement}
       */
      el = YAHOO.util.Dom.get(el);

      /**
       * The collection of attributes to be animated.
       * Each attribute must have at least a "to" or "by" defined in order to animate.
       * If "to" is supplied, the animation will end with the attribute at that value.
       * If "by" is supplied, the animation will end at that value plus its starting value.
       * If both are supplied, "to" is used, and "by" is ignored.
       * Optional additional member include "from" (the value the attribute should start animating from, defaults to current value), and "unit" (the units to apply to the values).
       * @type {Object}
       */
      this.attributes = attributes || {};

      /**
       * The length of the animation.  Defaults to "1" (second).
       * @type {Number}
       */
      this.duration = duration || 1;

      /**
       * The method that will provide values to the attribute(s) during the animation.
       * Defaults to "YAHOO.util.Easing.easeNone".
       * @type {Function}
       */
      this.method = method || YAHOO.util.Easing.easeNone;

      /**
       * Whether or not the duration should be treated as seconds.
       * Defaults to true.
       * @type {Boolean}
       */
      this.useSeconds = true; // default to seconds

      /**
       * The location of the current animation on the timeline.
       * In time-based animations, this is used by AnimMgr to ensure the animation finishes on time.
       * @type {Int}
       */
      this.currentFrame = 0;

      /**
       * The total number of frames to be executed.
       * In time-based animations, this is used by AnimMgr to ensure the animation finishes on time.
       * @type {Int}
       */
      this.totalFrames = YAHOO.util.AnimMgr.fps;


      /**
       * Returns a reference to the animated element.
       * @return {HTMLElement}
       */
      this.getEl = function() { return el; };


      /**
       * Sets the default value to be used when "from" is not supplied.
       * @param {String} attribute The attribute being set.
       * @param {Number} val The default value to be applied to the attribute.
       */
      this.setDefault = function(attribute, val) {
         if ( val == 'auto' ) { // if 'auto' set defaults for well known attributes, zero for others
            switch(attribute) {
               case'width':
                  val = el.clientWidth || el.offsetWidth; // computed width
                  break;
               case 'height':
                  val = el.clientHeight || el.offsetHeight; // computed height
                  break;
               case 'left':
                  if (YAHOO.util.Dom.getStyle(el, 'position') == 'absolute') {
                     val = el.offsetLeft; // computed left
                  } else {
                     val = 0;
                  }
                  break;
               case 'top':
                  if (YAHOO.util.Dom.getStyle(el, 'position') == 'absolute') {
                     val = el.offsetTop; // computed top
                  } else {
                     val = 0;
                  }
                  break;
               default:
                  val = 0;
            }
         }

         defaultValues[attribute] = val;
      }

      /**
       * Returns the default value for the given attribute.
       * @param {String} attribute The attribute whose value will be returned.
       */
      this.getDefault = function(attribute) {
         return defaultValues[attribute];
      };

      /**
       * Checks whether the element is currently animated.
       * @return {Boolean} current value of isAnimated.
       */
      this.isAnimated = function() {
         return isAnimated;
      };

      /**
       * Returns the animation start time.
       * @return {Date} current value of startTime.
       */
      this.getStartTime = function() {
         return startTime;
      };

      /**
       * Starts the animation by registering it with the animation manager.
       */
      this.animate = function() {
         this.onStart.fire();
         this._onStart.fire();

         this.totalFrames = ( this.useSeconds ) ? Math.ceil(YAHOO.util.AnimMgr.fps * this.duration) : this.duration;
         YAHOO.util.AnimMgr.registerElement(this);

         // get starting values or use defaults
         var attributes = this.attributes;
         var el = this.getEl();
         var val;

         for (var attribute in attributes) {
            val = this.getAttribute(attribute);
            this.setDefault(attribute, val);
         }

         isAnimated = true;
         actualFrames = 0;
         startTime = new Date();
      };

      /**
       * Stops the animation.  Normally called by AnimMgr when animation completes.
       */
      this.stop = function() {
         this.currentFrame = 0;

         endTime = new Date();

         var data = {
            time: endTime,
            duration: endTime - startTime,
            frames: actualFrames,
            fps: actualFrames / this.duration
         };

         isAnimated = false;
         actualFrames = 0;

         this.onComplete.fire(data);
      };

      /**
       * Feeds the starting and ending values for each animated attribute to doMethod once per frame, then applies the resulting value to the attribute(s).
       * @private
       */
      var onTween = function() {
         var start;
         var end = null;
         var val;
         var unit;
         var attributes = this['attributes'];

         for (var attribute in attributes) {
            unit = attributes[attribute]['unit'] || this.defaultUnits[attribute] || this.defaultUnit;

            if (typeof attributes[attribute]['from'] != 'undefined') {
               start = attributes[attribute]['from'];
            } else {
               start = this.getDefault(attribute);
            }

            // To beats by, per SMIL 2.1 spec
            if (typeof attributes[attribute]['to'] != 'undefined') {
               end = attributes[attribute]['to'];
            } else if (typeof attributes[attribute]['by'] != 'undefined') {
               end = start + attributes[attribute]['by'];
            }

            // if end is null, dont change value
            if (end !== null && typeof end != 'undefined') {

               val = this.doMethod(attribute, start, end);

               // negative not allowed for these (others too, but these are most common)
               if ( (attribute == 'width' || attribute == 'height' || attribute == 'opacity') && val < 0 ) {
                  val = 0;
               }

               this.setAttribute(attribute, val, unit);
            }
         }

         actualFrames += 1;
      };

      /**
       * Custom event that fires after onStart, useful in subclassing
       * @private
       */
      this._onStart = new YAHOO.util.CustomEvent('_onStart', this);

      /**
       * Custom event that fires when animation begins
       * Listen via subscribe method
       */
      this.onStart = new YAHOO.util.CustomEvent('start', this);

      /**
       * Custom event that fires between each frame
       * Listen via subscribe method
       */
      this.onTween = new YAHOO.util.CustomEvent('tween', this);

      /**
       * Custom event that fires after onTween
       * @private
       */
      this._onTween = new YAHOO.util.CustomEvent('_tween', this);

      /**
       * Custom event that fires when animation ends
       * Listen via subscribe method
       */
      this.onComplete = new YAHOO.util.CustomEvent('complete', this);

      this._onTween.subscribe(onTween);
   }
};

/**
 * @class Handles animation queueing and threading.
 * Used by Anim and subclasses.
 */
YAHOO.util.AnimMgr = new function() {
   /**
    * Reference to the animation Interval
    * @private
    * @type Int
    */
   var thread = null;

   /**
    * The current queue of registered animation objects.
    * @private
    * @type Array
    */
   var queue = [];

   /**
    * The number of active animations.
    * @private
    * @type Int
    */
   var tweenCount = 0;

   /**
    * Base frame rate (frames per second).
    * Arbitrarily high for better x-browser calibration (slower browsers drop more frames).
    * @type Int
    *
    */
   this.fps = 200;

   /**
    * Interval delay in milliseconds, defaults to fastest possible.
    * @type Int
    *
    */
   this.delay = 1;

   /**
    * Adds an animation instance to the animation queue.
    * All animation instances must be registered in order to animate.
    * @param {object} tween The Anim instance to be be registered
    */
   this.registerElement = function(tween) {
      if ( tween.isAnimated() ) { return false; }// but not if already animating

      queue[queue.length] = tween;
      tweenCount += 1;

      this.start();
   };

   /**
    * Starts the animation thread.
	 * Only one thread can run at a time.
    */
   this.start = function() {
      if (thread === null) { thread = setInterval(this.run, this.delay); }
   };

   /**
    * Stops the animation thread or a specific animation instance.
    * @param {object} tween A specific Anim instance to stop (optional)
    * If no instance given, Manager stops thread and all animations.
    */
   this.stop = function(tween) {
      if (!tween)
      {
         clearInterval(thread);
         for (var i = 0, len = queue.length; i < len; ++i) {
            if (queue[i].isAnimated()) {
               queue[i].stop();
            }
         }
         queue = [];
         thread = null;
         tweenCount = 0;
      }
      else {
         tween.stop();
         tweenCount -= 1;

         if (tweenCount <= 0) { this.stop(); }
      }
   };

   /**
    * Called per Interval to handle each animation frame.
    */
   this.run = function() {
      for (var i = 0, len = queue.length; i < len; ++i) {
         var tween = queue[i];
         if ( !tween || !tween.isAnimated() ) { continue; }

         if (tween.currentFrame < tween.totalFrames || tween.totalFrames === null)
         {
            tween.currentFrame += 1;

            if (tween.useSeconds) {
               correctFrame(tween);
            }

            tween.onTween.fire();
            tween._onTween.fire();
         }
         else { YAHOO.util.AnimMgr.stop(tween); }
      }
   };

   /**
    * On the fly frame correction to keep animation on time.
    * @private
    * @param {Object} tween The Anim instance being corrected.
    */
   var correctFrame = function(tween) {
      var frames = tween.totalFrames;
      var frame = tween.currentFrame;
      var expected = (tween.currentFrame * tween.duration * 1000 / tween.totalFrames);
      var elapsed = (new Date() - tween.getStartTime());
      var tweak = 0;

      if (elapsed < tween.duration * 1000) { // check if falling behind
         tweak = Math.round((elapsed / expected - 1) * tween.currentFrame);
      } else { // went over duration, so jump to end
         tweak = frames - (frame + 1);
      }
      if (tweak > 0 && isFinite(tweak)) { // adjust if needed
         if (tween.currentFrame + tweak >= frames) {// dont go past last frame
            tweak = frames - (frame + 1);
         }

         tween.currentFrame += tweak;
      }
   };
}

/**
 *
 * @class Used to calculate Bezier splines for any number of control points.
 *
 */
YAHOO.util.Bezier = new function()
{
   /**
    * Get the current position of the animated element based on t.
    * @param {array} points An array containing Bezier points.
    * Each point is an array of "x" and "y" values (0 = x, 1 = y)
    * At least 2 points are required (start and end).
    * First point is start. Last point is end.
    * Additional control points are optional.
    * @param {float} t Basis for determining current position (0 < t < 1)
    * @return {object} An object containing int x and y member data
    */
   this.getPosition = function(points, t)
   {
      var n = points.length;
      var tmp = [];

      for (var i = 0; i < n; ++i){
         tmp[i] = [points[i][0], points[i][1]]; // save input
      }

      for (var j = 1; j < n; ++j) {
         for (i = 0; i < n - j; ++i) {
            tmp[i][0] = (1 - t) * tmp[i][0] + t * tmp[parseInt(i + 1, 10)][0];
            tmp[i][1] = (1 - t) * tmp[i][1] + t * tmp[parseInt(i + 1, 10)][1];
         }
      }

      return [ tmp[0][0], tmp[0][1] ];

   };
};

/**
 * @class Class for defining the acceleration rate and path of animations.
 */
YAHOO.util.Easing = new function() {

   /**
    * Uniform speed between points.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.easeNone = function(t, b, c, d) {
	return b+c*(t/=d);
   };

   /**
    * Begins slowly and accelerates towards end.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.easeIn = function(t, b, c, d) {
   	return b+c*((t/=d)*t*t);
   };

   /**
    * Begins quickly and decelerates towards end.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.easeOut = function(t, b, c, d) {
   	var ts=(t/=d)*t;
   	var tc=ts*t;
   	return b+c*(tc + -3*ts + 3*t);
   };

   /**
    * Begins slowly and decelerates towards end.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.easeBoth = function(t, b, c, d) {
   	var ts=(t/=d)*t;
   	var tc=ts*t;
   	return b+c*(-2*tc + 3*ts);
   };

   /**
    * Begins by going below staring value.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.backIn = function(t, b, c, d) {
   	var ts=(t/=d)*t;
   	var tc=ts*t;
   	return b+c*(-3.4005*tc*ts + 10.2*ts*ts + -6.2*tc + 0.4*ts);
   };

   /**
    * End by going beyond ending value.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.backOut = function(t, b, c, d) {
   	var ts=(t/=d)*t;
   	var tc=ts*t;
   	return b+c*(8.292*tc*ts + -21.88*ts*ts + 22.08*tc + -12.69*ts + 5.1975*t);
   };

   /**
    * Starts by going below staring value, and ends by going beyond ending value.
    * @param {Number} t Time value used to compute current value.
    * @param {Number} b Starting value.
    * @param {Number} c Delta between start and end values.
    * @param {Number} d Total length of animation.
    * @return {Number} The computed value for the current animation frame.
    */
   this.backBoth = function(t, b, c, d) {
   	var ts=(t/=d)*t;
   	var tc=ts*t;
   	return b+c*(0.402*tc*ts + -2.1525*ts*ts + -3.2*tc + 8*ts + -2.05*t);
   };
};

/**
 * @class Anim subclass for moving elements along a path defined by the "points" member of "attributes".  All "points" are arrays with x, y coordinates.
 * <p>Usage: <code>var myAnim = new YAHOO.util.Motion(el, { points: { to: [800, 800] } }, 1, YAHOO.util.Easing.easeOut);</code></p>
 * @requires YAHOO.util.Anim
 * @requires YAHOO.util.AnimMgr
 * @requires YAHOO.util.Easing
 * @requires YAHOO.util.Bezier
 * @requires YAHOO.util.Dom
 * @requires YAHOO.util.Event
 * @constructor
 * @param {HTMLElement | String} el Reference to the element that will be animated
 * @param {Object} attributes The attribute(s) to be animated.
 * Each attribute is an object with at minimum a "to" or "by" member defined.
 * Additional optional members are "from" (defaults to current value), "units" (defaults to "px").
 * All attribute names use camelCase.
 * @param {Number} duration (optional, defaults to 1 second) Length of animation (frames or seconds), defaults to time-based
 * @param {Function} method (optional, defaults to YAHOO.util.Easing.easeNone) Computes the values that are applied to the attributes per frame (generally a YAHOO.util.Easing method)
 */
YAHOO.util.Motion = function(el, attributes, duration, method) {
   if (el) {
      this.initMotion(el, attributes, duration, method);
   }
};

YAHOO.util.Motion.prototype = new YAHOO.util.Anim();

/**
 * Per attribute units that should be used by default.
 * Motion points default to 'px' units.
 * @type Object
 */
YAHOO.util.Motion.prototype.defaultUnits.points = 'px';

/**
 * Returns the value computed by the animation's "method".
 * @param {String} attribute The name of the attribute.
 * @param {Number} start The value this attribute should start from for this animation.
 * @param {Number} end  The value this attribute should end at for this animation.
 * @return {Number} The Value to be applied to the attribute.
 */
YAHOO.util.Motion.prototype.doMethod = function(attribute, start, end) {
   var val = null;

   if (attribute == 'points') {
      var translatedPoints = this.getTranslatedPoints();
      var t = this.method(this.currentFrame, 0, 100, this.totalFrames) / 100;

      if (translatedPoints) {
         val = YAHOO.util.Bezier.getPosition(translatedPoints, t);
      }

   } else {
      val = this.method(this.currentFrame, start, end - start, this.totalFrames);
   }

   return val;
};

/**
 * Returns current value of the attribute.
 * @param {String} attribute The name of the attribute.
 * @return {Number} val The current value of the attribute.
 */
YAHOO.util.Motion.prototype.getAttribute = function(attribute) {
   var val = null;

   if (attribute == 'points') {
      val = [ this.getAttribute('left'), this.getAttribute('top') ];
      if ( isNaN(val[0]) ) { val[0] = 0; }
      if ( isNaN(val[1]) ) { val[1] = 0; }
   } else {
      val = parseFloat( YAHOO.util.Dom.getStyle(this.getEl(), attribute) );
   }

   return val;
};

/**
 * Applies a value to an attribute
 * @param {String} attribute The name of the attribute.
 * @param {Number} val The value to be applied to the attribute.
 * @param {String} unit The unit ('px', '%', etc.) of the value.
 */
YAHOO.util.Motion.prototype.setAttribute = function(attribute, val, unit) {
   if (attribute == 'points') {
      YAHOO.util.Dom.setStyle(this.getEl(), 'left', val[0] + unit);
      YAHOO.util.Dom.setStyle(this.getEl(), 'top', val[1] + unit);
   } else {
      YAHOO.util.Dom.setStyle(this.getEl(), attribute, val + unit);
   }
};

/**
 * @param {HTMLElement | String} el Reference to the element that will be animated
 * @param {Object} attributes The attribute(s) to be animated.
 * Each attribute is an object with at minimum a "to" or "by" member defined.
 * Additional optional members are "from" (defaults to current value), "units" (defaults to "px").
 * All attribute names use camelCase.
 * @param {Number} duration (optional, defaults to 1 second) Length of animation (frames or seconds), defaults to time-based
 * @param {Function} method (optional, defaults to YAHOO.util.Easing.easeNone) Computes the values that are applied to the attributes per frame (generally a YAHOO.util.Easing method)
 */
YAHOO.util.Motion.prototype.initMotion = function(el, attributes, duration, method) {
   YAHOO.util.Anim.call(this, el, attributes, duration, method);

   attributes = attributes || {};
   attributes.points = attributes.points || {};
   attributes.points.control = attributes.points.control || [];

   this.attributes = attributes;

   var start;
   var end = null;
   var translatedPoints = null;

   this.getTranslatedPoints = function() { return translatedPoints; };

   var translateValues = function(val, self) {
      var pageXY = YAHOO.util.Dom.getXY(self.getEl());
      val = [ val[0] - pageXY[0] + start[0], val[1] - pageXY[1] + start[1] ];

      return val;
   };

   var onStart = function() {
      start = this.getAttribute('points');
      var attributes = this.attributes;
      var control =  attributes['points']['control'] || [];

      if (control.length > 0 && control[0].constructor != Array) { // could be single point or array of points
         control = [control];
      }

      if (YAHOO.util.Dom.getStyle(this.getEl(), 'position') == 'static') { // default to relative
         YAHOO.util.Dom.setStyle(this.getEl(), 'position', 'relative');
      }

      if (typeof attributes['points']['from'] != 'undefined') {
         YAHOO.util.Dom.setXY(this.getEl(), attributes['points']['from']); // set to from point
         start = this.getAttribute('points'); // get actual offset values
      }
      else if ((start[0] === 0 || start[1] === 0)) { // these sometimes up when auto
         YAHOO.util.Dom.setXY(this.getEl(), YAHOO.util.Dom.getXY(this.getEl())); // set it to current position, giving offsets
         start = this.getAttribute('points'); // get actual offset values
      }

      var i, len;
      // TO beats BY, per SMIL 2.1 spec
      if (typeof attributes['points']['to'] != 'undefined') {
         end = translateValues(attributes['points']['to'], this);

         for (i = 0, len = control.length; i < len; ++i) {
            control[i] = translateValues(control[i], this);
         }

      } else if (typeof attributes['points']['by'] != 'undefined') {
         end = [ start[0] + attributes['points']['by'][0], start[1] + attributes['points']['by'][1]];

         for (i = 0, len = control.length; i < len; ++i) {
            control[i] = [ start[0] + control[i][0], start[1] + control[i][1] ];
         }
      }

      if (end) {
         translatedPoints = [start];

         if (control.length > 0) { translatedPoints = translatedPoints.concat(control); }

         translatedPoints[translatedPoints.length] = end;
      }
   };

   this._onStart.subscribe(onStart);
};

/**
 * @class Anim subclass for scrolling elements to a position defined by the "scroll" member of "attributes".  All "scroll" members are arrays with x, y scroll positions.
 * <p>Usage: <code>var myAnim = new YAHOO.util.Scroll(el, { scroll: { to: [0, 800] } }, 1, YAHOO.util.Easing.easeOut);</code></p>
 * @requires YAHOO.util.Anim
 * @requires YAHOO.util.AnimMgr
 * @requires YAHOO.util.Easing
 * @requires YAHOO.util.Bezier
 * @requires YAHOO.util.Dom
 * @requires YAHOO.util.Event
 * @constructor
 * @param {HTMLElement | String} el Reference to the element that will be animated
 * @param {Object} attributes The attribute(s) to be animated.
 * Each attribute is an object with at minimum a "to" or "by" member defined.
 * Additional optional members are "from" (defaults to current value), "units" (defaults to "px").
 * All attribute names use camelCase.
 * @param {Number} duration (optional, defaults to 1 second) Length of animation (frames or seconds), defaults to time-based
 * @param {Function} method (optional, defaults to YAHOO.util.Easing.easeNone) Computes the values that are applied to the attributes per frame (generally a YAHOO.util.Easing method)
 */
YAHOO.util.Scroll = function(el, attributes, duration,  method) {
   if (el) {
      YAHOO.util.Anim.call(this, el, attributes, duration, method);
   }
};

YAHOO.util.Scroll.prototype = new YAHOO.util.Anim();

/**
 * Per attribute units that should be used by default.
 * Scroll positions default to no units.
 * @type Object
 */
YAHOO.util.Scroll.prototype.defaultUnits.scroll = ' ';

/**
 * Returns the value computed by the animation's "method".
 * @param {String} attribute The name of the attribute.
 * @param {Number} start The value this attribute should start from for this animation.
 * @param {Number} end  The value this attribute should end at for this animation.
 * @return {Number} The Value to be applied to the attribute.
 */
YAHOO.util.Scroll.prototype.doMethod = function(attribute, start, end) {
   var val = null;

   if (attribute == 'scroll') {
      val = [
         this.method(this.currentFrame, start[0], end[0] - start[0], this.totalFrames),
         this.method(this.currentFrame, start[1], end[1] - start[1], this.totalFrames)
      ];

   } else {
      val = this.method(this.currentFrame, start, end - start, this.totalFrames);
   }
   return val;
}

/**
 * Returns current value of the attribute.
 * @param {String} attribute The name of the attribute.
 * @return {Number} val The current value of the attribute.
 */
YAHOO.util.Scroll.prototype.getAttribute = function(attribute) {
   var val = null;
   var el = this.getEl();

   if (attribute == 'scroll') {
      val = [ el.scrollLeft, el.scrollTop ];
   } else {
      val = parseFloat( YAHOO.util.Dom.getStyle(el, attribute) );
   }

   return val;
};

/**
 * Applies a value to an attribute
 * @param {String} attribute The name of the attribute.
 * @param {Number} val The value to be applied to the attribute.
 * @param {String} unit The unit ('px', '%', etc.) of the value.
 */
YAHOO.util.Scroll.prototype.setAttribute = function(attribute, val, unit) {
   var el = this.getEl();

   if (attribute == 'scroll') {
      el.scrollLeft = val[0];
      el.scrollTop = val[1];
   } else {
      YAHOO.util.Dom.setStyle(el, attribute, val + unit);
   }
};

