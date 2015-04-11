'use strict'

{ create, diff, patch, VNode, VText } = require('virtual-dom')
fromHTML = require('html-to-vdom')(VNode: VNode, VText: VText)
toHTML = require('vdom-to-html')
isVNode = require('virtual-dom/vnode/is-vnode')
isVText = require('virtual-dom/vnode/is-vtext')
isThunk = require('virtual-dom/vnode/is-thunk')
bean = require('bean')
$v = require('vdom-query')
ccss = require('ccss')
raf = require('raf')
teacup = require('teacup')
{ PathObserver, ArrayObserver, ObjectObserver, hasObjectObserve, CompoundObserver, Path, ObserverTransform } = require('observe-js')
$ = require('cash-dom')

_ = require('underscore-plus')
_.is = require('is')


_observers = []
_toRedraw = []
raf _redrawAll = ->

  for o in _observers
    o.deliver()

  if _toRedraw.length
    for r in _toRedraw
      r.redraw()
    _toRedraw = []

  raf(_redrawAll)


module.exports.$ = $

$.fn.on = bean.on.bind(bean)
$.fn.on = bean.on.bind(bean)
$.fn.off = bean.off.bind(bean)
$.fn.on = bean.on.bind(bean)

$.fn.on = (eventType, selector, handler, args...) ->
  @each((el) -> bean.on(el, eventType, selector, handler, args...))

$.fn.one = (eventType, selector, handler, args...) ->
  @each((el) -> bean.one(el, eventType, selector, handler, args...))

$.fn.off = (eventType, handler) ->
  @each((el) -> bean.off(el, eventType, handler))

$.fn.fire = (eventType, args...) ->
  @each((el) -> bean.fire(el, eventType, args...))

$.fn.eachDeep = (f) ->
  @each((el) ->
    f(el)
    if el.shadowRoot?
      $(el.shadowRoot).eachDeep(f)
    cn = el.childNodes
    for i in [0...cn.length]
      $(cn[i]).eachDeep(f) if cn[i].nodeType != 3
  )


module.exports.vdom =
  $: $v
  create: create
  diff: diff
  patch: patch
  VNode: VNode
  VText: VText
  fromHTML: fromHTML
  toHTML: toHTML
  isVNode: isVNode
  isVText: isVText
  isThunk: isThunk
module.exports.raf = raf
module.exports.ccss = ccss

module.exports.teacup = teacup
for k, v of teacup
  module.exports[k] = v

for k, v of require('observe-js')
  module.exports[k] = v


module.exports.hazel = (name, opts) ->
    proto = Object.create(HTMLElement.prototype)
    _name = _.dasherize(name).toLowerCase()

    proto.createdCallback = ->
      root = @createShadowRoot()

      @_style = if opts.style? then _.clone(opts.style) else {}
      @_data = if opts.data? then _.clone(opts.data) else {}
      @_methods = if opts.methods? then opts.methods else {}
      @_events = if opts.events? then opts.events else {}
      @_vdom = null
      @_vdom_style = null
      @_observers = []

      @data = (name, value) ->
        if arguments.length == 0
          @_data
        else if arguments.length > 1
          _.setValueForKeyPath(@_data, name, value)
        _.valueForKeyPath(@_data, name)

      proto.created = if opts.created? then opts.created else =>
        # console.log "created", @

      proto.destroyed = if opts.destroyed? then opts.destroyed else =>
        # console.log "destroyed", @

      proto.attached = if opts.attached? then opts.attached else (el) =>
        # console.log "attached", @

      proto.detached = if opts.detached? then opts.detached else =>
        # console.log "detached", @

      proto.updated = if opts.updated? then opts.updated else =>
        # console.log "updated", @

      @_template = if opts.template? then opts.template else teacup.renderable =>
        teacup.span "component #{@tagName}"

      if opts.extends?
        el = document.createElement(_.dasherize(opts.extends).toLowerCase())
        if el._style?
          @_style = _.deepExtend({}, el._style, @_style)
        if el._data?
          @_data = _.extend({}, el._data, @_data)
        if el._template?
          @_contentTemplate = @_template
          @_template = el._template
        if el._methods?
          @_methods = _.extend({}, el._methods, @_methods)
        if el._events?
          @_events = _.extend({}, el._events, @_events)

      for k, v of @_methods
        proto[k] = v

      @created()


    proto._bindInputs = ->
      that = @

      $(@).find(':root /deep/ input').each((el) ->
        el = $(el)
        path = el.prop('bind')
        if path? and _.valueForKeyPath(that._data, path)?
          if !el.attr('type')?
            el.attr('type', 'text')

          switch el.attr('type').toLowerCase()
            when 'checkbox'
              el.on('change', (e) ->
                _.setValueForKeyPath(that._data, path, el[0].checked)
              )
              el[0].checked = _.valueForKeyPath(that._data, path)

            when 'radio'
              el.on('change', (e) ->
                _.setValueForKeyPath(that._data, path, el[0].checked)
              )
              el[0].checked = _.valueForKeyPath(that._data, path)

            else
              el.on('keyup', (e) ->
                _.setValueForKeyPath(that._data, path, el[0].value)
              )
              el[0].value = _.valueForKeyPath(that._data, path)
      )


    proto._removeEvents = ->
      $(@).eachDeep((el) ->
        $(el).off()
      )


    proto._createEvents = ->
      for k, v of @_events
        p = k.split(' ')
        if p.length > 1
          eventType = _.first(p)
          selector = _.rest(p).join(' ')
          els = $(@).find(_.trim(':root /deep/ ' + selector))
        else
          eventType = k.trim()
          selector = null
          els = $(@)

        if v?
          els.on(eventType, v)
        else
          els.off(eventType)


    proto._observeData = ->
      o = new ObjectObserver(@_data)
      o._el = @
      that = @

      o.open((added, removed, changed, getOldValueFn) =>
        # for p of added

        # for p of removed
        #   old = getOldValueFn(p)

        # for p of changed
        #   old = getOldValueFn(p)

        # console.log "observed:", that, "added:", added, "removed:", removed, "changed:", changed

        that.refresh()
      )

      _observers.push(o)
      @_observers.push(o)


    proto._createIds = ->
      that = @
      that._data.$ = {}
      $(@).eachDeep((el) ->
        if !_.isEmpty(el.id)
          that.data("$." + _.camelize(el.id), el)
      )


    proto.attachedCallback = ->
      @_dom()

      if @_el_style?
        @shadowRoot.appendChild(@_el_style)
      if @_el?
        @shadowRoot.appendChild(@_el)

      @_observeData()

      @_removeEvents()
      @_bindInputs()
      @_createEvents()

      @_createIds()

      @refresh()

      @attached()


    proto.detachedCallback = ->
      @_removeEvents()

      for e in @_observers
        _observers.splice(_observers.indexOf(e), 1)
      @_observers = []

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
        else
          patches = diff(@_vdom, v);
          @_el = patch(@_el, patches);
      @_vdom = v;

      @updated()

    proto.redraw = ->
      @_dom()
      # console.log "redraw", @


    proto.needsRedraw = ->
      return _.contains(_toRedraw, @)


    proto.refresh = ->
      # console.log "refresh", @
      if !_.contains(_toRedraw, @)
        _toRedraw.push(@)


    # teacup[_.camelize(_name)] = (args...) -> @tag _.camelize(_name), args...

    return document.registerElement(_name, prototype: proto)
