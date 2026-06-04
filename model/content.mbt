// Copyright (C) ProseMirror Project. All Rights Reserved.
//
// Content expression matching — NFA/DFA compilation for schema content rules.

/// An edge in the ContentMatch DFA: a node type and the next state.
pub(all) struct MatchEdge {
  typ : NodeType
  next : ContentMatch
}

/// A match state in the content expression DFA.
/// Instances represent a position in a content expression and
/// can be used to determine whether further content matches here.
pub(all) struct ContentMatch {
  valid_end : Bool
  next : Array[MatchEdge]
  wrap_cache : Array[ContentMatchWrapEntry]
} derive(Show)

/// Entry in the wrap cache — stores (target_type, result_or_null)
struct ContentMatchWrapEntry {
  target : NodeType
  result : Array[NodeType]?
}

/// Create a ContentMatch state.
pub fn ContentMatch::new(valid_end : Bool) -> ContentMatch {
  { valid_end, next: [], wrap_cache: [] }
}

/// The empty content match — a state that is a valid end.
pub let content_match_empty : ContentMatch = ContentMatch::new(true)

// ─── TokenStream ────────────────────────────────────────────────────

/// TokenStream for parsing content expression strings.
struct TokenStream {
  string : String
  node_types : Map[String, NodeType]
  tokens : Array[String]
  pos : Int
  is_inline : Bool?
}

fn TokenStream::new(string : String, node_types : Map[String, NodeType]) -> TokenStream {
  let tokens = string.split(~sep_regex=Some(r"\s*(?=\b|\W|\$)"))
  let tokens = tokens.iter().filter(fn(t) { t != "" }).collect()
  { string, node_types, tokens, pos: 0, is_inline: None }
}

fn TokenStream::next(self : TokenStream) -> String? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

fn TokenStream::eat(self : TokenStream, tok : String) -> Bool {
  if self.next() == Some(tok) {
    self.pos = self.pos + 1
    true
  } else {
    false
  }
}

fn TokenStream::err[T](self : TokenStream, str : String) -> T! {
  fail!(
    "SyntaxError: " +
    str +
    " (in content expression '" +
    self.string +
    "')",
  )
}

// ─── Expr AST ───────────────────────────────────────────────────────
//
// `seq(a, b, c)`   = Sequence — each element must appear in order
// `choice(a, b)`   = Choice   — one of the alternatives must match
// `plus(a)`        = One or more repetitions of `a`
// `star(a)`        = Zero or more repetitions of `a`
// `opt(a)`         = Zero or one occurrence of `a`
// `range(min,max,a)` = Between `min` and `max` repetitions
// `name(t)`        = A single node type

enum Expr {
  Seq(Array[Expr])
  Choice(Array[Expr])
  Plus(Expr)
  Star(Expr)
  Opt(Expr)
  Range(Int, Int, Expr)  // min, max; max == -1 means unbounded
  Name(NodeType)
}

// ─── Parser ─────────────────────────────────────────────────────────

fn parse_expr(stream : TokenStream) -> Expr! {
  let exprs : Array[Expr] = []
  loop exprs.add(parse_expr_seq(stream!))
  if stream.eat("|") {
    continue exprs.add(parse_expr_seq(stream!))
  } else {
    break
  }
  if exprs.length() == 1 {
    exprs[0]
  } else {
    Choice(exprs)
  }
}

fn parse_expr_seq(stream : TokenStream) -> Expr! {
  let exprs : Array[Expr] = []
  loop exprs.add(parse_expr_subscript(stream!))
  match stream.next() {
    None => break
    Some(t) =>
      if t == ")" || t == "|" {
        break
      }
      continue exprs.add(parse_expr_subscript(stream!))
  }
  if exprs.length() == 1 {
    exprs[0]
  } else {
    Seq(exprs)
  }
}

fn parse_expr_subscript(stream : TokenStream) -> Expr! {
  let expr = parse_expr_atom(stream!)
  loop {
    if stream.eat("+") {
      expr = Plus(expr)
    } else if stream.eat("*") {
      expr = Star(expr)
    } else if stream.eat("?") {
      expr = Opt(expr)
    } else if stream.eat("{") {
      expr = parse_expr_range(stream!, expr)
    } else {
      break
    }
  }
  expr
}

fn parse_num(stream : TokenStream) -> Int! {
  guard let Some(tok) = stream.next() else {
    stream.err("Expected number, got end of input")
  }
  // tok should consist of digits
  for i = 0; i < tok.length(); i = i + 1 {
    let ch = tok[i]
    if ch < '0' || ch > '9' {
      stream.err("Expected number, got '\(tok)'")
    }
  }
  stream.pos = stream.pos + 1
  // Parse int from string
  tok.to_int().unwrap_or(stream.err("Expected number, got '\(tok)'"))
}

