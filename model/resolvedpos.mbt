// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// ResolvedPos — a resolved document position with context information.

/// You can resolve a position to get more information about it.
/// Objects of this class represent such a resolved position.
pub(all) struct ResolvedPos {
  pos : Int
  path : Array[ResolvedPathEntry]
  parent_offset : Int
  depth : Int
} derive(Show)

/// An entry in the resolution path: a node, its child index, and the
/// absolute start offset up to that point.
struct ResolvedPathEntry {
  node : Node
  index : Int
  start_offset : Int
}

/// Construct a ResolvedPos.
pub fn ResolvedPos::new(
  pos : Int,
  path : Array[ResolvedPathEntry],
  parent_offset : Int,
) -> ResolvedPos {
  let depth = path.length() - 1
  { pos, path, parent_offset, depth }
}

/// Resolve a depth value, handling `None` (→ `self.depth`) and negative values.
fn ResolvedPos::resolve_depth(self : ResolvedPos, val : Int?) -> Int {
  match val {
    None => self.depth
    Some(v) =>
      if v < 0 {
        self.depth + v
      } else {
        v
      }
  }
}

/// The parent node that the position points into.
pub fn ResolvedPos::parent(self : ResolvedPos) -> Node {
  self.node(self.depth)
}

/// The root node in which the position was resolved.
pub fn ResolvedPos::doc(self : ResolvedPos) -> Node {
  self.node(0)
}

/// The ancestor node at the given level.
pub fn ResolvedPos::node(self : ResolvedPos, depth : Int?) -> Node {
  let d = self.resolve_depth(depth)
  self.path[d].node
}

/// The index into the ancestor at the given level.
pub fn ResolvedPos::index(self : ResolvedPos, depth : Int?) -> Int {
  let d = self.resolve_depth(depth)
  self.path[d].index
}

/// The index pointing after this position into the ancestor at the given level.
pub fn ResolvedPos::index_after(self : ResolvedPos, depth : Int?) -> Int {
  let d = self.resolve_depth(depth)
  self.index(Some(d)) +
    (if d == self.depth && self.text_offset() == 0 { 0 } else { 1 })
}

/// The (absolute) position at the start of the node at the given level.
pub fn ResolvedPos::start(self : ResolvedPos, depth : Int?) -> Int {
  let d = self.resolve_depth(depth)
  if d == 0 {
    0
  } else {
    self.path[d - 1].start_offset + 1
  }
}

/// The (absolute) position at the end of the node at the given level.
pub fn ResolvedPos::end(self : ResolvedPos, depth : Int?) -> Int {
  let d = self.resolve_depth(depth)
  self.start(Some(d)) + self.node(Some(d)).content.size
}

/// The (absolute) position directly before the wrapping node at the
/// given level.
pub fn ResolvedPos::before(self : ResolvedPos, depth : Int?) -> Int! {
  let d = self.resolve_depth(depth)
  if d == 0 {
    fail!("There is no position before the top-level node")
  }
  if d == self.depth + 1 {
    self.pos
  } else {
    self.path[d - 1].start_offset
  }
}

/// The (absolute) position directly after the wrapping node at the
/// given level.
pub fn ResolvedPos::after(self : ResolvedPos, depth : Int?) -> Int! {
  let d = self.resolve_depth(depth)
  if d == 0 {
    fail!("There is no position after the top-level node")
  }
  if d == self.depth + 1 {
    self.pos
  } else {
    self.path[d - 1].start_offset + self.path[d].node.node_size()
  }
}

/// When this position points into a text node, this returns the
/// distance between the position and the start of the text node.
/// Will be zero for positions that point between nodes.
pub fn ResolvedPos::text_offset(self : ResolvedPos) -> Int {
  self.pos - self.path[self.path.length() - 1].start_offset
}

/// Get the node directly after the position, if any.
pub fn ResolvedPos::node_after(self : ResolvedPos) -> Node? {
  let parent = self.parent()
  let index = self.index(Some(self.depth))
  if index == parent.child_count() {
    return None
  }
  let child = parent.child(index)
  let d_off = self.pos - self.path[self.path.length() - 1].start_offset
  if d_off > 0 {
    Some(child.cut(d_off, child.node_size() - child.content.size + child.content.size))
  } else {
    Some(child)
  }
}

