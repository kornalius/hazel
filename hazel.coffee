'use strict'

Guid = require('guid')

# Kaffa = require('../kaffa/dist/kaffa.js')
Kaffa = require('../kaffa/kaffa.coffee')

{ create, diff, patch, VNode, VText } = require('virtual-dom')

# convertHTML = require('html-to-vdom')(VNode: VNode, VText: VText)
# fromHTML = convertHTML.bind(null,
#     getVNodeKey: (attributes) ->
#       if attributes?.id?
#         attributes.id
#       # else
#       #   Guid.raw()
# )

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
color = require('color')

_ = require('underscore-plus')
_.is = require('is')
_.extend(_, require('underscore-contrib'))


_contents = []
_toRedraw = []
_redrawing = false
_hazeling = false

raf _redrawAll = ->

  _redrawing = true
  if _toRedraw.length
    t = _.clone(_toRedraw)
    _toRedraw.length = 0
    for r in t
      r.redraw()
  _redrawing = false

  raf(_redrawAll)


require('./cashdom-ex.coffee')


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
  color: color

  toRedraw: _toRedraw
  redrawing: -> _redrawing
  hazeling: -> _hazeling
  contents: _contents

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

    f = teacup.renderable (args...) ->
          { selector, attrs, contents } = teacup.normalizeArgs args
          if !_.isFunction(contents)
            teacup.tag name, selector, attrs, contents
          else
            i = _contents.indexOf(contents)
            if i == -1
              i = _contents.length
              _contents.push contents
            teacup.tag name, selector, attrs, "#{i}"

    # f = teacup.component (selector, attrs, renderContents, args...) ->
    #       @raw "<#{name}#{@renderAttrs attrs}>"
    #       renderContents.apply(@, args)
    #       @raw "</#{name}>"

    window[name.replace('-', '_')] = f
    window[_.camelize(name)] = f

    return klass


  shutHazel: ->


if !teacup.oldRenderAttr?
  teacup.oldRenderAttr = teacup.renderAttr
  teacup.renderAttr = (name, value) ->
    if name == 'content' and _.isFunction(value)
      @_content = value
    else
      teacup.oldRenderAttr name, value


for k, v of teacup
  module.exports[k] = v

for k, v of require('observe-js')
  module.exports[k] = v

module.exports.BaseView = require('./base.coffee').BaseView
