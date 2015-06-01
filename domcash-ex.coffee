$ = require('cash-dom')
bean = require('bean')

$.fn.on = (eventType, selector, handler, args...) ->
  @each (el) -> bean.on(el, eventType, selector, handler, args...)
  return @


$.fn.add = (eventType, selector, handler, args...) ->
  @each (el) -> bean.add(el, eventType, selector, handler, args...)
  return @


$.fn.one = (eventType, selector, handler, args...) ->
  @each (el) -> bean.one(el, eventType, selector, handler, args...)
  return @


$.fn.off = (eventType, handler) ->
  @each (el) -> bean.off(el, eventType, handler)
  return @


$.fn.fire = (eventType, args...) ->
  @each (el) -> bean.fire(el, eventType, args...)
  return @


$.fn.eachDeep = (f) ->
  @each (el) ->
    f(el)
    if el.shadowRoot?
      $(el.shadowRoot).eachDeep(f)
    cn = el.childNodes
    for i in [0...cn.length]
      $(cn[i]).eachDeep(f) if cn[i].nodeType != 3
  return @


$.fn.$tagName = -> @[0].nodeName.toLowerCase()


$.fn.toggleClass = (name) ->
  @each (el) -> if el.hasClass(name) then el.removeClass(name) else el.addClass(name)
  return @


$.fn.isVisible = -> !(@[0].css('display') in ['none', 'hidden']) and !(@[0].visibility in ['hidden', 'collapse'])


$.fn.isHidden = -> !@[0].isVisible()


$.fn.show = ->
  @each (el) ->
    if el._prevDisplay? and el.isHidden()
      el.css('display', el._prevDisplay)
      delete el._prevDisplay
  return @


$.fn.hide = ->
  @each (el) ->
    if !el.isHidden()
      el._prevDisplay = el.css('display')
  return @


$.fn.toggle = ->
  @each (el) ->
    if el.isHidden() then el.show() else el.hide()
  return @


# _css = (el, name, value, computed) ->
#   computed = if computed then window.getComputedStyle(el.) else false
#   if name?
#     if _.isString(name)
#       if !value?
#         if computed?
#           computed.getPropertyValue(name)
#         else
#           el.style[name]
#       else
#         if _.isNumber(value)

#         else
#           el.style[name] = value

#     else if _.isObject(name)
#       for k, v of name
#         el.style[k] = v

#   else
#     r = {}
#     for k of el.style
#       v = if computed? then computed.getPropertyValue(k) else el.style[k]
#       if v?
#         r[k] = v
#     return r


# _find = (el, selector, deep, shadow) ->
#   _.first(_all(el, selector, deep, shadow))

#   if _.isString(selector)
#     if shadow and !selector.startsWith('body /deep/ ')
#       selector = 'body /deep/ ' + selector
#     e = el.querySelector(selector)
#     if e?
#       return e
#     else
#       for r in el.childNodes
#         if r.childNodes.length
#           e = _find(r, selector, deep, shadow)
#           if e?
#             return e

#   else if _.isFunction(selector)
#     r = _all(el, selector, deep, shadow)
#     return _.filter(r, (el) -> selector(el))

#   return null


# _all = (el, selector, deep, shadow) ->
#   if _.isString(selector)
#     if shadow and !selector.startsWith('body /deep/ ')
#       selector = 'body /deep/ ' + selector
#     return Array.from(el.querySelectorAll(selector))

#   else if _.isFunction(selector)
#     r = _all(el, '*', deep, shadow)
#     return _.filter(r, (el) -> selector(el))


$.fn.isEnabled = -> !@[0].disabled?


$.fn.isDisabled = -> @[0].disabled?


$.fn.isFocusable = -> @[0].isEnabled() and @[0].isVisible()


$.fn.isShadowed = ->
  el = @[0]
  p = el.parentNode?
  return p.nodeType == 11 and p.host?


$.fn.focusableElements = ->
  l = []
  @eachDeep (el) ->
    if el.isFocusable()
      l.push(el)
  return $(l)


_focusElement = (el, i) ->
  f = el.focusableElements()
  if i == -1
    i = f.length - 1
  r = if i in [0...f.length] then f[i] else null
  if r?
    r.focus()
  return r


$.fn.focusFirst = ->
  _focusElement(@[0], 0)
  return @


$.fn.focusLast = ->
  _focusElement(@[0], -1)
  return @


$.fn.focusNext = ->
  el = @[0]
  f = el.focusableElements()
  i = f.indexOf(el)
  if i != -1
    f[if i + 1 < f.length then i + 1 else 0].focus()
  return @


$.fn.focusPrevious = ->
  el = @[0]
  f = @focusableElements()
  i = f.indexOf(@)
  if i != -1
    f[if i - 1 > -1 then i - 1 else f.length - 1].focus()
  return @


oldAttr = $.fn.attr
$.fn.attr = (name, value) ->
  if value? and value == false
    @removeAttr(name)
  else
    oldAttr.call(@, name, value)


oldVal = $.fn.val
$.fn.val = (value) ->
  r = @
  processed = false
  @each (el) ->
    if el.type in ['radio', 'checkbox', 'toggle']
      if value? and _.isBoolean(value)
        el.attr('checked', value)
        processed = true
      else
        r = el.attr('checked')
        processed = true

    else if el.options?
      if !value?
        if el.options.length < el.selectedIndex
          el.options[el.selectedIndex]
          processed = true
      else
        if !_.isArray(value)
          value = [value]
        ok = false
        for i in [0...options.length]
          if el.options[i].selected = !el.options[i].disabled and el.options[i].value in value
            ok = true
        if !ok
          el.selectedIndex = -1
        processed = true

  if !processed
    r = oldVal.call(@, value)

  return r

