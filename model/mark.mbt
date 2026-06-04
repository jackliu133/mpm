// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// ProseMirror marks — typed annotations attached to nodes.

/// A mark is a piece of information attached to a node,
/// such as emphasis, code font, or a link.
pub(all) struct Mark {
  typ : MarkType
  attrs : Attrs
}

/// Construct a mark with the given type and attributes.
pub fn Mark::new(typ : MarkType, attrs : Attrs) -> Mark {
  { typ, attrs }
}

/// The empty set of marks.
pub let mark_none : Array[Mark] = []

/// Given a set of marks, create a new set which contains this one as well,
/// in the right position. If this mark is already in the set, the set itself
/// is returned. If any marks that are exclusive with this mark are present,
/// those are replaced by this one.
pub fn Mark::add_to_set(self : Mark, set : Array[Mark]) -> Array[Mark] {
  let mut copy : Array[Mark]? = None
  let mut placed = false
  for i = 0; i < set.length(); i = i + 1 {
    let other = set[i]
    if self.eq(other) {
      return set
    }
    if self.typ.excludes(other.typ) {
      if copy == None {
        let mut c : Array[Mark] = []
        for j = 0; j < i; j = j + 1 {
          c.push(set[j])
        }
        copy = Some(c)
      }
    } else if other.typ.excludes(self.typ) {
      return set
    } else {
      if not(placed) && other.typ.rank > self.typ.rank {
        if copy == None {
          let mut c : Array[Mark] = []
          for j = 0; j < i; j = j + 1 {
            c.push(set[j])
          }
          copy = Some(c)
        }
        copy.unwrap().push(self)
        placed = true
      }
      if copy != None {
        copy.unwrap().push(other)
      }
    }
  }
  if copy == None {
    let mut result : Array[Mark] = []
    for j = 0; j < set.length(); j = j + 1 {
      result.push(set[j])
    }
    copy = Some(result)
  }
  if not(placed) {
    copy.unwrap().push(self)
  }
  copy.unwrap()
}

/// Remove this mark from the given set, returning a new set.
/// Returns the set itself if this mark is not in it.
pub fn Mark::remove_from_set(self : Mark, set : Array[Mark]) -> Array[Mark] {
  for i = 0; i < set.length(); i = i + 1 {
    if self.eq(set[i]) {
      let mut result : Array[Mark] = []
      for j = 0; j < i; j = j + 1 {
        result.push(set[j])
      }
      for j = i + 1; j < set.length(); j = j + 1 {
        result.push(set[j])
      }
      return result
    }
  }
  set
}

/// Test whether this mark is in the given set of marks.
pub fn Mark::is_in_set(self : Mark, set : Array[Mark]) -> Bool {
  for i = 0; i < set.length(); i = i + 1 {
    if self.eq(set[i]) {
      return true
    }
  }
  false
}

/// Test whether this mark has the same type and attributes as another mark.
pub fn Mark::eq(self : Mark, other : Mark) -> Bool {
  self.typ == other.typ && self.attrs == other.attrs
}

/// Convert this mark to a JSON-serializable representation.
pub fn Mark::to_json(self : Mark) -> @json.Json {
  let mut obj : Map[String, @json.Json] = Map::new()
  obj["type"] = @json.Json::String(self.typ.name)
  // Only include attrs if non-empty
  if self.attrs.size() > 0 {
    obj["attrs"] = @json.Json::Object(self.attrs)
  }
  @json.Json::Object(obj)
}

/// Deserialize a mark from JSON.
pub fn Mark::from_json(schema : Schema, json : @json.Json?) -> Mark! {
  guard let Some(json_val) = json else {
    fail!("Invalid input for Mark.from_json")
  }
  guard let @json.Json::Object(obj) = json_val else {
    fail!("Invalid input for Mark.from_json")
  }
  guard let Some(type_name) = obj["type"] else {
    fail!("Invalid input for Mark.from_json: missing type")
  }
  guard let @json.Json::String(type_str) = type_name else {
    fail!("Invalid input for Mark.from_json: type is not a string")
  }
  guard let Some(typ) = schema.marks[type_str] else {
    fail!("There is no mark type \(type_str) in this schema")
  }
  let attrs = match obj["attrs"] {
    Some(@json.Json::Object(a)) => a
    _ => Map::new()
  }
  let mark = typ.create(attrs)
  typ.check_attrs(mark.attrs)
  mark
}

/// Test whether two sets of marks are identical.
pub fn Mark::same_set(a : Array[Mark], b : Array[Mark]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if not(a[i].eq(b[i])) {
      return false
    }
  }
  true
}

/// Create a properly sorted mark set from a single mark or array of marks.
pub fn Mark::set_from(marks : Array[Mark]) -> Array[Mark] {
  if marks.length() == 0 {
    return mark_none
  }
  let mut copy : Array[Mark] = []
  for i = 0; i < marks.length(); i = i + 1 {
    copy.push(marks[i])
  }
  // Sort by rank
  copy.sort_by(fn(a, b) { a.typ.rank - b.typ.rank })
  copy
}