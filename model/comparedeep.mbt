// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// Deep comparison utility for attribute objects.

/// Deep-compare two values for structural equality.
/// In MoonBit, the `==` operator performs deep structural comparison
/// for types that implement `Eq`, so this function simply delegates to `==`.
// pub fn compare_deep[V : Eq](a : V, b : V) -> Bool {
//   a == b
// }