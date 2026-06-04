// // Copyright (C) ProseMirror Project. All Rights Reserved.
// //
// // Slice and document replacement operations.

// /// Error raised when an invalid replacement is attempted.
// pub(all) struct ReplaceError {
//   message : String
// } derive(Debug,Eq)

// fn ReplaceError::new(message : String) -> ReplaceError {
//   { message }
// }

// /// A slice represents a piece cut out of a larger document.
// /// It stores a fragment along with the open depth on each side.
// pub(all) struct Slice {
//   content : Fragment
//   open_start : Int
//   open_end : Int
// } derive(Debug,Eq)

// /// Construct a Slice.
// pub fn Slice::new(content : Fragment, open_start : Int, open_end : Int) -> Slice {
//   { content, open_start, open_end }
// }

// /// The size this slice would add when inserted into a document.
// pub fn Slice::size(self : Slice) -> Int {
//   self.content.size - self.open_start - self.open_end
// }

// /// Insert a fragment at the given position in the slice.
// pub fn Slice::insert_at(self : Slice, pos : Int, fragment : Fragment) -> Slice? {
//   let content = insert_into(
//     self.content,
//     pos + self.open_start,
//     fragment,
//     self.open_start + 1,
//     self.open_end + 1,
//     None,
//   )
//   match content {
//     Some(c) => Some(Slice::new(c, self.open_start, self.open_end))
//     None => None
//   }
// }

// /// Remove the content between two positions from the slice.
// pub fn Slice::remove_between(self : Slice, from : Int, to : Int) -> Slice {
//   Slice::new(
//     remove_range(self.content, from + self.open_start, to + self.open_start),
//     self.open_start,
//     self.open_end,
//   )
// }

// /// Test whether two slices are equal.
// pub fn Slice::eq(self : Slice, other : Slice) -> Bool {
//   self.content.eq(other.content) &&
//   self.open_start == other.open_start &&
//   self.open_end == other.open_end
// }

// /// Debug string representation.
// pub fn Slice::to_string(self : Slice) -> String {
//   self.content.to_string() + "(" + self.open_start.to_string() + "," + self.open_end.to_string() + ")"
// }

// /// Convert the slice to a JSON-serializable representation.
// pub fn Slice::to_json(self : Slice) -> @json.Json? {
//   if self.content.size == 0 {
//     return None
//   }
//   let mut obj : Map[String, @json.Json] = Map::new()
//   match self.content.to_json() {
//     Some(c) => obj["content"] = c
//     None => {}
//   }
//   if self.open_start > 0 {
//     obj["openStart"] = @json.Json::Number(self.open_start.to_double())
//   }
//   if self.open_end > 0 {
//     obj["openEnd"] = @json.Json::Number(self.open_end.to_double())
//   }
//   Some(@json.Json::Object(obj))
// }

// /// Deserialize a slice from JSON.
// pub fn Slice::from_json(schema : Schema, json : @json.Json?) -> Slice! {
//   guard let Some(v) = json else {
//     return slice_empty
//   }
//   guard let @json.Json::Object(obj) = v else {
//     fail!("Invalid input for Slice.from_json")
//   }
//   let open_start = match obj["openStart"] {
//     Some(@json.Json::Number(n)) => n.to_int()
//     _ => 0
//   }
//   let open_end = match obj["openEnd"] {
//     Some(@json.Json::Number(n)) => n.to_int()
//     _ => 0
//   }
//   let content = Fragment::from_json(schema, obj["content"])
//   Slice::new(content, open_start, open_end)
// }

// /// Create a slice from a fragment by taking the maximum possible
// /// open values on both sides.
// pub fn Slice::max_open(fragment : Fragment, open_isolating : Bool) -> Slice {
//   let mut open_start = 0
//   let mut open_end = 0
//   // Count open depth at start
//   let mut n = fragment.first_child()
//   while n != None &&
//     not(n.unwrap().is_leaf()) &&
//     (open_isolating || not(match n.unwrap().typ.spec.isolating {
//       Some(true) => true
//       _ => false
//     })) {
//     open_start = open_start + 1
//     n = n.unwrap().first_child()
//   }
//   // Count open depth at end
//   n = fragment.last_child()
//   while n != None &&
//     not(n.unwrap().is_leaf()) &&
//     (open_isolating || not(match n.unwrap().typ.spec.isolating {
//       Some(true) => true
//       _ => false
//     })) {
//     open_end = open_end + 1
//     n = n.unwrap().last_child()
//   }
//   Slice::new(fragment, open_start, open_end)
// }

