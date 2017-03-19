module FastParser exposing (test)

import Parser exposing (..)
import Parser.LanguageKit exposing (..)
import Debug

--------------------------------------------------------------------------------
-- Parser Combinators
--------------------------------------------------------------------------------

try : Parser a -> Parser a
try parser =
  delayedCommitMap always parser (succeed ())

--------------------------------------------------------------------------------
-- Data Types
--------------------------------------------------------------------------------

type FrozenState = Frozen | Thawed | Restricted
type Range = Range Float Float

type Op0
  = Pi

type Op1
  = Cos
  | Sin
  | Arccos
  | Arcsin
  | Floor
  | Ceiling
  | Round
  | ToString
  | Sqrt
  | Explode

type Op2
  = Plus
  | Minus
  | Multiply
  | Divide
  | LessThan
  | Equal
  | Mod
  | Pow
  | Arctan2

type CasePath =
  -- pattern / value
  CasePath Exp Exp

type Exp
  = ENumber FrozenState (Maybe Range) Float
  | EString String
  | EBool Bool
  | EOp0 Op0
  | EOp1 Op1 Exp
  | EOp2 Op2 Exp Exp
  | EIf Exp Exp Exp
  -- heads / tail
  | EList (List Exp) (Maybe Exp)
  | ECase Exp (List CasePath)

--------------------------------------------------------------------------------
-- Whitespace
--------------------------------------------------------------------------------

isSpace : Char -> Bool
isSpace c =
  c == ' ' || c == '\n'

space : Parser ()
space =
  ignore (Exactly 1) isSpace

spaces : Parser ()
spaces =
  whitespace
    { allowTabs = False
    , lineComment = LineComment ";"
    , multiComment = NoMultiComment
    }

spaces1 : Parser ()
spaces1 =
  succeed identity
    |= space
    |. spaces

--------------------------------------------------------------------------------
-- Block Helper
--------------------------------------------------------------------------------

openBlock : Parser ()
openBlock =
  succeed identity
    |. spaces
    |= symbol "("
    |. spaces

closeBlock : Parser ()
closeBlock =
  succeed identity
    |. spaces
    |= symbol ")"

--------------------------------------------------------------------------------
-- Constant Expressions
--------------------------------------------------------------------------------

numParser : Parser Float
numParser =
  let
    sign =
      oneOf
        [ succeed (-1)
            |. symbol "-"
        , succeed 1
        ]
  in
    delayedCommit spaces <|
      succeed (\s n -> s * n)
        |= sign
        |= float

number : Parser Exp
number =
  let
    frozenAnnotation =
      inContext "frozen annotation" <|
        oneOf
          [ succeed Frozen
              |. symbol "!"
          , succeed Thawed
              |. symbol "?"
          , succeed Restricted
              |. symbol "~"
          , succeed Thawed -- default
          ]
    rangeAnnotation =
      inContext "range annotation" <|
        oneOf
          [ map Just <|
              succeed Range
                |. symbol "{"
                |= numParser
                |. symbol "-"
                |= numParser
                |. symbol "}"
          , succeed Nothing
          ]
  in
    inContext "number" <|
      succeed (\val frozen range -> ENumber frozen range val)
        |= numParser
        |= frozenAnnotation
        |= rangeAnnotation

string : Parser Exp
string =
  inContext "string" <|
    delayedCommit spaces <|
      succeed EString
        |. symbol "'"
        |= keep zeroOrMore (\c -> c /= '\'')
        |. symbol "'"

bool : Parser Exp
bool =
  delayedCommit spaces <|
    oneOf
      [ succeed (EBool True)
          |. keyword "true"
      , succeed (EBool False)
          |. keyword "false"
      ]

constant : Parser Exp
constant =
  oneOf
    [ number
    , string
    , bool
    ]

--------------------------------------------------------------------------------
-- Primitive Operators
--------------------------------------------------------------------------------

op0 : Parser Exp
op0 =
  inContext "nullary operator" <|
    delayedCommit spaces <|
      succeed (EOp0 Pi)
        |. keyword "pi"