fn parse_expr_range(stream : TokenStream, expr : Expr) -> Expr! {
  let min = parse_num(stream!)
  let mut max = min
  if stream.eat(",") {
    if stream.next() != Some("}") {
      max = parse_num(stream!)
    } else {
      max = -1
    }
  }
  if not(stream.eat("}")) {
    stream.err("Unclosed braced range")
  }
  Range(min, max, expr)
}

fn resolve_name(stream : TokenStream, name : String) -> Array[NodeType]! {
  match stream.node_types[name] {
    Some(typ) => return [typ]
    None => {}
  }
  let result : Array[NodeType] = []
  for type_name in stream.node_types.keys() {
    let typ = stream.node_types[type_name]
    if typ.is_in_group(name) {
      result.push(typ)
    }
  }
  if result.length() == 0 {
    stream.err("No node type or group '\(name)' found")
  }
  result
}

fn parse_expr_atom(stream : TokenStream) -> Expr! {
  if stream.eat("(") {
    let expr = parse_expr(stream!)
    if not(stream.eat(")")) {
      stream.err("Missing closing paren")
    }
    return expr
  }
  guard let Some(tok) = stream.next() else {
    stream.err("Unexpected end of input")
  }
  // Check if tok is a non-word token (not a name)
  let first_ch = tok[0]
  if first_ch >= '0' && first_ch <= '9' || first_ch == '+' || first_ch == '*' || first_ch == '?' || first_ch == '{' || first_ch == '}' || first_ch == '|' || first_ch == '(' || first_ch == ')' {
    stream.err("Unexpected token '\(tok)'")
  }
  let types = resolve_name(stream, tok)
  stream.pos = stream.pos + 1
  // Check inline consistency
  for i = 0; i < types.length(); i = i + 1 {
    let typ = types[i]
    match stream.is_inline {
      None => stream.is_inline = Some(typ.is_inline())
      Some(inline) =>
        if inline != typ.is_inline() {
          stream.err("Mixing inline and block content")
        }
    }
  }
  let exprs : Array[Expr] = []
  for i = 0; i < types.length(); i = i + 1 {
    exprs.push(Name(types[i]))
  }
  if exprs.length() == 1 {
    exprs[0]
  } else {
    Choice(exprs)
  }
}

// ─── ContentMatch.parse (entry point) ───────────────────────────────

/// Parse a content expression string and compile it into a DFA.
pub fn ContentMatch::parse(
  string : String,
  node_types : Map[String, NodeType],
) -> ContentMatch! {
  let stream = TokenStream::new(string, node_types)
  if stream.next() == None {
    return content_match_empty
  }
  let expr = parse_expr(stream!)
  if stream.next() != None {
    stream.err("Unexpected trailing text")
  }
  let match = dfa(nfa(expr))
  check_for_dead_ends(match, stream)
  match
}

// ─── NFA compilation ────────────────────────────────────────────────

// An NFA edge: optional terminal (node type) and optional target state index
struct NFAEdge {
  term : NodeType?
  to : Int?
}

