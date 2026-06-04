// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// ProseMirror Fragment — a collection of child nodes.

/// A fragment represents a node's collection of child nodes.
/// Fragments are persistent data structures — do not mutate them.
pub(all) struct Fragment {
  content : Array[Node]
  size : Int
}

/// Construct a fragment from an array of child nodes, computing total size.
pub fn Fragment::new(content : Array[Node]) -> Fragment {
  let mut s = 0
  for i = 0; i < content.length(); i = i + 1 {
    s = s + content[i].node_size()
  }
  { content, size: s }
}

/// Construct a fragment with a pre-computed size.
pub fn Fragment::new_with_size(content : Array[Node], size : Int) -> Fragment {
  { content, size }
}

/// An empty fragment.
pub let fragment_empty : Fragment = Fragment::new_with_size([], 0)

/// Invoke a callback for all descendant nodes between the given two
/// positions (relative to start of this fragment). Doesn't descend
/// into a node when the callback returns `false`.
pub fn Fragment::nodes_between(
  self : Fragment,
  from : Int,
  to : Int,
  f : (Node, Int, Node?, Int) -> Bool?,
  node_start : Int,
  parent : Node?,
) -> Unit {
  let mut pos = 0
  let mut i = 0
  while pos < to && i < self.content.length() {
    let child = self.content[i]
    let end = pos + child.node_size()
    if end > from {
      let result = f(child, node_start + pos, parent, i)
      let should_descend = match result {
        Some(b) => b
        None => true
      }
      if should_descend && child.content.size > 0 {
        let start = pos + 1
        child.nodes_between(
          max(0, from - start),
          min(child.content.size, to - start),
          f,
          node_start + start,
          Some(child),
        )
      }
    }
    pos = end
    i = i + 1
  }
}

/// Call the given callback for every descendant node recursively.
pub fn Fragment::descendants(
  self : Fragment,
  f : (Node, Int, Node?, Int) -> Bool?,
) -> Unit {
  self.nodes_between(0, self.size, f, 0, None)
}

/// Extract the text between `from` and `to`.
pub fn Fragment::text_between(
  self : Fragment,
  from : Int,
  to : Int,
  block_separator : String?,
  leaf_text : ((Node) -> String)?,
) -> String {
  let mut text = ""
  let mut first = true
  self.nodes_between(
    from,
    to,
    fn(node, pos, _parent, _index) -> Bool? {
      let node_text = if node.is_text() {
        node.text.unwrap().substring(max(from, pos) - pos, to - pos)
      } else if not(node.is_leaf()) {
        ""
      } else {
        match leaf_text {
          Some(f) => f(node)
          None =>
            match node.typ.spec.leaf_text {
              Some(lf) => lf(node)
              None => ""
            }
        }
      }
      if node.is_block() &&
        (node.is_leaf() && node_text != "" || node.is_textblock()) &&
        block_separator != None {
        if first {
          first = false
        } else {
          text = text + block_separator.unwrap()
        }
      }
      text = text + node_text
      Some(true)
    },
    0,
  )
  text
}

/// Create a new fragment containing the combined content of this
/// fragment and another.
pub fn Fragment::append(self : Fragment, other : Fragment) -> Fragment {
  if other.size == 0 {
    return self
  }
  if self.size == 0 {
    return other
  }
  let last = self.last_child().unwrap()
  let first = other.first_child().unwrap()
  let mut content : Array[Node] = []
  for i = 0; i < self.content.length(); i = i + 1 {
    content.push(self.content[i])
  }
  let mut i = 0
  if last.is_text() && last.same_markup(first) {
    // Merge adjacent text nodes with same markup
    let merged_text = last.text.unwrap() + first.text.unwrap()
    content[content.length() - 1] = last.with_text(merged_text)
    i = 1
  }
  while i < other.content.length() {
    content.push(other.content[i])
    i = i + 1
  }
  Fragment::new_with_size(content, self.size + other.size)
}

/// Cut out the sub-fragment between the two given positions.
pub fn Fragment::cut(self : Fragment, from : Int, to : Int) -> Fragment {
  if from == 0 && to == self.size {
    return self
  }
  let mut result : Array[Node] = []
  let mut size = 0
  if to > from {
    let mut pos = 0
    let mut i = 0
    while pos < to && i < self.content.length() {
      let child = self.content[i]
      let end = pos + child.node_size()
      if end > from {
        let node = if pos < from || end > to {
          if child.is_text() {
            child.cut(max(0, from - pos), min(child.text.unwrap().length(), to - pos))
          } else {
            child.cut(max(0, from - pos - 1), min(child.content.size, to - pos - 1))
          }
        } else {
          child
        }
        result.push(node)
        size = size + node.node_size()
      }
      pos = end
      i = i + 1
    }
  }
  Fragment::new_with_size(result, size)
}

/// Cut by child index (internal).
pub fn Fragment::cut_by_index(self : Fragment, from : Int, to : Int) -> Fragment {
  if from == to {
    return fragment_empty
  }
  if from == 0 && to == self.content.length() {
    return self
  }
  let mut sliced : Array[Node] = []
  for i = from; i < to; i = i + 1 {
    sliced.push(self.content[i])
  }
  Fragment::new(sliced)
}