/// Get the node directly before the position, if any.
pub fn ResolvedPos::node_before(self : ResolvedPos) -> Node? {
  let index = self.index(Some(self.depth))
  let d_off = self.pos - self.path[self.path.length() - 1].start_offset
  if d_off > 0 {
    return Some(self.parent().child(index).cut(0, d_off))
  }
  if index == 0 {
    None
  } else {
    Some(self.parent().child(index - 1))
  }
}

/// Get the position at the given index in the parent node at the
/// given depth.
pub fn ResolvedPos::pos_at_index(self : ResolvedPos, index : Int, depth : Int?) -> Int {
  let d = self.resolve_depth(depth)
  let node = self.path[d].node
  let mut pos = if d == 0 { 0 } else { self.path[d - 1].start_offset + 1 }
  for i = 0; i < index; i = i + 1 {
    pos = pos + node.child(i).node_size()
  }
  pos
}

/// Get the marks at this position, factoring in inclusive/exclusive properties.
pub fn ResolvedPos::marks(self : ResolvedPos) -> Array[Mark] {
  let parent = self.parent()
  let index = self.index(None)

  // In an empty parent, return the empty array
  if parent.content.size == 0 {
    return mark_none
  }

  // When inside a text node, just return the text node's marks
  if self.text_offset() > 0 {
    return parent.child(index).marks
  }

  let mut main = parent.maybe_child(index - 1)
  let mut other = parent.maybe_child(index)
  // If there's no node before, make the node after the main reference
  if main == None {
    let tmp = main
    main = other
    other = tmp
  }

  let mut marks : Array[Mark] = []
  match main {
    Some(m) =>
      for i = 0; i < m.marks.length(); i = i + 1 {
        marks.push(m.marks[i])
      }
      // Remove non-inclusive marks not present in other
      let mut i = 0
      while i < marks.length() {
        let mark = marks[i]
        let inclusive = match mark.typ.spec.inclusive {
          Some(false) => false
          _ => true
        }
        if not(inclusive) {
          let in_other = match other {
            Some(o) => mark.is_in_set(o.marks)
            None => false
          }
          if not(in_other) {
            marks = mark.remove_from_set(marks)
            continue
          }
        }
        i = i + 1
      }
    None => {}
  }
  marks
}

/// Get the marks after the current position, if any.
pub fn ResolvedPos::marks_across(self : ResolvedPos, end : ResolvedPos) -> Array[Mark]? {
  let after = self.parent().maybe_child(self.index(None))
  match after {
    Some(a) =>
      if not(a.is_inline()) {
        return None
      } else {
        let mut marks : Array[Mark] = []
        for i = 0; i < a.marks.length(); i = i + 1 {
          marks.push(a.marks[i])
        }
        let next = end.parent().maybe_child(end.index(None))
        let mut i = 0
        while i < marks.length() {
          let mark = marks[i]
          let inclusive = match mark.typ.spec.inclusive {
            Some(false) => false
            _ => true
          }
          if not(inclusive) {
            let in_next = match next {
              Some(n) => mark.is_in_set(n.marks)
              None => false
            }
            if not(in_next) {
              marks = mark.remove_from_set(marks)
              continue
            }
          }
          i = i + 1
        }
        Some(marks)
      }
    None => None
  }
}

/// The depth up to which this position and the given (non-resolved)
/// position share the same parent nodes.
pub fn ResolvedPos::shared_depth(self : ResolvedPos, pos : Int) -> Int {
  let mut depth = self.depth
  while depth > 0 {
    if self.start(Some(depth)) <= pos && self.end(Some(depth)) >= pos {
      return depth
    }
    depth = depth - 1
  }
  0
}