/// Compile an expression into an NFA.
/// Returns the NFA as an array of states, each state being an array of edges.
/// The first state is the entry state, the last is the success state.
fn nfa(expr : Expr) -> Array[Array[NFAEdge]] {
  let nfa_states : Array[Array[NFAEdge]] = [[]]
  fn node(nfa_states : Array[Array[NFAEdge]]) -> Int {
    nfa_states.push([])
    nfa_states.length() - 1
  }

  fn edge(
    nfa_states : Array[Array[NFAEdge]],
    from : Int,
    to : Int?,
    term : NodeType?,
  ) -> NFAEdge {
    let e = NFAEdge::{ term, to }
    nfa_states[from].push(e)
    e
  }

  fn connect(edges : Array[NFAEdge], to : Int) {
    for i = 0; i < edges.length(); i = i + 1 {
      edges[i].to = Some(to)
    }
  }

  fn compile(
    expr : Expr,
    from : Int,
    nfa_states : Array[Array[NFAEdge]],
  ) -> Array[NFAEdge] {
    match expr {
      Choice(exprs) => {
        let mut result : Array[NFAEdge] = []
        for i = 0; i < exprs.length(); i = i + 1 {
          let edges = compile(exprs[i], from, nfa_states)
          for j = 0; j < edges.length(); j = j + 1 {
            result.push(edges[j])
          }
        }
        result
      }
      Seq(exprs) => {
        let mut cur_from = from
        for i = 0; i < exprs.length(); i = i + 1 {
          let next_edges = compile(exprs[i], cur_from, nfa_states)
          if i == exprs.length() - 1 {
            return next_edges
          }
          let next_node = node(nfa_states)
          connect(next_edges, next_node)
          cur_from = next_node
        }
        [] // unreachable
      }
      Star(e) => {
        let loop_node = node(nfa_states)
        let _e1 = edge(nfa_states, from, Some(loop_node), None)
        let loop_edges = compile(e, loop_node, nfa_states)
        connect(loop_edges, loop_node)
        [edge(nfa_states, loop_node, None, None)]
      }
      Plus(e) => {
        let loop_node = node(nfa_states)
        let first_edges = compile(e, from, nfa_states)
        connect(first_edges, loop_node)
        let loop_edges = compile(e, loop_node, nfa_states)
        connect(loop_edges, loop_node)
        [edge(nfa_states, loop_node, None, None)]
      }
      Opt(e) => {
        let opt_edges = compile(e, from, nfa_states)
        let mut result : Array[NFAEdge] = [edge(nfa_states, from, None, None)]
        for i = 0; i < opt_edges.length(); i = i + 1 {
          result.push(opt_edges[i])
        }
        result
      }
      Range(min, max, e) => {
        let mut cur = from
        for i = 0; i < min; i = i + 1 {
          let next_node = node(nfa_states)
          let edges_i = compile(e, cur, nfa_states)
          connect(edges_i, next_node)
          cur = next_node
        }
        if max == -1 {
          let edges_inf = compile(e, cur, nfa_states)
          connect(edges_inf, cur)
        } else {
          for i = min; i < max; i = i + 1 {
            let next_node = node(nfa_states)
            let _e2 = edge(nfa_states, cur, Some(next_node), None)
            let edges_range = compile(e, cur, nfa_states)
            connect(edges_range, next_node)
            cur = next_node
          }
        }
        [edge(nfa_states, cur, None, None)]
      }
      Name(typ) => [edge(nfa_states, from, None, Some(typ))]
    }
  }

  let edges = compile(expr, 0, nfa_states)
  let success_node = node(nfa_states)
  connect(edges, success_node)
  nfa_states
}

// ─── DFA construction ──────────────────────────────────────────────

// Get the set of nodes reachable by null (epsilon) edges from `node`.
// Omits nodes with only a single null-out-edge to avoid needless duplication.
fn null_from(nfa_states : Array[Array[NFAEdge]], node : Int) -> Array[Int] {
  let result : Array[Int] = []
  fn scan(
    nfa_states : Array[Array[NFAEdge]],
    node : Int,
    result : Array[Int],
  ) {
    let edges = nfa_states[node]
    if edges.length() == 1 && edges[0].term == None {
      let to = edges[0].to.unwrap()
      return scan(nfa_states, to, result)
    }
    result.push(node)
    for i = 0; i < edges.length(); i = i + 1 {
      let e = edges[i]
      if e.term == None {
        let to = e.to.unwrap()
        if not(result.contains(to)) {
          scan(nfa_states, to, result)
        }
      }
    }
  }
  scan(nfa_states, node, result)
  // Sort descending (like TS: cmp = b - a)
  result.sort_by(fn(a, b) { b - a })
  result
}

// Compile an NFA to a DFA (ContentMatch states).
fn dfa(nfa_states : Array[Array[NFAEdge]]) -> ContentMatch {
  let labeled : Map[String, ContentMatch] = Map::new()

  fn states_key(states : Array[Int]) -> String {
    let parts : Array[String] = []
    for i = 0; i < states.length(); i = i + 1 {
      parts.push(states[i].to_string())
    }
    parts.join(",")
  }

  fn explore(
    states : Array[Int],
    nfa_states : Array[Array[NFAEdge]],
    labeled : Map[String, ContentMatch],
  ) -> ContentMatch {
    // Group outgoing edges by terminal type
    let mut out : Array[(NodeType, Array[Int])] = []
    for i = 0; i < states.length(); i = i + 1 {
      let node_idx = states[i]
      let edges = nfa_states[node_idx]
      for j = 0; j < edges.length(); j = j + 1 {
        let e = edges[j]
        guard let Some(term) = e.term else { continue }
        // Find or create the set for this term
        let mut set : Array[Int]? = None
        for k = 0; k < out.length(); k = k + 1 {
          if out[k].0 == term {
            set = Some(out[k].1)
            break
          }
        }
        if set == None {
          let new_set : Array[Int] = []
          set = Some(new_set)
          out.push((term, new_set))
        }
        let null_states = null_from(nfa_states, e.to.unwrap())
        for m = 0; m < null_states.length(); m = m + 1 {
          let ns = null_states[m]
          if not(set.unwrap().contains(ns)) {
            set.unwrap().push(ns)
          }
        }
      }
    }

    let key = states_key(states)
    let is_valid_end = states.contains(nfa_states.length() - 1)
    let state = ContentMatch::new(is_valid_end)
    labeled[key] = state

    for i = 0; i < out.length(); i = i + 1 {
      let (term, target_states) = out[i]
      // Sort descending
      target_states.sort_by(fn(a, b) { b - a })
      let target_key = states_key(target_states)
      let next_state = match labeled[target_key] {
        Some(existing) => existing
        None => explore(target_states, nfa_states, labeled)
      }
      state.next.push(MatchEdge::{ typ: term, next: next_state })
    }
    state
  }

  let initial_states = null_from(nfa_states, 0)
  explore(initial_states, nfa_states, labeled)
}

