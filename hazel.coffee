'use strict'

# Kaffa = require('../kaffa/dist/kaffa.js')
Kaffa = require('../kaffa/kaffa.coffee')

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
{ Class } = Kaffa

_ = require('underscore-plus')
_.is = require('is')


_toRedraw = []
_redrawing = false
_hazeling = false

raf _redrawAll = ->

  _redrawing = true
  if _toRedraw.length
    for r in _toRedraw
      r.redraw()
    _toRedraw.length = 0
  _redrawing = false

  raf(_redrawAll)


# $.fn.on = bean.on.bind(bean)
# $.fn.one = bean.one.bind(bean)
# $.fn.off = bean.off.bind(bean)
# $.fn.fire = bean.fire.bind(bean)

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


_classify = (name) ->
  _.capitalize(_.camelize(name))

_isElementRegistered = (name) ->
  _elementConstructor(name) != HTMLElement

_elementConstructor = (name) ->
  document.createElement(name).constructor

_createElement = (name, attributes) ->
  el = document.createElement(name)
  for key, value of attributes
    el.setAttribute(key, value.toString())
  return el

_appendElement = (name, selector, attributes) ->
  el = _createElement(name, attributes)
  $(selector)[0].appendChild(el)
  return el

_loadCSS = (path, macros) ->
  fs = require('fs')
  el = document.createElement('style')
  s = fs.readFileSync(path).toString()
  if macros?
    for k, v of macros
      s = s.replace(new RegExp('__' + k + '__', 'gim'), v)
  el.textContent = s
  document.querySelector('head').appendChild(el)
  return el


module.exports =
  $: $
  bean: bean
  raf: raf
  ccss: ccss
  teacup: teacup

  toRedraw: _toRedraw
  redrawing: -> _redrawing
  hazeling: -> _hazeling

  vdom:
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

  isElementRegistered: _isElementRegistered
  elementConstructor: _elementConstructor
  createElement: _createElement
  appendElement: _appendElement
  loadCSS: _loadCSS

  css:
    none: 'none'
    auto: 'auto'
    inherit: 'inherit'
    hidden: 'hidden'
    pointer: 'pointer'
    normal: 'normal'
    block: 'block'
    transparent: 'transparent'
    absolute: 'absolute'
    relative: 'relative'
    baseline: 'baseline'
    center: 'center'
    middle: 'middle'
    top: 'top'
    left: 'left'
    bottom: 'bottom'
    right: 'right'

    rgb: (red, green, blue) -> "rgb(#{red}, #{green}, #{blue})"

    rgba: (red, green, blue, opacity) -> "rgba(#{red}, #{green}, #{blue}, #{opacity})"

    em: ->
      r = []
      for a in arguments
        r.push(a + 'em')
      r.join(' ')

    rem: ->
      r = []
      for a in arguments
        r.push(a + 'rem')
      r.join(' ')

    px: ->
      r = []
      for a in arguments
        r.push(a + 'px')
      r.join(' ')

    important: -> Array.prototype.slice.call(arguments).join(' ') + ' !important'


  hazel: (name, klass) ->
    klass = BaseView if !klass?
    proto = klass.prototype

    if !_isElementRegistered(name)
      _hazeling = true
      e = document.registerElement(_.dasherize(name), prototype: proto)
      _hazeling = false

    # teacup tag
    f = -> teacup.tag name, arguments...

    window[name.replace('-', '_')] = f
    window[_.camelize(name)] = f

    return klass

  shutHazel: ->


for k, v of teacup
  module.exports[k] = v

for k, v of require('observe-js')
  module.exports[k] = v

module.exports.BaseView = require('./base.coffee').BaseView
