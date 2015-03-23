'use strict';
var $, $v, Component, Delegator, EventEmitter, VNode, VText, _is, create, diff, isThunk, isVNode, isVText, patch, ref, toHTML, virtualize,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

ref = require('virtual-dom'), create = ref.create, diff = ref.diff, patch = ref.patch, VNode = ref.VNode, VText = ref.VText;

virtualize = require('vdom-virtualize').virtualize;

toHTML = require('vdom-to-html');

isVNode = require('virtual-dom/vnode/is-vnode');

isVText = require('virtual-dom/vnode/is-vtext');

isThunk = require('virtual-dom/vnode/is-thunk');

Delegator = require("dom-delegator");

EventEmitter = require("events").EventEmitter;

$v = require('vdom-query');

$ = require('bonzo');

_is = require('is');

module.exports = {
  HazelComponent: Component = (function() {
    Component.vdom = null;

    Component.el = null;

    Component.data = {};

    Component._needRefresh = false;

    function Component(el) {
      this.detached = bind(this.detached, this);
      this.attached = bind(this.attached, this);
      this.updated = bind(this.updated, this);
      this.destroyed = bind(this.destroyed, this);
      this.created = bind(this.created, this);
      this.render = bind(this.render, this);
      this.attachTo(el);
      this.created();
    }

    Component.prototype.attachTo = function(el) {
      if (el != null) {
        if (_is.string(el)) {
          el = $(el);
        } else if (_is.element(el)) {
          el = el;
        }
      }
      if (el == null) {
        el = document.createElement('div');
      }
      return this.el = el;
    };

    Component.prototype.redraw = function() {
      var patches, v;
      if (this._needRefresh) {
        v = this.render();
        if (_is.string(v)) {
          v = virtualize.fromHTML(v);
        } else if (!isVNode(v)) {
          v = null;
        }
        if ((v != null) && (this.vdom != null)) {
          patches = diff(this.vdom, v);
          this.el = patch(this.el, patches);
          this.vdom = v;
        }
        return this._needRefresh = false;
      }
    };

    Component.prototype.refresh = function() {
      return this.needRefresh = true;
    };

    Component.prototype.render = function() {
      return null;
    };

    Component.prototype.created = function() {};

    Component.prototype.destroyed = function() {};

    Component.prototype.updated = function() {};

    Component.prototype.attached = function() {};

    Component.prototype.detached = function() {};

    return Component;

  })()
};