op1 : Parser Exp
op1 =
  let
    op =
      oneOf
        [ succeed Cos
          |. keyword "cos"
        , succeed Sin
          |. keyword "sin"
        , succeed Arccos
          |. keyword "arccos"
        , succeed Arcsin
          |. keyword "arcsin"
        , succeed Floor
          |. keyword "floor"
        , succeed Ceiling
          |. keyword "ceiling"
        , succeed Round
          |. keyword "round"
        , succeed ToString
          |. keyword "toString"
        , succeed Sqrt
          |. keyword "sqrt"
        , succeed Explode
          |. keyword "explode"
        ]
  in
    inContext "unary operator" <|
      delayedCommit spaces <|
        succeed EOp1
          |= op
          |. spaces1
          |= exp

op2 : Parser Exp
op2 =
  let
    op =
      oneOf
        [ succeed Plus
          |. keyword "+"
        , succeed Minus
          |. keyword "-"
        , succeed Multiply
          |. keyword "*"
        , succeed Divide
          |. keyword "/"
        , succeed LessThan
          |. keyword "<"
        , succeed Equal
          |. keyword "="
        , succeed Mod
          |. keyword "mod"
        , succeed Pow
          |. keyword "pow"
        , succeed Arctan2
          |. keyword "arctan2"
        ]
  in
    inContext "binary operator" <|
      delayedCommit spaces <|
        succeed EOp2
          |= op
          |. spaces1
          |= exp
          |. spaces1
          |= exp

operator : Parser Exp
operator =
  inContext "operator" <|
    lazy <| \_ ->
      let
        inner =
          oneOf
            [ op0
            , op1
            , op2
            ]
      in
        delayedCommit openBlock <|
          succeed identity
            |= inner
            |. closeBlock

--------------------------------------------------------------------------------
-- Conditionals
--------------------------------------------------------------------------------

conditional : Parser Exp
conditional =
  inContext "conditional" <|
    delayedCommit openBlock <|
      lazy <| \_ ->
        succeed EIf
          |. keyword "if"
          |. spaces1
          |= exp
          |. spaces1
          |= exp
          |. spaces1
          |= exp
          |. closeBlock

--------------------------------------------------------------------------------
-- Lists
--------------------------------------------------------------------------------

listLiteral : Parser Exp -> Parser Exp
listLiteral elemParser =
  inContext "list literal" <|
    try <|
      succeed (\heads -> EList heads Nothing)
        |. spaces
        |. symbol "["
        |= repeat zeroOrMore elemParser
        |. spaces
        |. symbol "]"

multiCons : Parser Exp -> Parser Exp
multiCons elemParser =
  inContext "multi cons literal" <|
    delayedCommitMap
      (\heads tail -> EList heads (Just tail))
      ( succeed identity
          |. spaces
          |. symbol "["
          |= repeat oneOrMore elemParser
          |. spaces
          |. symbol "|"
      )
      ( succeed identity
          |= elemParser
          |. spaces
          |. symbol "]"
      )

list : Parser Exp -> Parser Exp
list elemParser =
  inContext "list" <|
    lazy <| \_ ->
      oneOf
        [ listLiteral elemParser
        , multiCons elemParser
        ]

--------------------------------------------------------------------------------
-- Patterns
--------------------------------------------------------------------------------

pattern : Parser Exp
pattern =
  inContext "pattern" <|
    oneOf
      [ constant
      , lazy (\_ -> list pattern)
      ]

--------------------------------------------------------------------------------
-- Case Expression
--------------------------------------------------------------------------------

caseExpression : Parser Exp
caseExpression =
  let
    casePath =
      inContext "case expression path" <|
        delayedCommit openBlock <|
          succeed CasePath
            |= pattern
            |. spaces1
            |= exp
            |. closeBlock
  in
    inContext "case expression" <|
      delayedCommit openBlock <|
        succeed ECase
          |. keyword "case"
          |= exp
          |= repeat oneOrMore casePath
          |. closeBlock

--------------------------------------------------------------------------------
-- General Expression
--------------------------------------------------------------------------------

exp : Parser Exp
exp =
  inContext "expression" <|
    oneOf
      [ constant
      , lazy (\_ -> operator)
      , lazy (\_ -> conditional)
      , lazy (\_ -> list exp)
      , lazy (\_ -> caseExpression)
      ]

--------------------------------------------------------------------------------
-- Tester
--------------------------------------------------------------------------------

testProgram = "  (  case (= 1 2) (true 'yes') (false 'no')  ) "

test _ = Debug.log (toString (parse testProgram)) 0

parse = run exp