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

module.exports.observers = _observers

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


module.exports.shutHazel = ->
  for o in _observers
    o.close()


isElementRegistered = (name) ->
  document.createElement(name).constructor != HTMLElement
module.exports.isElementRegistered = isElementRegistered


elementConstructor = (name) ->
  document.createElement(name).constructor
module.exports.elementConstructor = elementConstructor


createElement = (name, attributes) ->
  el = document.createElement(name)
  for key, value of attributes
    el.setAttribute(key, value.toString())
  return el

appendElement = (name, selector, attributes) ->
  el = createElement(name, attributes)
  $(selector)[0].appendChild(el)
  return el

module.exports.createElement = createElement
module.exports.appendElement = appendElement


module.exports.hazel = (name, opts) ->
  proto = Object.create(HTMLElement.prototype)

  if !opts? or !opts.extends?
    if !proto.created?
      proto.created = ->

    if !proto.ready?
      proto.ready = ->

    if !proto.attached?
      proto.attached = ->

    if !proto.detached?
      proto.detached = ->

    if !proto.updated?
      proto.updated = ->

  proto._style = if opts? and opts.style? then opts.style else -> {}


  proto.createdCallback = ->
    root = @createShadowRoot()

    @isReady = false
    @isAttached = false
    @_data = if opts.data? then _.clone(opts.data) else {}
    @_attributes = if opts.attributes? then opts.attributes.split(' ') else []
    @_vdom = null
    @_vdom_style = null
    @_observers = []

    @data = (name, value) ->
      if arguments.length == 0
        @_data
      else if arguments.length > 1
        _.setValueForKeyPath(@_data, name, value)
      _.valueForKeyPath(@_data, name)

    @_template = if opts.template? then opts.template else teacup.renderable =>
      teacup.span "component #{@tagName}"

    _super = null

    if opts? and opts.extends?
      el = document.createElement(_.dasherize(opts.extends).toLowerCase())
      proto.__proto__ = el.__proto__
      _super = proto.__proto__

      if _super._style?
        proto._style = ((fct, superFct) ->
          () ->
            s = superFct.bind(@)
            try
              r = fct.call(@)
            finally
              r = _.deepExtend({}, r, s.call(@))
            return r
        )(proto._style, _super._style)

      if el._data?
        @_data = _.extend({}, el._data, @_data)

      if el._attributes? and el._attributes.length
        @_attributes = _.intersection(@_attributes, el._attributes)

      if el._template?
        @_contentTemplate = @_template
        @_template = el._template

    # inherit functions
    if opts?
      for k of opts
        if _.isFunction(opts[k]) and !(k in ['style'])
          if _super and _.isFunction(_super[k])
            proto[k] = ((fct, superFct) ->
              () ->
                tmp = @super
                @super = superFct.bind(@)
                try
                  fct.call(@, arguments)
                finally
                  @super = tmp
            )(opts[k], _super[k])
          else
            proto[k] = opts[k]

    if @created?
      @created()

    @_prepare()


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
    for k, v of @
      if k.startsWith('@')
        k = k.substr(1)
        p = k.split(' ')
        if p.length > 1
          eventType = _.first(p)
          selector = _.rest(p).join(' ')
          els = $(@).find(':root /deep/ ' + selector.trim())
        else
          eventType = k.trim()
          selector = null
          els = $(@)

        if v?
          els.on(eventType, v)
        else
          els.off(eventType)


  proto._observeProperty = (name) ->
    v = @[name]
    that = @

    if _.isArray(v)
      o = new ArrayObserver(v)
      o.open (splices) ->
        splices.forEach (splice) ->
          console.log "observed:", that, splice.index, splice.removed, splice.addedCount

    else if _.isObject(v)
      o = new ObjectObserver(v)
      o.open (added, removed, changed, getOldValueFn) ->
        # for p of added

        # for p of removed
        #   old = getOldValueFn(p)

        # for p of changed
        #   old = getOldValueFn(p)

        console.log "observed:", that, "added:", added, "removed:", removed, "changed:", changed
        that.refresh()

    else
      o = new PathObserver(@, name)
      o.open (newValue, oldValue) ->
        console.log "observed:", that, oldValue, '->', newValue
        that.refresh()

    o._el = @

    _observers.push(o)
    @_observers.push(o)


  proto._createIds = ->
    that = @
    that._data.$ = {}
    $(@).eachDeep((el) ->
      if !_.isEmpty(el.id)
        that.data("$." + _.camelize(el.id), el)
    )


  # string to type
  proto._deserializeAttributeValue = (value) ->
    try
      i = parseFloat(value)
      if !_.isNaN(i)
        return i
    catch e

    if value.toLowerCase() in ['true', 'false', 't', 'f', 'yes', 'no', 'y', 'n']
      return value in ['true', 't', 'yes', 'y']
    else if value.toString?
      return value.toString()
    else
      return ""


  # type to string
  proto._serializeAttributeValue = (value) ->
    if _.isBoolean(value)
      return (if value then "true" else "false")
    else if _.isString(value)
      return value
    else if value.toString?
      return value.toString()
    else
      return ""


  proto._propertiesToAttributes = ->
    for key in @_attributes
      if @[key]?
        @setAttribute(key, @_serializeAttributeValue(@[key]))
        @_observeProperty(key)


  proto._attributesToProperties = ->
    for key in @_attributes
      if !@[key]?
        @[key] = null
        @_observeProperty(key)
        @[key] = @_deserializeAttributeValue(@getAttribute(key))


  proto._attributesToEvents = ->
    for i in [0...@attributes.length]
      key = @attributes[i].name
      value = @attributes[i].value
      if key.startsWith('on-')
        if @[value]? and _.isFunction(@[value])
          @on(key.substr(3), @[value])


  proto._prepare = ->
    @_dom()

    if @_el_style?
      @shadowRoot.appendChild(@_el_style)
    if @_el?
      @shadowRoot.appendChild(@_el)

    @_propertiesToAttributes()


  proto.attachedCallback = ->
    @_attributesToProperties()

    if @ready?
      @ready()

    @isReady = true

    @_removeEvents()
    @_bindInputs()
    @_attributesToEvents()
    @_createEvents()

    @_createIds()

    @_observeProperty('_data')

    @refresh()

    if @attached?
      @attached()

    @isAttached = true


  proto.detachedCallback = ->
    @_removeEvents()

    for e in @_observers
      _observers.splice(_observers.indexOf(e), 1)
    @_observers = []

    if @detached?
      @detached()

    @isAttached = false


  proto.attributeChangedCallback = (name, oldValue, newValue) ->
    console.log "attributeChanged:", name, oldValue, '->', newValue


  proto._dom = ->
    s = @_template(@, @_contentTemplate)
    if _.isEmpty(s)
      s = '<div></div>'

    st = '<style>' + ccss.compile(@_style()) + '</style>'
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

    if @updated?
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


  # teacup[_.camelize(name)] = (args...) -> @tag _.camelize(name), args...

  if !isElementRegistered(name)
    e = document.registerElement(name, prototype: proto)
  else
    e = null
  return e