/// Create a new fragment in which the node at the given index is
/// replaced by the given node.
pub fn Fragment::replace_child(self : Fragment, index : Int, node : Node) -> Fragment {
  let current = self.content[index]
  if current == node {
    return self
  }
  let mut copy : Array[Node] = []
  for i = 0; i < self.content.length(); i = i + 1 {
    copy.push(self.content[i])
  }
  let size = self.size + node.node_size() - current.node_size()
  copy[index] = node
  Fragment::new_with_size(copy, size)
}

/// Create a new fragment by prepending the given node to this fragment.
pub fn Fragment::add_to_start(self : Fragment, node : Node) -> Fragment {
  let mut content : Array[Node] = [node]
  for i = 0; i < self.content.length(); i = i + 1 {
    content.push(self.content[i])
  }
  Fragment::new_with_size(content, self.size + node.node_size())
}

/// Create a new fragment by appending the given node to this fragment.
pub fn Fragment::add_to_end(self : Fragment, node : Node) -> Fragment {
  let mut content : Array[Node] = []
  for i = 0; i < self.content.length(); i = i + 1 {
    content.push(self.content[i])
  }
  content.push(node)
  Fragment::new_with_size(content, self.size + node.node_size())
}

/// Compare this fragment to another one.
pub fn Fragment::eq(self : Fragment, other : Fragment) -> Bool {
  if self.content.length() != other.content.length() {
    return false
  }
  for i = 0; i < self.content.length(); i = i + 1 {
    if not(self.content[i].eq_node(other.content[i])) {
      return false
    }
  }
  true
}

/// The first child of the fragment, or `None` if it is empty.
pub fn Fragment::first_child(self : Fragment) -> Node? {
  if self.content.length() > 0 {
    Some(self.content[0])
  } else {
    None
  }
}

/// The last child of the fragment, or `None` if it is empty.
pub fn Fragment::last_child(self : Fragment) -> Node? {
  if self.content.length() > 0 {
    Some(self.content[self.content.length() - 1])
  } else {
    None
  }
}

/// The number of child nodes in this fragment.
pub fn Fragment::child_count(self : Fragment) -> Int {
  self.content.length()
}

/// Get the child node at the given index. Raises an error when out of range.
pub fn Fragment::child(self : Fragment, index : Int) -> Node! {
  if index >= self.content.length() || index < 0 {
    fail!("Index \(index) out of range for fragment")
  }
  self.content[index]
}

/// Get the child node at the given index, if it exists.
pub fn Fragment::maybe_child(self : Fragment, index : Int) -> Node? {
  if index >= 0 && index < self.content.length() {
    Some(self.content[index])
  } else {
    None
  }
}

/// Call `f` for every child node, passing the node, its offset into
/// this parent node, and its index.
pub fn Fragment::for_each(
  self : Fragment,
  f : (Node, Int, Int) -> Unit,
) -> Unit {
  let mut p = 0
  for i = 0; i < self.content.length(); i = i + 1 {
    let child = self.content[i]
    f(child, p, i)
    p = p + child.node_size()
  }
}

// FindIndex helper — returns a reusable result struct
struct FindIndexResult {
  index : Int
  offset : Int
}

/// Find the index and inner offset corresponding to a given relative
/// position in this fragment.
pub fn Fragment::find_index(self : Fragment, pos : Int) -> (Int, Int) {
  if pos == 0 {
    return (0, 0)
  }
  if pos == self.size {
    return (self.content.length(), pos)
  }
  if pos > self.size || pos < 0 {
    fail!("Position \(pos) outside of fragment")
  }
  let mut cur_pos = 0
  for i = 0; i < self.content.length(); i = i + 1 {
    let cur = self.content[i]
    let end = cur_pos + cur.node_size()
    if end >= pos {
      if end == pos {
        return (i + 1, end)
      }
      return (i, cur_pos)
    }
    cur_pos = end
  }
  fail!("Position \(pos) outside of fragment")
}

/// Find the first position at which this fragment and another differ,
/// or `None` if they are the same.
pub fn Fragment::find_diff_start(self : Fragment, other : Fragment, pos : Int) -> Int? {
  find_diff_start(self, other, pos)
}

/// Find the first position, searching from the end, at which this
/// fragment and the given fragment differ.
pub fn Fragment::find_diff_end(
  self : Fragment,
  other : Fragment,
  pos_a : Int,
  pos_b : Int,
) -> (Int, Int)? {
  find_diff_end(self, other, pos_a, pos_b)
}

/// Return a debugging string that describes this fragment.
pub fn Fragment::to_string(self : Fragment) -> String {
  "<" + self.to_string_inner() + ">"
}

/// Internal string representation.
pub fn Fragment::to_string_inner(self : Fragment) -> String {
  let parts : Array[String] = []
  for i = 0; i < self.content.length(); i = i + 1 {
    parts.push(self.content[i].to_string())
  }
  parts.join(", ")
}

