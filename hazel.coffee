'use strict'

{ create, diff, patch, VNode, VText } = require('virtual-dom')
{ virtualize } = require('vdom-virtualize')
toHTML = require('vdom-to-html')
isVNode = require('virtual-dom/vnode/is-vnode')
isVText = require('virtual-dom/vnode/is-vtext')
isThunk = require('virtual-dom/vnode/is-thunk')
Delegator = require("dom-delegator")
EventEmitter = require("events").EventEmitter
$v = require('vdom-query')
$ = require('bonzo')
_is = require('is')

module.exports =

  HazelComponent: class Component
    @vdom = null
    @el = null
    @data = {}
    @_needRefresh = false

    constructor: (el) ->
      @attachTo(el)
      @created()

    attachTo: (el) ->
      if el?
        if _is.string(el)
          el = $(el)
        else if _is.element(el)
          el = el
      if !el?
        el = document.createElement('div')
      @el = el

    redraw: ->
      if @_needRefresh
        v = @render()
        if _is.string(v)
          v = virtualize.fromHTML(v)
        else if !isVNode(v)
          v = null
        if v? and @vdom?
          patches = diff(@vdom, v);
          @el = patch(@el, patches);
          @vdom = v;
        @_needRefresh = false

    refresh: ->
      @needRefresh = true

    render: =>
      return null

    created: =>

    destroyed: =>

    updated: =>

    attached: =>

    detached: =>

