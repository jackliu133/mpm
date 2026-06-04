// // Copyright (C) ProseMirror Project. All Rights Reserved.
// //
// // ProseMirror document node — persistent tree node with typed content.

// /// The empty attributes map, shared across nodes with no custom attributes.
// let empty_attrs : Attrs = Map::new()

// /// A ProseMirror document node — a persistent tree node with typed content.
// pub(all) struct Node {
//   typ : NodeType
//   attrs : Attrs
//   content : Fragment
//   marks : Array[Mark]
//   text : String?
// } derive(Debug,Eq)

// /// Construct a `Node` with content and marks (no text — for non-text nodes).
// pub fn Node::new(
//   typ : NodeType,
//   attrs : Attrs,
//   content : Fragment,
//   marks : Array[Mark],
// ) -> Node {
//   { typ, attrs, content, marks, text: None }
// }

// /// Construct a `Node` with text content (for text nodes).
// pub fn Node::new_text(
//   typ : NodeType,
//   attrs : Attrs,
//   text : String,
//   marks : Array[Mark],
// ) -> Node {
//   { typ, attrs, content: fragment_empty, marks, text: Some(text) }
// }

// /// The size of this node: for text nodes, the length of text;
// /// for leaf nodes, 1; for non-leaf nodes, 2 + content.size.
// pub fn Node::node_size(self : Node) -> Int {
//   if self.is_leaf() {
//     1
//   } else {
//     2 + self.content.size
//   }
// }

// /// The number of children the node has.
// pub fn Node::child_count(self : Node) -> Int {
//   self.content.child_count()
// }

// /// Get the child at `index`. Raises an error if out of range.
// pub fn Node::child(self : Node, index : Int) -> Node! {
//   self.content.child(index)
// }

// /// Get the child at `index`, if it exists (returns `None` otherwise).
// pub fn Node::maybe_child(self : Node, index : Int) -> Node? {
//   self.content.maybe_child(index)
// }

// /// Call `f` for every child node, passing the node, its offset into
// /// this parent node, and its index.
// pub fn Node::for_each(
//   self : Node,
//   f : (Node, Int, Int) -> Unit,
// ) -> Unit {
//   self.content.for_each(f)
// }

// /// Walk descendant nodes recursively between `from` and `to`,
// /// relative to start of this node's content. The callback returns
// /// `Some(false)` to stop descending into a node's children, or `None`
// /// / `Some(true)` to continue.
// pub fn Node::nodes_between(
//   self : Node,
//   from : Int,
//   to : Int,
//   f : (Node, Int, Node?, Int) -> Bool?,
//   start_pos : Int,
// ) -> Unit {
//   self.content.nodes_between(from, to, f, start_pos, Some(self))
// }

// /// Walk every descendant node recursively.
// pub fn Node::descendants(
//   self : Node,
//   f : (Node, Int, Node?, Int) -> Bool?,
// ) -> Unit {
//   self.nodes_between(0, self.content.size, f, 0)
// }

// /// The concatenated text content of the entire node.
// pub fn Node::text_content(self : Node) -> String {
//   if self.is_leaf() {
//     match self.typ.spec.leaf_text {
//       Some(lf) => lf(self)
//       None => ""
//     }
//   } else {
//     self.text_between(0, self.content.size, None, None)
//   }
// }

// /// Get the text between `from` and `to` positions.
// pub fn Node::text_between(
//   self : Node,
//   from : Int,
//   to : Int,
//   block_separator : String?,
//   leaf_text : ((Node) -> String)?,
// ) -> String {
//   self.content.text_between(from, to, block_separator, leaf_text)
// }

// /// The first child of this node, or `None` if there are no children.
// pub fn Node::first_child(self : Node) -> Node? {
//   self.content.first_child()
// }

// /// The last child of this node, or `None` if there are no children.
// pub fn Node::last_child(self : Node) -> Node? {
//   self.content.last_child()
// }

// /// Test whether two nodes represent the same piece of document.
// pub fn Node::eq_node(self : Node, other : Node) -> Bool {
//   self.same_markup(other) && self.content.eq(other.content)
// }

// /// Compare the markup (type, attributes, and marks) of this node
// /// to those of another.
// pub fn Node::same_markup(self : Node, other : Node) -> Bool {
//   self.has_markup(other.typ, Some(other.attrs), Some(other.marks))
// }

