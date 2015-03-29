'use strict'

{ create, diff, patch, VNode, VText } = require('virtual-dom')
fromHTML = require('html-to-vdom')(VNode: VNode, VText: VText)
toHTML = require('vdom-to-html')
isVNode = require('virtual-dom/vnode/is-vnode')
isVText = require('virtual-dom/vnode/is-vtext')
isThunk = require('virtual-dom/vnode/is-thunk')
Delegator = require("dom-delegator")
EventEmitter = require("events").EventEmitter
$v = require('vdom-query')
bonzo = require('bonzo')
ccss = require('ccss')
raf = require 'raf'
teacup = require 'teacup'
_ = require('lodash')
_.mixin(require('underscore.string').exports())
_.is = require('is')
deepExtend = require('deep-extend')

_toRedraw = []

$ = (selector) ->
  if _.isString(selector)
    if _.startsWith(selector, '<')
      bonzo.create(selector)
    else
      bonzo(document.querySelector(selector))
  else
    bonzo(selector)

raf _redrawAll = ->
  if _toRedraw.length
    for r in _toRedraw
      r.redraw()
    _toRedraw = []
  raf(_redrawAll)

module.exports.teacup = teacup

for k, v of teacup
  module.exports[k] = v

module.exports.hazel = (name, opts) ->
    proto = Object.create(HTMLElement.prototype)
    _name = _.dasherize(name).toLowerCase()

    proto.createdCallback = ->
      root = @createShadowRoot()

      @_style = if opts.style? then _.clone(opts.style) else {}
      @_data = if opts.data? then _.clone(opts.data) else {}
      @_methods = if opts.methods? then opts.methods else {}
      @_vdom = null
      @_vdom_style = null

      proto.created = if opts.created? then opts.created else =>
        console.log "created", @

      proto.destroyed = if opts.destroyed? then opts.destroyed else =>
        console.log "destroyed", @

      proto.attached = if opts.attached? then opts.attached else =>
        console.log "attached", @

      proto.detached = if opts.detached? then opts.detached else =>
        console.log "detached", @

      @_template = if opts.template? then opts.template else teacup.renderable =>
        teacup.span "component #{@tagName}"

      if opts.extends?
        el = document.createElement(_.dasherize(opts.extends).toLowerCase())
        if el._style?
          @_style = deepExtend({}, el._style, @_style)
        if el._data?
          @_data = _.extend({}, el._data, @_data)
        if el._template?
          @_contentTemplate = @_template
          @_template = el._template
        if el._methods?
          @_methods = _.extend({}, el._methods, @_methods)

      for k, v of @_methods
        proto[k] = v

      @created()


    proto.attachedCallback = ->
      @_dom()

      if @_el_style?
        @shadowRoot.appendChild(@_el_style)
      if @_el?
        @shadowRoot.appendChild(@_el)

      @refresh()

      @attached()


    proto.detachedCallback = ->
      @detached()


    proto.attributeChangedCallback = ->


    proto._dom = ->
      s = @_template(@, @_contentTemplate)
      if _.isEmpty(s)
        s = '<div></div>'

      st = '<style>' + ccss.compile(@_style) + '</style>'
      vs = fromHTML(st)
      if vs?
        if !@_vdom_style?
          @_el_style = create(vs)
        else
          patches = diff(@_vdom_style, vs);
          @_el_style = patch(@_el_style, patches);
      @_vdom_style = vs;

      v = fromHTML("#{s}")
      if v?
        if !@_vdom?
          @_el = create(v)
          # @__createIds()
        else
          patches = diff(@_vdom, v);
          @_el = patch(@_el, patches);
      @_vdom = v;


    proto.redraw = ->
      @_dom()
      console.log "redraw", @


    proto.needsRedraw = ->
      return _.contains(_toRedraw, @)


    proto.refresh = ->
      console.log "refresh", @
      if !_.contains(_toRedraw, @)
        _toRedraw.push(@)


    # teacup[_.classify(_name)] = (args...) -> @tag _.classify(_name), args...

    return document.registerElement(_name, prototype: proto)