/// Create a JSON-serializable representation of this fragment.
pub fn Fragment::to_json(self : Fragment) -> @json.Json? {
  if self.content.length() == 0 {
    None
  } else {
    let arr : Array[@json.Json] = []
    for i = 0; i < self.content.length(); i = i + 1 {
      arr.push(self.content[i].to_json())
    }
    Some(@json.Json::Array(arr))
  }
}

/// Deserialize a fragment from its JSON representation.
pub fn Fragment::from_json(schema : Schema, value : @json.Json?) -> Fragment! {
  guard let Some(v) = value else {
    return fragment_empty
  }
  guard let @json.Json::Array(arr) = v else {
    fail!("Invalid input for Fragment.from_json")
  }
  let nodes : Array[Node] = []
  for i = 0; i < arr.length(); i = i + 1 {
    nodes.push(schema.node_from_json(arr[i]))
  }
  Fragment::from_array(nodes)
}

/// Build a fragment from an array of nodes. Ensures that adjacent
/// text nodes with the same marks are joined together.
pub fn Fragment::from_array(array : Array[Node]) -> Fragment {
  if array.length() == 0 {
    return fragment_empty
  }
  let mut joined : Array[Node]? = None
  let mut size = 0
  for i = 0; i < array.length(); i = i + 1 {
    let node = array[i]
    size = size + node.node_size()
    if i > 0 && node.is_text() && array[i - 1].same_markup(node) {
      if joined == None {
        let mut j : Array[Node] = []
        for k = 0; k < i; k = k + 1 {
          j.push(array[k])
        }
        joined = Some(j)
      }
      let prev = joined.unwrap()[joined.unwrap().length() - 1]
      joined.unwrap()[joined.unwrap().length() - 1] = prev.with_text(
        prev.text.unwrap() + node.text.unwrap(),
      )
    } else if joined != None {
      joined.unwrap().push(node)
    }
  }
  match joined {
    Some(j) => Fragment::new_with_size(j, size)
    None => Fragment::new_with_size(array, size)
  }
}

/// Create a fragment from a fragment, node, or array of nodes.
/// `None` returns the empty fragment.
pub fn Fragment::from(nodes : Node?) -> Fragment {
  guard let Some(node) = nodes else {
    return fragment_empty
  }
  Fragment::new([node])
}

// ─── Diff helpers ──────────────────────────────────────────────────

/// Find the first position at which two fragments differ.
fn find_diff_start(a : Fragment, b : Fragment, pos : Int) -> Int? {
  let mut i = 0
  let mut pos = pos
  loop {
    if i == a.child_count() || i == b.child_count() {
      return if a.child_count() == b.child_count() {
        None
      } else {
        Some(pos)
      }
    }
    let child_a = a.child(i)
    let child_b = b.child(i)
    if child_a == child_b {
      pos = pos + child_a.node_size()
      i = i + 1
      continue
    }
    if not(child_a.same_markup(child_b)) {
      return Some(pos)
    }
    if child_a.is_text() && child_a.text != child_b.text {
      let text_a = child_a.text.unwrap()
      let text_b = child_b.text.unwrap()
      let mut j = 0
      while j < text_a.length() && j < text_b.length() && text_a[j] == text_b[j] {
        pos = pos + 1
        j = j + 1
      }
      return Some(pos)
    }
    if child_a.content.size > 0 || child_b.content.size > 0 {
      let inner = find_diff_start(child_a.content, child_b.content, pos + 1)
      if inner != None {
        return inner
      }
    }
    pos = pos + child_a.node_size()
    i = i + 1
  }
}

/// Find the first position from the end at which two fragments differ.
fn find_diff_end(a : Fragment, b : Fragment, pos_a : Int, pos_b : Int) -> (Int, Int)? {
  let mut i_a = a.child_count()
  let mut i_b = b.child_count()
  let mut pos_a = pos_a
  let mut pos_b = pos_b
  loop {
    if i_a == 0 || i_b == 0 {
      return if i_a == i_b { None } else { Some((pos_a, pos_b)) }
    }
    i_a = i_a - 1
    i_b = i_b - 1
    let child_a = a.child(i_a)
    let child_b = b.child(i_b)
    let size = child_a.node_size()
    if child_a == child_b {
      pos_a = pos_a - size
      pos_b = pos_b - size
      continue
    }
    if not(child_a.same_markup(child_b)) {
      return Some((pos_a, pos_b))
    }
    if child_a.is_text() && child_a.text != child_b.text {
      let text_a = child_a.text.unwrap()
      let text_b = child_b.text.unwrap()
      let mut same = 0
      let min_len = min(text_a.length(), text_b.length())
      while same < min_len &&
        text_a[text_a.length() - same - 1] == text_b[text_b.length() - same - 1] {
        same = same + 1
        pos_a = pos_a - 1
        pos_b = pos_b - 1
      }
      return Some((pos_a, pos_b))
    }
    if child_a.content.size > 0 || child_b.content.size > 0 {
      let inner = find_diff_end(child_a.content, child_b.content, pos_a - 1, pos_b - 1)
      if inner != None {
        return inner
      }
    }
    pos_a = pos_a - size
    pos_b = pos_b - size
  }
}