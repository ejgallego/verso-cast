/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license.
Author: Emilio J. Gallego Arias -/
module
public import VersoCast.Manual.Codec
public meta import Vir.Attributes
import all MultiVerso.InternalId
import all VersoManual.Basic
public section

namespace VersoCastTests.JsonSafe
open Lean Verso Verso.Doc Verso.Genre.Manual

def sample : Part Verso.Genre.Manual := {
  title := #[.text "Typed document λ"]
  titleString := "Typed document λ"
  metadata := some {
    shortTitle := some "Short", shortContextTitle := some "Context"
    authors := ["作者", "Zoë"], authorshipNote := some "note\nquote\""
    date := some "2026-10-20", tag := some "canonical"
    xrefTag := some (.provided "xref"), file := some "chapter"
    id := some ⟨900719925474099312345⟩
    number := false, draft := true, assignedNumber := some (.letter '🦀')
    htmlToc := false, htmlSplit := .never, searchPriority := 99 }
  content := #[.para #[.text "Escaped <body> 🦀"], .other {
    name := `Cast.codec
    id := some ⟨29⟩
    data := .mkObj [("exact", .num ⟨-12345678901234567890123456789000, 37⟩),
      ("nested", .arr #[.null, .bool true, .str "λ\n🦀"])]
    properties := Verso.NameMap.ofArray #[(.str .anonymous "a.b", "dotted"),
      (.str (.str .anonymous "a") "b", "first"), (.str .anonymous "", "blank"),
      (.str (.str .anonymous "a") "b", "last")]
  } #[.code "#check Nat"]]
  subParts := #[{
    title := #[.text "Child"]
    titleString := "Child"
    metadata := some {
      assignedNumber := some (.nat 900719925474099312345)
      xrefTag := some (.internal "machine")
      searchPriority := 0 }
    content := #[]
    subParts := #[] }] }

@[vir_export] def fixture : Part Verso.Genre.Manual := sample

@[vir_export] def observe (part : Part Verso.Genre.Manual) : Array String := Id.run do
  let some m := part.metadata | return #["missing metadata"]
  let numbering : Numbering → String
    | .nat n => s!"nat:{n}"
    | .letter c => s!"letter:{c}"
  let mut out := #[part.titleString,
    m.shortTitle.getD "missing", m.shortContextTitle.getD "missing",
    "|".intercalate m.authors, m.authorshipNote.getD "missing",
    m.date.getD "missing", m.tag.getD "missing",
    (match m.xrefTag with | some (.provided s) => s | _ => "missing"),
    m.file.getD "missing", (m.id.map (toString ·.id)).getD "missing",
    toString m.number, toString m.draft,
    (m.assignedNumber.map numbering).getD "missing", toString m.htmlToc,
    toString (m.htmlSplit == .never), toString m.searchPriority.val]
  let some block := part.content[1]? | return out.push "missing extension"
  let .other ext _ := block | return out.push "missing extension"
  let .ok (.num n) := ext.data.getObjVal? "exact" | return out.push "missing number"
  out := out ++ #[n.mantissa.repr, toString n.exponent,
    toString ext.properties.size,
    (ext.properties.get? (.str .anonymous "a.b")).getD "missing",
    (ext.properties.get? (.str (.str .anonymous "a") "b")).getD "missing",
    (ext.properties.get? (.str .anonymous "")).getD "missing"]
  let some child := part.subParts[0]? | return out.push "missing child"
  let some cm := child.metadata | return out.push "missing child metadata"
  out := out ++ #[child.titleString,
    (cm.assignedNumber.map numbering).getD "missing",
    (match cm.xrefTag with | some (.internal s) => s | _ => "missing"),
    toString cm.searchPriority.val]
  return out

end VersoCastTests.JsonSafe