// /// The empty slice.
// pub let slice_empty : Slice = Slice::new(fragment_empty, 0, 0)

// // ═══════════════════════════════════════════════════════════════════
// // Replace operation
// // ═══════════════════════════════════════════════════════════════════

// /// Replace the part of the document between two resolved positions
// /// with the given slice.
// pub fn replace(from : ResolvedPos, to : ResolvedPos, slice : Slice) -> Node! {
//   if slice.open_start > from.depth {
//     fail!("Inserted content deeper than insertion position")
//   }
//   if from.depth - slice.open_start != to.depth - slice.open_end {
//     fail!("Inconsistent open depths")
//   }
//   replace_outer(from, to, slice, 0)
// }

// // ═══════════════════════════════════════════════════════════════════
// // Internal helpers
// // ═══════════════════════════════════════════════════════════════════

// fn remove_range(content : Fragment, from : Int, to : Int) -> Fragment! {
//   let (index, offset) = content.find_index(from)
//   let child = content.maybe_child(index)
//   let (index_to, offset_to) = content.find_index(to)
//   if offset == from || child.unwrap().is_text() {
//     if offset_to != to && not(content.child(index_to).is_text()) {
//       fail!("Removing non-flat range")
//     }
//     return content.cut(0, from).append(content.cut(to, content.size))
//   }
//   if index != index_to {
//     fail!("Removing non-flat range")
//   }
//   let inner = remove_range(
//     child.unwrap().content,
//     from - offset - 1,
//     to - offset - 1,
//   )
//   content.replace_child(index, child.unwrap().copy(Some(inner)))
// }

// fn insert_into(
//   content : Fragment,
//   dist : Int,
//   insert : Fragment,
//   open_start : Int,
//   open_end : Int,
//   parent : Node?,
// ) -> Fragment? {
//   let (index, offset) = content.find_index(dist)
//   let child = content.maybe_child(index)
//   if offset == dist || child.unwrap().is_text() {
//     match parent {
//       Some(p) =>
//         if open_start <= 0 && open_end <= 0 &&
//           not(p.can_replace(index, index, insert, 0, insert.child_count())) {
//           return None
//         }
//       None => {}
//     }
//     return Some(
//       content.cut(0, dist).append(insert).append(content.cut(dist, content.size)),
//     )
//   }
//   let inner = insert_into(
//     child.unwrap().content,
//     dist - offset - 1,
//     insert,
//     if index == 0 { open_start - 1 } else { 0 },
//     if index == content.child_count() - 1 { open_end - 1 } else { 0 },
//     child,
//   )
//   match inner {
//     Some(i) => Some(content.replace_child(index, child.unwrap().copy(Some(i))))
//     None => None
//   }
// }

// fn replace_outer(
//   from : ResolvedPos,
//   to : ResolvedPos,
//   slice : Slice,
//   depth : Int,
// ) -> Node! {
//   let index = from.index(Some(depth))
//   let node = from.node(Some(depth))
//   if index == to.index(Some(depth)) && depth < from.depth - slice.open_start {
//     let inner = replace_outer(from, to, slice, depth + 1)
//     return node.copy(Some(node.content.replace_child(index, inner)))
//   } else if slice.content.size == 0 {
//     return close_node(node, replace_two_way(from, to, depth))
//   } else if slice.open_start == 0 && slice.open_end == 0 &&
//     from.depth == depth && to.depth == depth {
//     // Simple, flat case
//     let parent = from.parent()
//     let content = parent.content
//     return close_node(
//       parent,
//       content.cut(0, from.parent_offset)
//         .append(slice.content)
//         .append(content.cut(to.parent_offset, content.size)),
//     )
//   } else {
//     let (start, end) = prepare_slice_for_replace(slice, from)
//     return close_node(node, replace_three_way(from, start, end, to, depth))
//   }
// }

// fn check_join(main : Node, sub : Node) -> Unit! {
//   if not(sub.typ.compatible_content(main.typ)) {
//     fail!("Cannot join \(sub.typ.name) onto \(main.typ.name)")
//   }
// }

