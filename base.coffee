{ $, toRedraw, redrawing, hazeling, ccss, css, vdom, renderable, div } = require('./hazel.coffee')
{ fromHTML, create, diff, patch } = vdom
{ relative } = css

# Kaffa = require('../kaffa/dist/kaffa.js')
Kaffa = require('../kaffa/kaffa.coffee')
{ Class } = Kaffa


_isEvent = (name) ->
  name.startsWith('@')


_getMixinKeys = (proto, name) ->
  r = []
  for k, v of proto
    if k == name or k.startsWith(name + '.')
      r.push(k)
  return r


_getAttributes = (view, proto) ->
  ps = proto._superclass
  sv = if ps? then _getAttributes(view, ps) else []
  v = []
  for k in _getMixinKeys(proto, 'layout')
    mv = if proto[k].attributes? then proto[k].attributes else []
    v = _.union(mv, v)
  _.union(sv, v)


_getStyle = (view, proto) ->
  ps = proto._superclass
  sv = if ps? then _getStyle(view, ps) else {}
  v = {}
  for k in _getMixinKeys(proto, 'layout')
    mv = if proto[k].style? then proto[k].style.call(view) else {}
    _.deepExtend(v, mv)
  _.deepExtend({}, sv, v)


_getTemplate = (view, proto) ->
  ps = proto._superclass
  t = if proto.layout?.template? then proto.layout.template else null
  if ps?.layout?.template?
    ps.layout.template.call(view, t)
  else if t?
    t.call(view)
  else
    renderable -> span ""


# string to type
_deserializeAttributeValue = (value) ->
  if !value?
    return false

  try
    i = parseFloat(value)
    if !_.isNaN(i)
      return i
  catch e

  return if value.toLowerCase() in ['true', 'false'] then value.toLowerCase() == 'true' else if value == '' then true else value


# type to string
_serializeAttributeValue = (value) ->
  if !value?
    return ""

  if _.isBoolean(value)
    return (if value then 'true' else 'false')
  else if _.isString(value)
    if value == ''
      return 'false'
    else
      return value
  else if value.toString?
    return value.toString()
  else
    return ""


_setVProperties = (v) ->
  if v.children?
    _setVProperties(c) for c in v.children
  if v.properties?
    for key, value of v.properties
      if !(key in ['dataset', 'id', 'class'])
        if !v.properties.attributes?
          v.properties.attributes = {}
        v.properties.attributes[key] = value