// /// Check whether this node's markup correspond to the given type,
// /// attributes, and marks.
// pub fn Node::has_markup(
//   self : Node,
//   typ : NodeType,
//   attrs : Attrs?,
//   marks : Array[Mark]?,
// ) -> Bool {
//   if self.typ != typ {
//     return false
//   }
//   let target_attrs = match attrs {
//     Some(a) => a
//     None =>
//       match typ.default_attrs {
//         Some(d) => d
//         None => empty_attrs
//       }
//   }
//   // Compare attrs using structural equality
//   if self.attrs != target_attrs {
//     return false
//   }
//   let target_marks = match marks {
//     Some(m) => m
//     None => mark_none
//   }
//   Mark::same_set(self.marks, target_marks)
// }

// /// Create a new node with the same markup as this node, containing
// /// the given content (or empty, if no content is given).
// pub fn Node::copy(self : Node, content : Fragment?) -> Node {
//   let c = match content {
//     Some(frag) => frag
//     None => fragment_empty
//   }
//   if c == self.content {
//     return self
//   }
//   Node::new(self.typ, self.attrs, c, self.marks)
// }

// /// Create a copy of this node, with the given set of marks instead
// /// of the node's own marks.
// pub fn Node::mark(self : Node, marks : Array[Mark]) -> Node {
//   if marks == self.marks {
//     return self
//   }
//   match self.text {
//     Some(t) => Node::new_text(self.typ, self.attrs, t, marks)
//     None => Node::new(self.typ, self.attrs, self.content, marks)
//   }
// }

// /// Create a copy of this node with only the content between the
// /// given positions.
// pub fn Node::cut(self : Node, from : Int, to : Int) -> Node {
//   if self.is_text() {
//     let text = self.text.unwrap()
//     if from == 0 && to == text.length() {
//       return self
//     }
//     return Node::new_text(
//       self.typ,
//       self.attrs,
//       text.substring(from, to),
//       self.marks,
//     )
//   }
//   if from == 0 && to == self.content.size {
//     return self
//   }
//   self.copy(Some(self.content.cut(from, to)))
// }

// /// Cut out the part of the document between the given positions, and
// /// return it as a `Slice` object.
// pub fn Node::slice(
//   self : Node,
//   from : Int,
//   to : Int,
//   include_parents : Bool,
// ) -> Slice {
//   if from == to {
//     return slice_empty
//   }
//   let from_pos = self.resolve(from)
//   let to_pos = self.resolve(to)
//   let depth = if include_parents { 0 } else { from_pos.shared_depth(to) }
//   let start = from_pos.start(Some(depth))
//   let node = from_pos.node(Some(depth))
//   let content = node.content.cut(from_pos.pos - start, to_pos.pos - start)
//   Slice::new(
//     content,
//     from_pos.depth - depth,
//     to_pos.depth - depth,
//   )
// }

// /// Replace the part of the document between the given positions with
// /// the given slice.
// pub fn Node::replace(self : Node, from : Int, to : Int, slice : Slice) -> Node! {
//   replace(self.resolve(from), self.resolve(to), slice)
// }

// /// Find the node directly after the given position.
// pub fn Node::node_at(self : Node, pos : Int) -> Node? {
//   let mut node : Node? = Some(self)
//   let mut pos = pos
//   loop {
//     guard let Some(current) = node else { return None }
//     let (index, offset) = current.content.find_index(pos)
//     node = current.maybe_child(index)
//     if node == None {
//       return None
//     }
//     if offset == pos || node.unwrap().is_text() {
//       return node
//     }
//     pos = pos - offset - 1
//   }
// }

// /// Find the (direct) child node after the given offset, if any,
// /// and return it along with its index and offset relative to this node.
// pub fn Node::child_after(self : Node, pos : Int) -> (Node?, Int, Int) {
//   let (index, offset) = self.content.find_index(pos)
//   (self.content.maybe_child(index), index, offset)
// }

// /// Find the (direct) child node before the given offset, if any,
// /// and return it along with its index and offset relative to this node.
// pub fn Node::child_before(self : Node, pos : Int) -> (Node?, Int, Int) {
//   if pos == 0 {
//     return (None, 0, 0)
//   }
//   let (index, offset) = self.content.find_index(pos)
//   if offset < pos {
//     return (Some(self.content.child(index)), index, offset)
//   }
//   let node = self.content.child(index - 1)
//   (Some(node), index - 1, offset - node.node_size())
// }

