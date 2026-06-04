// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// ProseMirror Schema — defines document node and mark types.

/// Attribute values are stored as JSON values.
pub type Attrs = Map[String, @json.Json]

/// A specification for a single attribute on a node or mark type.
pub(all) struct AttributeSpec {
  default : @json.Json?
  validate : (@json.Json) -> Unit!?
}

/// Specification for a node type.
pub(all) struct NodeSpec {
  content : String?
  marks : String?
  group : String?
  inline : Bool?
  atom : Bool?
  attrs : Map[String, AttributeSpec]?
  selectable : Bool?
  draggable : Bool?
  code : Bool?
  whitespace : String?
  defining_as_context : Bool?
  defining_for_content : Bool?
  defining : Bool?
  isolating : Bool?
  leaf_text : ((Node) -> String)?
  to_debug_string : ((Node) -> String)?
  linebreak_replacement : Bool?
}

/// Specification for a mark type.
pub(all) struct MarkSpec {
  attrs : Map[String, AttributeSpec]?
  inclusive : Bool?
  excludes : String?
  group : String?
  spanning : Bool?
  code : Bool?
}

/// A node type — describes a class of nodes in the schema.
pub(all) struct NodeType {
  name : String
  schema : Schema
  spec : NodeSpec
  groups : Array[String]
  attrs : Map[String, Attribute]
  default_attrs : Attrs?
  is_block : Bool
  is_text : Bool
  // Filled in during schema compilation
  mut content_match : ContentMatch?
  mut inline_content : Bool?
  mut mark_set : Array[MarkType]?
  mut is_textblock : Bool?
  mut is_leaf : Bool?
  mut is_atom : Bool?
}

/// A mark type — describes a class of marks in the schema.
pub(all) struct MarkType {
  name : String
  rank : Int
  schema : Schema
  spec : MarkSpec
  attrs : Map[String, Attribute]
  mut excluded : Array[MarkType]?
  instance : Mark?
}

/// Internal attribute descriptor with defaults and validation.
struct Attribute {
  has_default : Bool
  default : @json.Json?
  validate : (@json.Json) -> Unit!?
}

/// The document schema — holds all node and mark types.
pub(all) struct Schema {
  spec : SchemaSpec
  nodes : Map[String, NodeType]
  marks : Map[String, MarkType]
  top_node_type : NodeType
  mut linebreak_replacement : NodeType?
  // Bound functions
  mut node_from_json : (@json.Json) -> Node
  mut mark_from_json : (@json.Json) -> Mark
  mut cached : Map[String, @json.Json]
}

/// Internal spec snapshot.
struct SchemaSpec {
  nodes : Map[String, NodeSpec]
  marks : Map[String, MarkSpec]
  top_node : String?
}

// ═══════════════════════════════════════════════════════════════════
// Attribute helpers
// ═══════════════════════════════════════════════════════════════════

fn init_attrs(
  type_name : String,
  attrs : Map[String, AttributeSpec]?,
) -> Map[String, Attribute] {
  let result : Map[String, Attribute] = Map::new()
  match attrs {
    None => {}
    Some(amap) =>
      for name in amap.keys() {
        let spec = amap[name]
        result[name] = Attribute::new(type_name, name, spec)
      }
  }
  result
}

fn Attribute::new(type_name : String, attr_name : String, options : AttributeSpec) -> Attribute {
  let has_default = match options.default {
    Some(_) => true
    None => false
  }
  {
    has_default,
    default: options.default,
    validate: options.validate,
  }
}

fn default_attrs(attrs : Map[String, Attribute]) -> Attrs? {
  let mut defaults : Map[String, @json.Json] = Map::new()
  for name in attrs.keys() {
    let attr = attrs[name]
    if not(attr.has_default) {
      return None
    }
    match attr.default {
      Some(d) => defaults[name] = d
      None => return None
    }
  }
  Some(defaults)
}

