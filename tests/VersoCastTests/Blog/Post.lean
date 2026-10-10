/- Copyright (c) 2023-2024 Lean FRO LLC. Released under Apache 2.0 license.
Adapted from Verso's DemoSite/Blog/FirstPost.lean (David Thrane Christiansen).
Fixture additions: Emilio J. Gallego Arias. -/
module
public import VersoBlog
public meta import VersoBlog
public import Lean.Parser
public import Verso.Parser
public meta import VersoBlog.LexedText
public meta import Lean.Parser
public meta import Verso.Parser
open Verso Genre Blog LexedText

public meta section

open Lean.Parser in
open Verso.Parser in
def jsonHl : Highlighter where
  name := "json"
  lexer :=
    token `brace (chFn '{' <|> chFn '}') <|>
    token `arr (chFn '[' <|> chFn ']') <|>
    token `delim (chFn ',' <|> chFn ':') <|>
    token `bool (strFn "true" <|> strFn "false") <|>
    token `null (strFn "null") <|>
    token `num (many1Fn (satisfyFn Char.isDigit) >> optionalFn (chFn '.' >> many1Fn (satisfyFn Char.isDigit))) <|>
    token `str (chFn '"' >> manyFn (satisfyEscFn (· != '"')) >> chFn '"')
  tokenClass := fun node => some (toString node.getKind)

define_lexed_text json ← jsonHl

end

#doc (Post) "First Post" =>
%%%
authors := ["Cast fixture author"]
date := {year := 2026, month := 10, day := 10}
htmlId := some "first-post"
%%%

This post introduces the blog.

```json
{"one thing": ["and", "another"], "number": 1.5, "more": [true, false, null]}
```

An ordinary code block:
```
hello <escaped>
```

Verso supports [links][named link] defined later!

:::htmlDiv (class := "post-callout")
A *styled* callout with {htmlSpan (class := "post-badge")}[typed extensions].
:::

```leanInit post
```

```lean post (name := result)
#eval 2 + 3
```

```leanOutput result
5
```

[named link]: https://lean-lang.org
