{run} = Cycle
{h, makeDOMDriver} = CycleDOM
rxExtend!

# FormState (model)
inc = 0 |> (i) ->-> i++
class FormState
  ~>
    # defaults
    @list = ['Element 1', 'Element 2', 'Element 3']
    @id = inc!
    @setIndex 0
  focus: ~> void
  getText: ~> @list[@index] or ''
  setText: (str) ~> @list[@index] = str
  setIndex: (idx) ~>
    @index = idx if 0 <= idx < @list.length
    @focus = once new FocusHook!

class FocusHook
  hook: (elem, prop) -> setTimeout -> elem.select!

# Event sources
isTag = (name) -> (el) -> el.tagName == name
# event to observable, select `event.target` element
keypress$ = Rx.DOM.input document.body .map (.target)
click$ = Rx.DOM.click document.body .map (.target)
# filter by element type, attributtes
index$ = click$.filter isTag 'P' .map (.idx)
text$  = keypress$.filter isTag 'INPUT' .map (.value)
reset$ = click$.filter isTag 'BUTTON' .filter (.useAs == 'RESET')

# Form logic
formState$ = reset$
  # start with one reset
  .startWith null
  # new state on reset
  .map -> new FormState!
  # in parallel with latest state value
  .shareReplay!
  .latestWith do
    index$, (st, idx) -> st.setIndex idx; st
    text$, (st, txt) -> st.setText txt; st
  # new timestamp on any change
  .do (st) -> st.time = new Date!
  # share one subscription with infinite (Number.MAX_VALUE) buffer and window time
  .shareReplay!

# Form UI
function renderForm {id, index, focus, getText, list}
  p = (txt, idx) ->
    isSelected = idx == index
    selCss = if isSelected then '.selected' else ''
    h "p.element#selCss" , idx: idx, [txt]
  # v-dom
  h 'div.form', [
    h 'input', type: 'text', class: focus!, value: getText!, disabled: not index?
    ...list.map p
    h 'p', h 'b', ['ID: ' + id] if id?
    h 'button', useAs: 'RESET', ['Reset']
  ]

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
function renderHistory {list}
  pretty = -> JSON.stringify it, null, 2
  p = -> h 'pre', key: it.id, [pretty it]
  # v-dom
  h 'div.history', null, [
    h 'h2', ['History']
    ...list.map p
  ]

# Map UI (render) to state observable
formVTree$ = formState$.map renderForm
historyVTree$ = history$.map renderHistory

# Subscribe state with DOM driver, BIG BANG -> first reset :))
states  = -> FORM: formVTree$,  HISTORY: historyVTree$
drivers =    FORM: makeDriver!, HISTORY: makeDriver!
run states, drivers

# ---------------------------------------------------------------------

# Virtual-DOM driver factory
function makeDriver container = document.body
  parent = document.createElement 'div'
  container.appendChild parent
  makeDOMDriver parent

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