// /// Resolve the given position in the document, returning a `ResolvedPos`.
// pub fn Node::resolve(self : Node, pos : Int) -> ResolvedPos! {
//   ResolvedPos::resolve_cached(self, pos)
// }

// /// Resolve the position without caching.
// pub fn Node::resolve_no_cache(self : Node, pos : Int) -> ResolvedPos! {
//   ResolvedPos::resolve(self, pos)
// }

// /// Test whether a given mark or mark type occurs in this document
// /// between the two given positions.
// pub fn Node::range_has_mark(
//   self : Node,
//   from : Int,
//   to : Int,
//   mark_type : MarkType,
// ) -> Bool {
//   let mut found = false
//   if to > from {
//     self.nodes_between(
//       from,
//       to,
//       fn(node, _pos, _parent, _index) -> Bool? {
//         if mark_type.is_in_set(node.marks) != None {
//           found = true
//         }
//         Some(not(found))
//       },
//       0,
//     )
//   }
//   found
// }

// /// `true` when this is a block (non-inline node).
// pub fn Node::is_block(self : Node) -> Bool {
//   self.typ.is_block
// }

// /// `true` when this is a textblock node, a block node with inline content.
// pub fn Node::is_textblock(self : Node) -> Bool {
//   self.typ.is_textblock()
// }

// /// `true` when this node allows inline content.
// pub fn Node::inline_content(self : Node) -> Bool {
//   self.typ.inline_content()
// }

// /// `true` when this is an inline node.
// pub fn Node::is_inline(self : Node) -> Bool {
//   self.typ.is_inline()
// }

// /// `true` when this is a text node.
// pub fn Node::is_text(self : Node) -> Bool {
//   self.typ.is_text
// }

// /// `true` when this is a leaf node.
// pub fn Node::is_leaf(self : Node) -> Bool {
//   self.typ.is_leaf()
// }

// /// `true` when this is an atom, i.e. when it does not have directly
// /// editable content.
// pub fn Node::is_atom(self : Node) -> Bool {
//   self.typ.is_atom()
// }

// /// Return a string representation of this node for debugging purposes.
// pub fn Node::to_string(self : Node) -> String {
//   match self.typ.spec.to_debug_string {
//     Some(f) => f(self)
//     None => {
//       let name = self.typ.name
//       if self.content.size > 0 {
//         wrap_marks(self.marks, name + "(" + self.content.to_string_inner() + ")")
//       } else {
//         wrap_marks(self.marks, name)
//       }
//     }
//   }
// }

// /// Get the content match in this node at the given index.
// pub fn Node::content_match_at(self : Node, index : Int) -> ContentMatch! {
//   match self.typ.content_match {
//     Some(cm) =>
//       let result = cm.match_fragment(self.content, 0, index)
//       match result {
//         Some(r) => r
//         None => fail!("Called content_match_at on a node with invalid content")
//       }
//     None => fail!("Called content_match_at on a node with no content match")
//   }
// }

// /// Test whether replacing the range between `from` and `to` (by
// /// child index) with the given replacement fragment would leave the
// /// node's content valid.
// pub fn Node::can_replace(
//   self : Node,
//   from : Int,
//   to : Int,
//   replacement : Fragment,
//   start : Int,
//   end : Int,
// ) -> Bool {
//   let one = self.content_match_at(from).match_fragment(replacement, start, end)
//   if one == None {
//     return false
//   }
//   let two = one.unwrap().match_fragment(self.content, to)
//   if two == None || not(two.unwrap().valid_end) {
//     return false
//   }
//   for i = start; i < end; i = i + 1 {
//     if not(self.typ.allows_marks(replacement.child(i).marks)) {
//       return false
//     }
//   }
//   true
// }

// /// Test whether replacing the range `from` to `to` (by index) with
// /// a node of the given type would leave the node's content valid.
// pub fn Node::can_replace_with(
//   self : Node,
//   from : Int,
//   to : Int,
//   typ : NodeType,
//   marks : Array[Mark]?,
// ) -> Bool {
//   match marks {
//     Some(m) =>
//       if not(self.typ.allows_marks(m)) {
//         return false
//       }
//     None => {}
//   }
//   let start = self.content_match_at(from).match_type(typ)
//   if start == None {
//     return false
//   }
//   let end = start.unwrap().match_fragment(self.content, to)
//   match end {
//     Some(e) => e.valid_end
//     None => false
//   }
// }