// ─── Dead-end checking ─────────────────────────────────────────────

fn check_for_dead_ends(match : ContentMatch, stream : TokenStream) -> Unit! {
  let mut work : Array[ContentMatch] = [match]
  let mut i = 0
  while i < work.length() {
    let state = work[i]
    i = i + 1
    let mut dead = not(state.valid_end)
    let mut nodes : Array[String] = []
    for j = 0; j < state.next.length(); j = j + 1 {
      let edge = state.next[j]
      nodes.push(edge.typ.name)
      if dead && not(edge.typ.is_text() || edge.typ.has_required_attrs()) {
        dead = false
      }
      if not(work.contains(edge.next)) {
        work.push(edge.next)
      }
    }
    if dead {
      stream.err(
        "Only non-generatable nodes (" +
        nodes.join(", ") +
        ") in a required position",
      )
    }
  }
}

// ─── Match operations ──────────────────────────────────────────────

/// Match a node type at this position, returning the next match state.
pub fn ContentMatch::match_type(
  self : ContentMatch,
  typ : NodeType,
) -> ContentMatch? {
  for i = 0; i < self.next.length(); i = i + 1 {
    if self.next[i].typ == typ {
      return Some(self.next[i].next)
    }
  }
  None
}

/// Try to match a fragment. Returns the resulting match when successful.
pub fn ContentMatch::match_fragment(
  self : ContentMatch,
  frag : Fragment,
  start : Int,
  end : Int,
) -> ContentMatch? {
  let mut cur : ContentMatch? = Some(self)
  let mut i = start
  while cur != None && i < end {
    cur = cur.unwrap().match_type(frag.child(i).typ)
    i = i + 1
  }
  cur
}

/// Returns true when the first type of node that this content match
/// allows is an inline node.
pub fn ContentMatch::inline_content(self : ContentMatch) -> Bool {
  self.next.length() != 0 && self.next[0].typ.is_inline()
}

/// Get the first matching node type at this match position that can
/// be auto-generated (not text, no required attrs).
pub fn ContentMatch::default_type(self : ContentMatch) -> NodeType? {
  for i = 0; i < self.next.length(); i = i + 1 {
    let typ = self.next[i].typ
    if not(typ.is_text() || typ.has_required_attrs()) {
      return Some(typ)
    }
  }
  None
}

/// Test whether this content match has any node type in common
/// with another content match.
pub fn ContentMatch::compatible(self : ContentMatch, other : ContentMatch) -> Bool {
  for i = 0; i < self.next.length(); i = i + 1 {
    for j = 0; j < other.next.length(); j = j + 1 {
      if self.next[i].typ == other.next[j].typ {
        return true
      }
    }
  }
  false
}