/// Returns a block range around the divergence point of this and another position.
pub fn ResolvedPos::block_range(
  self : ResolvedPos,
  other : ResolvedPos,
  pred : ((Node) -> Bool)?,
) -> NodeRange? {
  if other.pos < self.pos {
    return other.block_range(self, pred)
  }
  let mut d = self.depth -
    (if self.parent().inline_content(self) || self.pos == other.pos { 1 } else { 0 })
  while d >= 0 {
    if other.pos <= self.end(Some(d)) &&
      (match pred {
        Some(p) => p(self.node(Some(d)))
        None => true
      }) {
      return Some(NodeRange::new(self, other, d))
    }
    d = d - 1
  }
  None
}

/// Query whether the given position shares the same parent node.
pub fn ResolvedPos::same_parent(self : ResolvedPos, other : ResolvedPos) -> Bool {
  self.pos - self.parent_offset == other.pos - other.parent_offset
}

/// Return the greater of this and the given position.
pub fn ResolvedPos::max(self : ResolvedPos, other : ResolvedPos) -> ResolvedPos {
  if other.pos > self.pos { other } else { self }
}

/// Return the smaller of this and the given position.
pub fn ResolvedPos::min(self : ResolvedPos, other : ResolvedPos) -> ResolvedPos {
  if other.pos < self.pos { other } else { self }
}

/// Debug string representation.
pub fn ResolvedPos::to_debug_string(self : ResolvedPos) -> String {
  let mut str = ""
  for i = 1; i <= self.depth; i = i + 1 {
    str = str +
      (if str == "" { "" } else { "/" }) +
      self.node(Some(i)).typ.name +
      "_" +
      self.index(Some(i - 1)).to_string()
  }
  str + ":" + self.parent_offset.to_string()
}

/// Resolve a position in a document (uncached).
pub fn ResolvedPos::resolve(doc : Node, pos : Int) -> ResolvedPos! {
  if not(pos >= 0 && pos <= doc.content.size) {
    fail!("Position \(pos) out of range")
  }
  let mut path : Array[ResolvedPathEntry] = []
  let mut start = 0
  let mut parent_offset = pos
  let mut node = doc
  loop {
    let (index, offset) = node.content.find_index(parent_offset)
    let rem = parent_offset - offset
    path.push(ResolvedPathEntry::{ node, index, start_offset: start + offset })
    if rem == 0 {
      break
    }
    node = node.child(index)
    if node.is_text() {
      break
    }
    parent_offset = rem - 1
    start = start + offset + 1
  }
  ResolvedPos::new(pos, path, parent_offset)
}

/// A simple positional cache for ResolvedPos.
/// In the TS code this uses a WeakMap with a ring buffer.
/// For simplicity, we skip the cache in the MoonBit port.
pub fn ResolvedPos::resolve_cached(doc : Node, pos : Int) -> ResolvedPos! {
  ResolvedPos::resolve(doc, pos)
}

// ═══════════════════════════════════════════════════════════════════
// NodeRange
// ═══════════════════════════════════════════════════════════════════

/// Represents a flat range of content, i.e. one that starts and
/// ends in the same node.
pub(all) struct NodeRange {
  from : ResolvedPos
  to : ResolvedPos
  depth : Int
}

/// Construct a NodeRange.
pub fn NodeRange::new(from : ResolvedPos, to : ResolvedPos, depth : Int) -> NodeRange {
  { from, to, depth }
}

/// The position at the start of the range.
pub fn NodeRange::start(self : NodeRange) -> Int! {
  self.from.before(Some(self.depth + 1))
}

/// The position at the end of the range.
pub fn NodeRange::end(self : NodeRange) -> Int! {
  self.to.after(Some(self.depth + 1))
}

/// The parent node that the range points into.
pub fn NodeRange::parent(self : NodeRange) -> Node {
  self.from.node(Some(self.depth))
}

/// The start index of the range in the parent node.
pub fn NodeRange::start_index(self : NodeRange) -> Int {
  self.from.index(Some(self.depth))
}

/// The end index of the range in the parent node.
pub fn NodeRange::end_index(self : NodeRange) -> Int {
  self.to.index_after(Some(self.depth))
}