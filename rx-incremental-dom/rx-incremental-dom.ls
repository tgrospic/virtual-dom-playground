{elementVoid, elementOpen, elementClose, text, patch, attributes, applyProp} = IncrementalDOM
rxExtend!
idomSetup!

# FormState (model)
inc = 0 |> (i) ->-> i++
class FormState
  ~>
    # defaults
    @list = ['Element 1', 'Element 2', 'Element 3']
    @id = inc!
    @setIndex void
  focus: ~> void
  getText: ~> @list[@index] or ''
  setText: (str) ~> @list[@index] = str
  setIndex: (idx) ~>
    @index = parseInt idx if 0 <= idx < @list.length
    @focus = once {}

# Event sources
isTag = (name, el) --> el.tagName == name
# event to observable, select `event.target` element
keypress$ = Rx.DOM.keypress document.body .map (.target)
click$ = Rx.DOM.click document.body .map (.target)
# filter by element type, attributtes
index$ = click$.filter isTag 'P' .map (.idx)
text$  = keypress$.filter isTag 'INPUT' .map (.value)
reset$ = click$.filter isTag 'BUTTON' .filter (.useAs == 'RESET')

# Form logic
formState$ = reset$
  # start with one reset
  .startWith void
  # new state on reset
  .map -> new FormState!
  # in parallel with latest state value
  .share!
  .latestWith do
    index$, (st, idx) -> st.setIndex idx; st
    text$, (st, txt) -> st.setText txt; st
  # new timestamp on any change
  .do (st) -> st.time = new Date!
  # share one subscription with infinite (Number.MAX_VALUE) buffer and window time
  .shareReplay!

# Form UI
!function renderForm {id, index, focus, getText, list}
  elData = (txt, idx) ->
    isSelected = idx == index
    selCss = if isSelected then 'selected' else ''
    * class: "element #selCss", idx: idx
      !-> text txt
  # render i-dom
  idom 'div', class: 'form', !->
    idom 'input', type: 'text', setFocus: focus!, value: getText!, disabled: not index?
    [idom 'p', attr, child for [attr, child] in list.map elData]
    idom 'p', void, !-> idom 'b', void, !-> text 'ID: ' + id if id?
    idom 'button', useAs: 'RESET', !-> text 'Reset'

# History logic
history$ = Rx.Observable.of list: []
  .latestWith do
    formState$
    (hist, st) ->
      [lastSt] = hist.list
      # prepend form state
      hist.list.unshift st if not lastSt or lastSt.id != st.id
      hist

# History UI
!function renderHistory {list}
  pretty = (o) -> -> text JSON.stringify o, void, 2
  # render i-dom
  idom 'div', class: 'history', !->
    idom 'h2', void, !-> text 'History'
    [idom 'pre', void, pretty st for st in list]

# Subscribe state with incremental DOM updater, BIG BANG -> first reset :))
formState$.subscribe buildVDOMupdater renderForm
history$  .subscribe buildVDOMupdater renderHistory

# ---------------------------------------------------------------------

# Incremental-DOM update factory
function buildVDOMupdater render, container = document.body
  var lastTree, rootNode
  parent = document.createElement 'div'
  container.appendChild parent

  function updateDom data
    console.log 'UPDATE-DOM', data
    patch parent, render, data

# Incremental-DOM element builder
function idom tagName, attrs, childFunc
  attrsArray = join [[k, v] for k, v of attrs]
  elementOpen .apply @, [tagName, void, void, ...attrsArray]
  childFunc! if childFunc
  elementClose tagName

# join : [[a]] -> [a]
function join xss
  [x for xs in xss for x in xs]

# Incremental-DOM setup
function idomSetup
  # i-dom attributes hook
  attributes
    ..value = applyProp
    ..idx = applyProp
    ..useAs = applyProp
    ..setFocus = (element, name, value) -> setTimeout ->
      element.select! if value
    ..disabled = (element, name, value) ->
      if value
        then element.setAttribute 'disabled', 'disabled'
        else element.removeAttribute 'disabled'

# Rx extensions
function rxExtend
  Rx.Observable.prototype.latestWith = (...args) ->
    # [a, b, c, d] -> [[a, b], [c, d]]
    listOfPairs = toTuples 2, args
    # combine with latest from `this`
    withLatest = ([xs, fn]) ~>
      xs .withLatestFrom this .map ([x, last]) -> fn last, x
    # merge all
    Rx.Observable.merge [this, ...listOfPairs.map withLatest]

# toTuples : Int -> List a -> List (List a)
# toTuples 0 []              = []
# toTuples 2 [a, b, c, d]    = [[a, b], [c, d]]
# toTuples 3 [a, b, c, d, e] = [[a, b, c], [d, e]]
function toTuples len, arr
  [arr.splice 0, len for _ in arr by len]

# create function with single return value
function once x
  inf = [x]
  -> inf.pop!