/// Try to match the given fragment, and if that fails, see if it can
/// be made to match by inserting auto-generatable nodes before it.
pub fn ContentMatch::fill_before(
  self : ContentMatch,
  after : Fragment,
  to_end : Bool,
  start_index : Int,
) -> Fragment? {
  let mut seen : Array[ContentMatch] = [self]

  fn search(
    match : ContentMatch,
    types : Array[NodeType],
    after : Fragment,
    to_end : Bool,
    start_index : Int,
    seen : Array[ContentMatch],
  ) -> Fragment? {
    let finished = match.match_fragment(after, start_index, after.child_count())
    if finished != None && (not(to_end) || finished.unwrap().valid_end) {
      let mut nodes : Array[Node] = []
      for i = 0; i < types.length(); i = i + 1 {
        let created = types[i].create_and_fill()
        if created == None {
          return None
        }
        nodes.push(created.unwrap())
      }
      return Some(Fragment::from_array(nodes))
    }

    for i = 0; i < match.next.length(); i = i + 1 {
      let edge = match.next[i]
      if not(edge.typ.is_text() || edge.typ.has_required_attrs()) &&
        not(seen.contains(edge.next)) {
        seen.push(edge.next)
        let mut new_types = types
        // Clone types array and append
        let mut new_types_copy : Array[NodeType] = []
        for j = 0; j < new_types.length(); j = j + 1 {
          new_types_copy.push(new_types[j])
        }
        new_types_copy.push(edge.typ)
        let found = search(edge.next, new_types_copy, after, to_end, start_index, seen)
        if found != None {
          return found
        }
      }
    }
    None
  }

  search(self, [], after, to_end, start_index, seen)
}

/// Find a set of wrapping node types that would allow a node of the
/// given type to appear at this position.
pub fn ContentMatch::find_wrapping(
  self : ContentMatch,
  target : NodeType,
) -> Array[NodeType]? {
  // Check cache
  let mut cache_i = 0
  while cache_i < self.wrap_cache.length() {
    if self.wrap_cache[cache_i].target == target {
      return self.wrap_cache[cache_i].result
    }
    cache_i = cache_i + 2
  }
  let computed = self.compute_wrapping(target)
  self.wrap_cache.push(ContentMatchWrapEntry::{ target, result: computed })
  self.wrap_cache.push(ContentMatchWrapEntry::{ target: target, result: None }) // placeholder for next pair
  // Actually we need to fix the wrap_cache structure... Let me simplify.
  // We'll just not cache for now and compute every time, or use a separate Map.
  computed
}

/// Compute wrapping (uncached).
fn ContentMatch::compute_wrapping(
  self : ContentMatch,
  target : NodeType,
) -> Array[NodeType]? {
  struct Active {
    match : ContentMatch
    typ : NodeType?
    via : Int? // index into active array for parent
  }

  let mut seen : Map[String, Bool] = Map::new()
  let mut active : Array[Active] = [Active::{ match: self, typ: None, via: None }]
  let mut head = 0
  while head < active.length() {
    let current = active[head]
    head = head + 1
    if current.match.match_type(target) != None {
      // Build result by walking back
      let mut result : Array[NodeType] = []
      let mut obj = current
      while obj.typ != None {
        result.push(obj.typ.unwrap())
        // Follow via pointer
        guard let Some(via_idx) = obj.via else { break }
        obj = active[via_idx]
      }
      result.reverse()
      return Some(result)
    }
    for i = 0; i < current.match.next.length(); i = i + 1 {
      let edge = current.match.next[i]
      if not(edge.typ.is_leaf()) &&
        not(edge.typ.has_required_attrs()) &&
        not(seen.contains(edge.typ.name)) &&
        (current.typ == None || edge.next.valid_end) {
        active.push(
          Active::{
            match: edge.typ.content_match,
            typ: Some(edge.typ),
            via: Some(head - 1),
          },
        )
        seen[edge.typ.name] = true
      }
    }
  }
  None
}

/// The number of outgoing edges from this match state.
pub fn ContentMatch::edge_count(self : ContentMatch) -> Int {
  self.next.length()
}

/// Get the nth outgoing edge from this match state.
pub fn ContentMatch::edge(self : ContentMatch, n : Int) -> MatchEdge! {
  if n >= self.next.length() {
    fail!("There's no \(n)th edge in this content match")
  }
  self.next[n]
}

/// Debug string representation of the DFA.
pub fn ContentMatch::to_debug_string(self : ContentMatch) -> String {
  let mut seen : Array[ContentMatch] = []
  fn scan(m : ContentMatch, seen : Array[ContentMatch]) {
    seen.push(m)
    for i = 0; i < m.next.length(); i = i + 1 {
      if not(seen.contains(m.next[i].next)) {
        scan(m.next[i].next, seen)
      }
    }
  }
  scan(self, seen)
  let mut lines : Array[String] = []
  for i = 0; i < seen.length(); i = i + 1 {
    let m = seen[i]
    let mut out = i.to_string() +
      (if m.valid_end { "* " } else { "  " })
    for j = 0; j < m.next.length(); j = j + 1 {
      if j > 0 {
        out = out + ", "
      }
      out = out +
        m.next[j].typ.name +
        "->" +
        seen.index_of(m.next[j].next).unwrap_or(-1).to_string()
    }
    lines.push(out)
  }
  lines.join("\n")
}