// /// Test whether the given node's content could be appended to this node.
// pub fn Node::can_append(self : Node, other : Node) -> Bool {
//   if other.content.size > 0 {
//     self.can_replace(self.child_count(), self.child_count(), other.content, 0, other.child_count())
//   } else {
//     self.typ.compatible_content(other.typ)
//   }
// }

// /// Check whether this node and its descendants conform to the
// /// schema, and raise an exception when they do not.
// pub fn Node::check(self : Node) -> Unit! {
//   self.typ.check_content(self.content)
//   self.typ.check_attrs(self.attrs)
//   let mut copy = mark_none
//   for i = 0; i < self.marks.length(); i = i + 1 {
//     let mark = self.marks[i]
//     mark.typ.check_attrs(mark.attrs)
//     copy = mark.add_to_set(copy)
//   }
//   if not(Mark::same_set(copy, self.marks)) {
//     let mark_names : Array[String] = []
//     for i = 0; i < self.marks.length(); i = i + 1 {
//       mark_names.push(self.marks[i].typ.name)
//     }
//     fail!(
//       "Invalid collection of marks for node \(self.typ.name): \(mark_names.join(", "))",
//     )
//   }
//   self.content.for_each(fn(child, _offset, _index) { child.check() })
// }

// /// Return a JSON-serializable representation of this node.
// pub fn Node::to_json(self : Node) -> @json.Json {
//   let mut obj : Map[String, @json.Json] = Map::new()
//   obj["type"] = @json.Json::String(self.typ.name)
//   if self.attrs.size() > 0 {
//     obj["attrs"] = @json.Json::Object(self.attrs)
//   }
//   if self.content.size > 0 {
//     match self.content.to_json() {
//       Some(c) => obj["content"] = c
//       None => {}
//     }
//   }
//   if self.marks.length() > 0 {
//     let mark_arr : Array[@json.Json] = []
//     for i = 0; i < self.marks.length(); i = i + 1 {
//       mark_arr.push(self.marks[i].to_json())
//     }
//     obj["marks"] = @json.Json::Array(mark_arr)
//   }
//   match self.text {
//     Some(t) => obj["text"] = @json.Json::String(t)
//     None => {}
//   }
//   @json.Json::Object(obj)
// }

// /// Deserialize a node from its JSON representation.
// pub fn Node::from_json(schema : Schema, json : @json.Json) -> Node! {
//   guard let @json.Json::Object(obj) = json else {
//     fail!("Invalid input for Node.from_json")
//   }
//   // Handle marks
//   let mut marks : Array[Mark]? = None
//   match obj["marks"] {
//     Some(@json.Json::Array(arr)) =>
//       let ms : Array[Mark] = []
//       for i = 0; i < arr.length(); i = i + 1 {
//         ms.push(Mark::from_json(schema, Some(arr[i])))
//       }
//       marks = Some(ms)
//     Some(_) => fail!("Invalid mark data for Node.from_json")
//     None => {}
//   }

//   // Check if this is a text node
//   guard let Some(@json.Json::String(type_name)) = obj["type"] else {
//     fail!("Invalid input for Node.from_json: missing type")
//   }

//   if type_name == "text" {
//     guard let Some(@json.Json::String(text)) = obj["text"] else {
//       fail!("Invalid text node in JSON")
//     }
//     return schema.text(text, marks)
//   }

//   // Non-text node
//   let content = Fragment::from_json(schema, obj["content"])
//   let m = match marks {
//     Some(ms) => ms
//     None => mark_none
//   }
//   let attrs = match obj["attrs"] {
//     Some(@json.Json::Object(a)) => a
//     _ => Map::new()
//   }
//   let node_type = schema.node_type(type_name)
//   let node = node_type.create(Some(attrs), Some(content), Some(m))
//   node_type.check_attrs(node.attrs)
//   node
// }

// /// Helper to create this node with different text (for text nodes only).
// pub fn Node::with_text(self : Node, text : String) -> Node {
//   if self.is_text() && text == self.text.unwrap() {
//     return self
//   }
//   if self.is_text() {
//     return Node::new_text(self.typ, self.attrs, text, self.marks)
//   }
//   // Should not happen for non-text nodes, but return self as fallback
//   self
// }

// /// Helper to unwrap marks into their string form.
// fn wrap_marks(marks : Array[Mark], str : String) -> String {
//   let mut result = str
//   let mut i = marks.length()
//   while i > 0 {
//     i = i - 1
//     result = marks[i].typ.name + "(" + result + ")"
//   }
//   result
// }