// fn joinable(before : ResolvedPos, after : ResolvedPos, depth : Int) -> Node {
//   let node = before.node(Some(depth))
//   check_join(node, after.node(Some(depth)))
//   node
// }

// fn add_node(child : Node, target : Array[Node]) {
//   let last_idx = target.length() - 1
//   if last_idx >= 0 && child.is_text() && child.same_markup(target[last_idx]) {
//     target[last_idx] = target[last_idx].with_text(
//       target[last_idx].text.unwrap() + child.text.unwrap(),
//     )
//   } else {
//     target.push(child)
//   }
// }

// fn add_range(
//   start : ResolvedPos?,
//   end : ResolvedPos?,
//   depth : Int,
//   target : Array[Node],
// ) {
//   let node = match end {
//     Some(e) => e.node(Some(depth))
//     None => start.unwrap().node(Some(depth))
//   }
//   let start_index = match start {
//     Some(s) =>
//       let si = s.index(Some(depth))
//       if s.depth > depth {
//         si + 1
//       } else if s.text_offset() > 0 {
//         match s.node_after() {
//           Some(na) => add_node(na, target)
//           None => {}
//         }
//         si + 1
//       } else {
//         si
//       }
//     None => 0
//   }
//   let end_index = match end {
//     Some(e) =>
//       let ei = e.index(Some(depth))
//       ei
//     None => node.child_count()
//   }
//   for i = start_index; i < end_index; i = i + 1 {
//     add_node(node.child(i), target)
//   }
//   match end {
//     Some(e) =>
//       if e.depth == depth && e.text_offset() > 0 {
//         match e.node_before() {
//           Some(nb) => add_node(nb, target)
//           None => {}
//         }
//       }
//     None => {}
//   }
// }

// fn close_node(node : Node, content : Fragment) -> Node! {
//   node.typ.check_content(content)
//   node.copy(Some(content))
// }

// fn replace_three_way(
//   from : ResolvedPos,
//   start : ResolvedPos,
//   end : ResolvedPos,
//   to : ResolvedPos,
//   depth : Int,
// ) -> Fragment {
//   let open_start = from.depth > depth && joinable(from, start, depth + 1) != Node::dummy()
//   let open_end = to.depth > depth && joinable(end, to, depth + 1) != Node::dummy()

//   let mut content : Array[Node] = []
//   add_range(None, Some(from), depth, content)
//   if open_start && open_end && start.index(Some(depth)) == end.index(Some(depth)) {
//     let os = joinable(from, start, depth + 1)
//     let oe = joinable(end, to, depth + 1)
//     check_join(os, oe)
//     add_node(
//       close_node(os, replace_three_way(from, start, end, to, depth + 1)),
//       content,
//     )
//   } else {
//     if open_start {
//       add_node(
//         close_node(
//           joinable(from, start, depth + 1),
//           replace_two_way(from, start, depth + 1),
//         ),
//         content,
//       )
//     }
//     add_range(Some(start), Some(end), depth, content)
//     if open_end {
//       add_node(
//         close_node(
//           joinable(end, to, depth + 1),
//           replace_two_way(end, to, depth + 1),
//         ),
//         content,
//       )
//     }
//   }
//   add_range(Some(to), None, depth, content)
//   Fragment::new(content)
// }

// fn replace_two_way(
//   from : ResolvedPos,
//   to : ResolvedPos,
//   depth : Int,
// ) -> Fragment {
//   let mut content : Array[Node] = []
//   add_range(None, Some(from), depth, content)
//   if from.depth > depth {
//     let typ = joinable(from, to, depth + 1)
//     add_node(
//       close_node(typ, replace_two_way(from, to, depth + 1)),
//       content,
//     )
//   }
//   add_range(Some(to), None, depth, content)
//   Fragment::new(content)
// }

// fn prepare_slice_for_replace(
//   slice : Slice,
//   along : ResolvedPos,
// ) -> (ResolvedPos, ResolvedPos) {
//   let extra = along.depth - slice.open_start
//   let parent = along.node(Some(extra))
//   let mut node = parent.copy(Some(slice.content))
//   let mut i = extra - 1
//   while i >= 0 {
//     node = along.node(Some(i)).copy(Some(Fragment::from(Some(node))))
//     i = i - 1
//   }
//   let start = node.resolve_no_cache(slice.open_start + extra)
//   let end = node.resolve_no_cache(node.content.size - slice.open_end - extra)
//   (start, end)
// }