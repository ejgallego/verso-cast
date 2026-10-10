/- Copyright (c) 2026 Lean FRO LLC. Released under Apache 2.0 license. -/
module
public import CastSlides.Fixture

public def main : IO Unit := do IO.print (← CastSlides.standardHtml)