fn compute_attrs(attrs : Map[String, Attribute], value : Attrs?) -> Attrs! {
  let mut built : Map[String, @json.Json] = Map::new()
  for name in attrs.keys() {
    let attr = attrs[name]
    let given = match value {
      Some(v) => v[name]
      None => None
    }
    let resolved = match given {
      Some(g) => g
      None =>
        if attr.has_default {
          match attr.default {
            Some(d) => d
            None => fail!("No value supplied for attribute \(name)")
          }
        } else {
          fail!("No value supplied for attribute \(name)")
        }
    }
    built[name] = resolved
  }
  built
}

fn check_attrs(
  attr_defs : Map[String, Attribute],
  values : Attrs,
  type_kind : String,
  type_name : String,
) -> Unit! {
  // Check for unsupported attributes
  for attr in values.keys() {
    if not(attr_defs.contains(attr)) {
      fail!(
        "Unsupported attribute \(attr) for \(type_kind) of type \(type_name)",
      )
    }
  }
  // Run validators
  for attr in attr_defs.keys() {
    let def = attr_defs[attr]
    match def.validate {
      Some(validate_fn) =>
        match values[attr] {
          Some(val) => validate_fn(val)
          None => {}
        }
      None => {}
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// NodeType methods
// ═══════════════════════════════════════════════════════════════════

/// True if this node type has inline content.
pub fn NodeType::inline_content(self : NodeType) -> Bool {
  match self.inline_content {
    Some(v) => v
    None => false
  }
}

/// True if this is a textblock type.
pub fn NodeType::is_textblock(self : NodeType) -> Bool {
  match self.is_textblock {
    Some(v) => v
    None => false
  }
}

/// True if this is an inline type.
pub fn NodeType::is_inline(self : NodeType) -> Bool {
  not(self.is_block)
}

/// True for node types that allow no content.
pub fn NodeType::is_leaf(self : NodeType) -> Bool {
  match self.is_leaf {
    Some(v) => v
    None => false
  }
}

/// True when this node is an atom.
pub fn NodeType::is_atom(self : NodeType) -> Bool {
  match self.is_atom {
    Some(v) => v
    None => false
  }
}

/// True when this node is a text node.
pub fn NodeType::is_text(self : NodeType) -> Bool {
  self.is_text
}

/// Return true when this node type is part of the given group.
pub fn NodeType::is_in_group(self : NodeType, group : String) -> Bool {
  for i = 0; i < self.groups.length(); i = i + 1 {
    if self.groups[i] == group {
      return true
    }
  }
  false
}

/// The whitespace mode for this node type.
pub fn NodeType::whitespace(self : NodeType) -> String {
  match self.spec.whitespace {
    Some(w) => w
    None =>
      match self.spec.code {
        Some(true) => "pre"
        _ => "normal"
      }
  }
}

/// Tells you whether this node type has any required attributes.
pub fn NodeType::has_required_attrs(self : NodeType) -> Bool {
  for name in self.attrs.keys() {
    if not(self.attrs[name].has_default) {
      return true
    }
  }
  false
}

/// Indicates whether this node allows some of the same content as another.
pub fn NodeType::compatible_content(self : NodeType, other : NodeType) -> Bool {
  if self == other {
    return true
  }
  match (self.content_match, other.content_match) {
    (Some(a), Some(b)) => a.compatible(b)
    _ => false
  }
}

/// Create a Node of this type.
pub fn NodeType::create(
  self : NodeType,
  attrs : Attrs?,
  content : Fragment?,
  marks : Array[Mark]?,
) -> Node! {
  if self.is_text {
    fail!("NodeType.create can't construct text nodes")
  }
  let a = compute_attrs(self.attrs, attrs)
  let c = match content {
    Some(frag) => frag
    None => fragment_empty
  }
  let m = match marks {
    Some(mk) => Mark::set_from(mk)
    None => mark_none
  }
  Node::new(self, a, c, m)
}

/// Like `create`, but checks content against the node's content restrictions.
pub fn NodeType::create_checked(
  self : NodeType,
  attrs : Attrs?,
  content : Fragment?,
  marks : Array[Mark]?,
) -> Node! {
  let c = match content {
    Some(frag) => frag
    None => fragment_empty
  }
  self.check_content(c)
  let a = compute_attrs(self.attrs, attrs)
  let m = match marks {
    Some(mk) => Mark::set_from(mk)
    None => mark_none
  }
  Node::new(self, a, c, m)
}

/// Create and fill — auto-generate nodes at start and end to make content fit.
pub fn NodeType::create_and_fill(
  self : NodeType,
  attrs : Attrs?,
  content : Fragment?,
  marks : Array[Mark]?,
) -> Node? {
  let a = compute_attrs(self.attrs, attrs)
  let mut c = match content {
    Some(frag) => frag
    None => fragment_empty
  }
  if c.size > 0 {
    match self.content_match {
      Some(cm) =>
        let before = cm.fill_before(c, false, 0)
        match before {
          Some(b) => c = b.append(c)
          None => return None
        }
      None => return None
    }
  }
  match self.content_match {
    Some(cm) =>
      let matched = cm.match_fragment(c, 0, c.child_count())
      match matched {
        Some(m) =>
          let after = m.fill_before(fragment_empty, true, 0)
          match after {
            Some(a) => c = c.append(a)
            None => return None
          }
        None => return None
      }
    None => return None
  }
  let m = match marks {
    Some(mk) => Mark::set_from(mk)
    None => mark_none
  }
  Some(Node::new(self, a, c, m))
}

/// Returns true if the given fragment is valid content for this node type.
pub fn NodeType::valid_content(self : NodeType, content : Fragment) -> Bool {
  match self.content_match {
    Some(cm) =>
      let result = cm.match_fragment(content, 0, content.child_count())
      if result == None || not(result.unwrap().valid_end) {
        return false
      }
      for i = 0; i < content.child_count(); i = i + 1 {
        if not(self.allows_marks(content.child(i).marks)) {
          return false
        }
      }
      true
    None => false
  }
}

/// Check content validity, raising on failure.
pub fn NodeType::check_content(self : NodeType, content : Fragment) -> Unit! {
  if not(self.valid_content(content)) {
    fail!(
      "Invalid content for node \(self.name): \(content.to_string().substring(0, 50))",
    )
  }
}

/// Check attribute validity.
pub fn NodeType::check_attrs(self : NodeType, attrs : Attrs) -> Unit! {
  check_attrs(self.attrs, attrs, "node", self.name)
}

/// Check whether the given mark type is allowed in this node.
pub fn NodeType::allows_mark_type(self : NodeType, mark_type : MarkType) -> Bool {
  match self.mark_set {
    Some(ms) =>
      for i = 0; i < ms.length(); i = i + 1 {
        if ms[i] == mark_type {
          return true
        }
      }
      false
    None => true
  }
}

/// Test whether the given set of marks are allowed in this node.
pub fn NodeType::allows_marks(self : NodeType, marks : Array[Mark]) -> Bool {
  match self.mark_set {
    Some(_) =>
      for i = 0; i < marks.length(); i = i + 1 {
        if not(self.allows_mark_type(marks[i].typ)) {
          return false
        }
      }
      true
    None => true
  }
}

/// Removes the marks that are not allowed in this node from the given set.
pub fn NodeType::allowed_marks(self : NodeType, marks : Array[Mark]) -> Array[Mark] {
  match self.mark_set {
    Some(_) =>
      let mut copy : Array[Mark]? = None
      for i = 0; i < marks.length(); i = i + 1 {
        if not(self.allows_mark_type(marks[i].typ)) {
          if copy == None {
            let mut c : Array[Mark] = []
            for j = 0; j < i; j = j + 1 {
              c.push(marks[j])
            }
            copy = Some(c)
          }
        } else if copy != None {
          copy.unwrap().push(marks[i])
        }
      }
      match copy {
        Some(c) => if c.length() > 0 { c } else { mark_none }
        None => marks
      }
    None => marks
  }
}

// ═══════════════════════════════════════════════════════════════════
// MarkType methods
// ═══════════════════════════════════════════════════════════════════

/// Create a mark of this type.
pub fn MarkType::create(self : MarkType, attrs : Attrs?) -> Mark! {
  match attrs {
    Some(a) =>
      Mark::new(self, compute_attrs(self.attrs, Some(a)))
    None =>
      match self.instance {
        Some(inst) => inst
        None => Mark::new(self, compute_attrs(self.attrs, None))
      }
  }
}

/// Remove marks of this type from the given set.
pub fn MarkType::remove_from_set(
  self : MarkType,
  set : Array[Mark],
) -> Array[Mark] {
  let mut result : Array[Mark] = []
  let mut i = 0
  while i < set.length() {
    if set[i].typ == self {
      i = i + 1
      continue
    }
    result.push(set[i])
    i = i + 1
  }
  result
}

/// Tests whether there is a mark of this type in the given set.
pub fn MarkType::is_in_set(self : MarkType, set : Array[Mark]) -> Mark? {
  for i = 0; i < set.length(); i = i + 1 {
    if set[i].typ == self {
      return Some(set[i])
    }
  }
  None
}

/// Check mark attribute validity.
pub fn MarkType::check_attrs(self : MarkType, attrs : Attrs) -> Unit! {
  check_attrs(self.attrs, attrs, "mark", self.name)
}

/// Queries whether a given mark type is excluded by this one.
pub fn MarkType::excludes(self : MarkType, other : MarkType) -> Bool {
  match self.excluded {
    Some(ex) =>
      for i = 0; i < ex.length(); i = i + 1 {
        if ex[i] == other {
          return true
        }
      }
      false
    None => false
  }
}

// ═══════════════════════════════════════════════════════════════════
// Schema construction
// ═══════════════════════════════════════════════════════════════════

/// Construct a schema from node and mark specs.
pub fn Schema::new(
  node_specs : Map[String, NodeSpec],
  mark_specs : Map[String, MarkSpec],
  top_node : String?,
) -> Schema! {
  let schema = Schema::new_uninitialized()
  schema.spec = SchemaSpec::{ nodes: node_specs, marks: mark_specs, top_node }

  // Compile NodeTypes
  let mut compiled_nodes : Map[String, NodeType] = Map::new()
  for name in node_specs.keys() {
    let spec = node_specs[name]
    let groups = match spec.group {
      Some(g) => g.split(" ").iter().filter(fn(s) { s != "" }).collect()
      None => []
    }
    let attrs = init_attrs(name, spec.attrs)
    let def_attrs = default_attrs(attrs)
    let is_block = not(
      (match spec.inline {
        Some(true) => true
        _ => false
      }) ||
      name == "text",
    )
    let is_text = name == "text"

    compiled_nodes[name] = NodeType::{
      name,
      schema,
      spec,
      groups,
      attrs,
      default_attrs: def_attrs,
      is_block,
      is_text,
      content_match: None,
      inline_content: None,
      mark_set: None,
      is_textblock: None,
      is_leaf: None,
      is_atom: None,
    }
  }

  let top_node_name = match top_node {
    Some(tn) => tn
    None => "doc"
  }
  if not(compiled_nodes.contains(top_node_name)) {
    fail!("Schema is missing its top node type ('\(top_node_name)')")
  }
  if not(compiled_nodes.contains("text")) {
    fail!("Every schema needs a 'text' type")
  }
  // Text nodes should not have attributes
  let text_node = compiled_nodes["text"]
  if text_node.attrs.size() > 0 {
    fail!("The text node type should not have attributes")
  }

  schema.nodes = compiled_nodes

  // Compile MarkTypes
  let mut compiled_marks : Map[String, MarkType] = Map::new()
  let mut rank = 0
  for name in mark_specs.keys() {
    let spec = mark_specs[name]
    let attrs = init_attrs(name, spec.attrs)
    let defs = default_attrs(attrs)
    let instance = match defs {
      Some(d) => Some(Mark::new(
        MarkType::{
          name,
          rank,
          schema,
          spec,
          attrs,
          excluded: None,
          instance: None,
        },
        d,
      ))
      None => None
    }
    compiled_marks[name] = MarkType::{
      name,
      rank,
      schema,
      spec,
      attrs,
      excluded: None,
      instance,
    }
    rank = rank + 1
  }
  schema.marks = compiled_marks

  // Second pass: resolve content expressions and mark sets
  let mut content_expr_cache : Map[String, ContentMatch] = Map::new()
  for name in schema.nodes.keys() {
    let nt = schema.nodes[name]
    if schema.marks.contains(name) {
      fail!("\(name) can not be both a node and a mark")
    }
    let content_expr = match nt.spec.content {
      Some(c) => c
      None => ""
    }
    // Parse content expression
    let cm_content = match content_expr_cache[content_expr] {
      Some(cached) => cached
      None =>
        let parsed = ContentMatch::parse(content_expr, schema.nodes)
        content_expr_cache[content_expr] = parsed
        parsed
    }
    nt.content_match = Some(cm_content)
    nt.inline_content = Some(cm_content.inline_content())

    // Handle linebreak replacement
    match nt.spec.linebreak_replacement {
      Some(true) =>
        match schema.linebreak_replacement {
          Some(_) => fail!("Multiple linebreak nodes defined")
          None =>
            if not(nt.is_inline()) || not(nt.is_leaf()) {
              fail!("Linebreak replacement nodes must be inline leaf nodes")
            }
            schema.linebreak_replacement = Some(nt)
        }
      _ => {}
    }

    // Determine mark set
    nt.mark_set = match nt.spec.marks {
      Some("_") => None  // all marks allowed
      Some("") => Some([])  // no marks
      Some(mark_expr) =>
        let names = mark_expr.split(" ").iter().filter(fn(s) { s != "" }).collect()
        Some(gather_marks(schema, names))
      None =>
        match nt.inline_content {
          Some(true) => None  // all marks allowed
          _ => Some([])  // no marks
        }
    }

    nt.is_textblock = Some(nt.is_block && nt.inline_content() == true)
    nt.is_leaf = Some(
      match nt.content_match {
        Some(cm) => cm.edge_count() == 0
        None => false
      },
    )
    nt.is_atom = Some(
      nt.is_leaf() == true ||
      (match nt.spec.atom {
        Some(true) => true
        _ => false
      }),
    )
  }

  // Resolve mark exclusions
  for name in schema.marks.keys() {
    let mt = schema.marks[name]
    mt.excluded = match mt.spec.excludes {
      Some("") => Some([])
      Some(excl) =>
        let names = excl.split(" ").iter().filter(fn(s) { s != "" }).collect()
        Some(gather_marks(schema, names))
      None => Some([mt])  // default: exclude same type
    }
  }

  // Bind JSON helpers
  schema.node_from_json = fn(json : @json.Json) -> Node {
    Schema::deserialize_node(schema, json).unwrap()
  }
  schema.mark_from_json = fn(json : @json.Json) -> Mark {
    Mark::from_json(schema, Some(json)).unwrap()
  }

  schema.top_node_type = schema.nodes[top_node_name]
  schema.cached = Map::new()

  // Re-link self-references (the schema pointer in node/mark types)
  for name in schema.nodes.keys() {
    schema.nodes[name].schema = schema
  }
  for name in schema.marks.keys() {
    schema.marks[name].schema = schema
  }

  schema
}

fn Schema::new_uninitialized() -> Schema {
  let dummy_map : Map[String, @json.Json] = Map::new()
  // Create a dummy placeholder — will be overwritten
  let dummy_nodes : Map[String, NodeSpec] = Map::new()
  let dummy_marks : Map[String, MarkSpec] = Map::new()
  let dummy_spec = SchemaSpec::{ nodes: dummy_nodes, marks: dummy_marks, top_node: None }
  let dummy_node = NodeType::{
    name: "",
    schema: Schema::dummy(),
    spec: NodeSpec::{},
    groups: [],
    attrs: Map::new(),
    default_attrs: None,
    is_block: true,
    is_text: false,
    content_match: None,
    inline_content: None,
    mark_set: None,
    is_textblock: None,
    is_leaf: None,
    is_atom: None,
  }
  {
    spec: dummy_spec,
    nodes: Map::new(),
    marks: Map::new(),
    top_node_type: dummy_node,
    linebreak_replacement: None,
    node_from_json: fn(_) { Node::dummy() },
    mark_from_json: fn(_) { Mark::new(MarkType::dummy(), Map::new()) },
    cached: Map::new(),
  }
}

fn Schema::dummy() -> Schema {
  Schema::new_uninitialized()
}

fn NodeType::dummy() -> NodeType {
  // Not used — placeholder
  NodeType::{
    name: "",
    schema: Schema::dummy(),
    spec: NodeSpec::{},
    groups: [],
    attrs: Map::new(),
    default_attrs: None,
    is_block: true,
    is_text: false,
    content_match: None,
    inline_content: None,
    mark_set: None,
    is_textblock: None,
    is_leaf: None,
    is_atom: None,
  }
}

fn MarkType::dummy() -> MarkType {
  MarkType::{
    name: "",
    rank: 0,
    schema: Schema::dummy(),
    spec: MarkSpec::{},
    attrs: Map::new(),
    excluded: None,
    instance: None,
  }
}

fn Node::dummy() -> Node {
  Node::new(
    NodeType::dummy(),
    Map::new(),
    fragment_empty,
    mark_none,
  )
}

/// Schema-internal helper: deserialize a node from JSON.
fn Schema::deserialize_node(self : Schema, json : @json.Json) -> Node! {
  Node::from_json(self, json)
}

fn gather_marks(schema : Schema, marks : Array[String]) -> Array[MarkType] {
  let mut found : Array[MarkType] = []
  for i = 0; i < marks.length(); i = i + 1 {
    let name = marks[i]
    match schema.marks[name] {
      Some(mark) => found.push(mark)
      None =>
        // Look up by group
        let mut ok : MarkType? = None
        for prop in schema.marks.keys() {
          let mt = schema.marks[prop]
          if name == "_" ||
            (match mt.spec.group {
              Some(g) =>
                let group_parts : Array[String] = g.split(" ").iter().filter(fn(s) { s != "" }).collect()
                group_parts.iter().any(fn(p) { p == name })
              None => false
            }) {
            ok = Some(mt)
            found.push(mt)
          }
        }
        match ok {
          Some(_) => {}
          None => fail!("Unknown mark type: '\(marks[i])'")
        }
    }
  }
  found
}

/// Create a node in this schema. `type_name` is a string node type name.
pub fn Schema::node(
  self : Schema,
  type_name : String,
  attrs : Attrs?,
  content : Fragment?,
  marks : Array[Mark]?,
) -> Node! {
  guard let Some(typ) = self.nodes[type_name] else {
    fail!("Unknown node type: \(type_name)")
  }
  typ.create_checked(attrs, content, marks)
}

/// Create a text node in this schema.
pub fn Schema::text(self : Schema, text : String, marks : Array[Mark]?) -> Node! {
  let typ = self.nodes["text"]
  let defs = match typ.default_attrs {
    Some(d) => d
    None => Map::new()
  }
  let m = match marks {
    Some(mk) => Mark::set_from(mk)
    None => mark_none
  }
  Node::new_text(typ, defs, text, m)
}

/// Create a mark with the given type name and attributes.
pub fn Schema::mark(self : Schema, type_name : String, attrs : Attrs?) -> Mark! {
  guard let Some(typ) = self.marks[type_name] else {
    fail!("Unknown mark type: \(type_name)")
  }
  typ.create(attrs)
}

/// Look up a node type by name.
pub fn Schema::node_type(self : Schema, name : String) -> NodeType! {
  guard let Some(found) = self.nodes[name] else {
    fail!("Unknown node type: \(name)")
  }
  found
}

// ═══════════════════════════════════════════════════════════════════
// Empty NodeSpec/MarkSpec defaults
// ═══════════════════════════════════════════════════════════════════

pub impl NodeSpec with Default {
  default() -> NodeSpec {
    NodeSpec::{
      content: None,
      marks: None,
      group: None,
      inline: None,
      atom: None,
      attrs: None,
      selectable: None,
      draggable: None,
      code: None,
      whitespace: None,
      defining_as_context: None,
      defining_for_content: None,
      defining: None,
      isolating: None,
      leaf_text: None,
      to_debug_string: None,
      linebreak_replacement: None,
    }
  }
}

pub impl MarkSpec with Default {
  default() -> MarkSpec {
    MarkSpec::{
      attrs: None,
      inclusive: None,
      excludes: None,
      group: None,
      spanning: None,
      code: None,
    }
  }
}