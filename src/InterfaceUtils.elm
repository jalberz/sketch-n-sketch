-- InterfaceUtils.elm
-- This provide utility and helper functions to Interface.elm
module InterfaceUtils where
import Lang exposing (..) --For access to what makes up the Vals
import Sync exposing (Triggers)
import Utils
import LangSvg exposing (IndexedTree, NodeId, ShapeKind, Attr, Zone)
import MainSvg exposing (tests)

import List 
import Dict
import Debug
import String

import Svg
import Lazy

type alias Model =
  { code : String
  , inputExp : Maybe Exp
  , movingObj : Maybe (NodeId, ShapeKind, Zone, Maybe MouseTrigger)
  , rootId : NodeId
  , workingSlate : IndexedTree
  , mode : Mode
  , ui : UI
  , showZones : Bool
  }

type alias UI = 
  { orient : Orientation
  --, windowSplit : (Int, Int) --TODO: for changing window dimensions of
  --codebox and visualsbox
  }

type Orientation = Vertical | Horizontal

type alias MouseTrigger = (Int, Int) -> (Exp, IndexedTree)

type alias PossibleChanges = List ((Exp, Val), Float)

type Mode
  = AdHoc | SyncSelect PossibleChanges | Live Triggers
  | NoDirectMan

syncBool m = case m of
  NoDirectMan  -> False -- TODO: dummy...
  Live _       -> False -- TODO: dummy...
  AdHoc        -> False
  SyncSelect _ -> True

--Event
--CodeUpdate : carries updated string of code with it
--SelectObject : carries an id of an object and an identifying string for a zone
--DeselectObject : carries an id of an object which shall no longer be selected
--                  for alteration.
--MousePos : carries a position of mouse on a down click
--Sync : signals the system to enter selectMode
--SelectOption : carries a possiblechange pane from sync to be displayed as the new
--              console
--Render : display a given val from the code
type Event = CodeUpdate String
           | SelectObject Int ShapeKind Zone
           | DeselectObject
           | MousePos (Int, Int)
           | Sync
           | SwitchMode Mode
           | SelectOption ((Exp, Val), Float)
           | SelectTest Int
           | Render
           | Print
           | ToggleZones
           | UIupdate UI

events : Signal.Mailbox Event
events = Signal.mailbox <| CodeUpdate ""

adjustCoords : (Int, Int) -> (Int, Int) -> (Int, Int)
adjustCoords (w,h) (mx, my) = (mx - (w // 2), my)
        
upslate : LangSvg.NodeId -> (String, LangSvg.AVal) -> LangSvg.IndexedTree -> LangSvg.IndexedTree
upslate id newattr nodes = case Dict.get id nodes of
    Nothing   -> Debug.crash "upslate"
    Just node -> case node of
        LangSvg.TextNode x -> nodes
        LangSvg.SvgNode shape attrs children -> 
            let newnode = LangSvg.SvgNode shape (Utils.update newattr attrs) children
            in Dict.insert id newnode nodes

indexedTreeToVal : NodeId -> LangSvg.IndexedTree -> Val
indexedTreeToVal rootId slate =
  let foo n =
    case n of
      LangSvg.TextNode s -> VList [VBase (String "TEXT"), VBase (String s)]
      LangSvg.SvgNode kind l1 l2 ->
        let vs1 = List.map LangSvg.valOfAttr l1 in
        let vs2 = List.map (foo << flip Utils.justGet slate) l2 in
        VList [VBase (String kind), VList vs1, VList vs2]
  in
  foo (Utils.justGet rootId slate)

switchOrient m = case m of
  Vertical -> Horizontal
  Horizontal -> Vertical

dimToPix d = String.append (toString d) "px"

-- TODO: get rid of this eventually
firstTestIndex = 15
lastTestIndex  = List.length MainSvg.tests + firstTestIndex - 1
testIndices    = [firstTestIndex .. lastTestIndex]