BaseView = Class 'BaseView',
  extends: HTMLElement

  layout:

    attributes: []

    style: ->
      ':host':
        position: relative
        display: 'inline-block'
        cursor: 'default'

    template: renderable (content) ->
      content.call(@) if content?


  createdCallback: ->
    @_properties = []
    for k, v of @
      if k != '$$' and k.startsWith('$') and !_.isFunction(v)
        nk = k.substr(1)
        @[nk] = @[k]
        @_properties.push(nk)

    root = @createShadowRoot()

    @isReady = false
    @isAttached = false
    @_vdom = null
    @_vdom_style = null
    @_observers = []

    @$ = $(@)
    @[0] = @
    @length = 1
    @cash = true

    if @created?
      @created()

    @_prepare()


  _bindInputs: ->
    that = @

    $(@).find(':root /deep/ input').each((el) ->
      el = $(el)
      path = el.prop('bind')
      if path? and _.valueForKeyPath(that, path)?
        if !el.attr('type')?
          el.attr('type', 'text')

        switch el.attr('type').toLowerCase()
          when 'checkbox'
            el.on('change', (e) ->
              _.setValueForKeyPath(that, path, el[0].checked)
            )
            el[0].checked = _.valueForKeyPath(that, path)

          when 'radio'
            el.on('change', (e) ->
              _.setValueForKeyPath(that, path, el[0].checked)
            )
            el[0].checked = _.valueForKeyPath(that, path)

          else
            el.on('keyup', (e) ->
              _.setValueForKeyPath(that, path, el[0].value)
            )
            el[0].value = _.valueForKeyPath(that, path)
    )


  _removeEvents: ->
    $(@).eachDeep((el) ->
      $(el).off()
    )


  _createEvents: ->
    for k, v of @__proto__
      if _isEvent(k)
        kk = k
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


  _observeProperty: (name) ->
    o = Kaffa.observe(@, name, ((args) -> @refresh()))
    o._el = @
    @_observers.push(o)


  _createIds: ->
    that = @
    @.$$ = {}
    $(@).eachDeep((el) ->
      if !_.isEmpty(el.id)
        that.$$[_.camelize(el.id)] = el
    )


  _propertiesToAttributes: ->
    for key in _getAttributes(@, @__proto__)
      if !key.startsWith('on-') and @[key]?
        @setAttribute(key, _serializeAttributeValue(@[key]))
        @_observeProperty(key)


  _attributesToProperties: ->
    for key in _getAttributes(@, @__proto__)
      if !key.startsWith('on-') and @hasAttribute(key)
        # if !@hasAttribute(key)
        #   @setAttribute(key, _serializeAttributeValue(@[key]))
        if !@[key]?
          # @[key] = null
          @[key] = _deserializeAttributeValue(@getAttribute(key))
          @_observeProperty(key)


  _attributesToEvents: ->
    for i in [0...@attributes.length]
      key = @attributes[i].name
      value = @attributes[i].value
      if key.startsWith('on-')
        if !value?
          $(@).off(key.substr(3))
        else if _.isFunction(value)
          $(@).on(key.substr(3), value)
        else if _.isString(value)
          if @[value]? and _.isFunction(@[value])
            $(@).on(key.substr(3), @[value])
          else
            $(@).on(key.substr(3), new Function(['event'], value))


  _prepare: ->
    @_dom()

    if @_el_style?
      @shadowRoot.appendChild(@_el_style)
    if @_el?
      @shadowRoot.appendChild(@_el)

    @_propertiesToAttributes()


  attachedCallback: ->
    @_propertiesToAttributes()
    @_attributesToProperties()

    if @ready?
      @ready()

    @isReady = true

    @_removeEvents()
    @_bindInputs()
    @_attributesToEvents()
    @_createEvents()

    @_createIds()

    for k in @_properties
      @_observeProperty(k)

    @redraw()

    if @attached?
      @attached()

    # @refresh()

    @isAttached = true


  detachedCallback: ->
    @_removeEvents()

    for e in @_observers
      e.close()
      Kaffa.observers.splice(Kaffa.observers.indexOf(e), 1)
    @_observers = []

    if @detached?
      @detached()

    @isAttached = false


  attributeChangedCallback: (name, oldValue, newValue) ->
    # console.log "attributeChanged:", "#{@tagName.toLowerCase()}#{if !_.isEmpty(@id) then '#' + @id else ''}#{if !_.isEmpty(@className) then '.' + @className else ''}", name, oldValue, '->', newValue
    if @isAttached
      @refresh()

  _dom: ->
    return if hazeling()

    s = _getTemplate(@, @__proto__)
    if _.isEmpty(s)
      s = '<div></div>'
    # if !s.startsWith('<div>')
    #   s = '<div>' + s + '</div>'
    st = '<style>' + ccss.compile(_getStyle(@, @__proto__)) + '</style>'

    vs = fromHTML(st)
    if vs?
      if !@_vdom_style?
        @_el_style = create(vs)
      else
        patches = diff(@_vdom_style, vs);
        @_el_style = patch(@_el_style, patches);
    @_vdom_style = vs;

    v = fromHTML(s)
    if v?
      # _setVProperties(v)

      if !@_vdom?
        @_el = create(v)
      else
        patches = diff(@_vdom, v);
        @_el = patch(@_el, patches);
    @_vdom = v;

    if @updated?
      @updated()


  redraw: ->
    @_dom()
    if _.contains(toRedraw, @)
      _.remove(toRedraw, @)
    # console.log "redraw", @


  needsRedraw: ->
    return _.contains(toRedraw, @)


  refresh: ->
    # console.log "refresh", @, toRedraw
    if !_.contains(toRedraw, @)
      toRedraw.push(@)


  created: ->


  ready: ->


  attached: ->


  detached: ->


  updated: ->


for k of $.fn
  if !(k in ['length', 'cash', 'init', 'extend']) and !BaseView.prototype[k]?
    BaseView.prototype[k] = ( (fn) -> (args...) -> fn.call(@$, args...))($.fn[k])


module.exports.BaseView = BaseView
