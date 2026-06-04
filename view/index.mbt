
pub type Element


pub struct EditorView {
  place : String
}


pub fn EditorView::new(place : String)->EditorView{
  {place,}
}


pub fn EditorView::find_element_by_id(id : String)->Unit{
  @ffi.find_element_by_id(id) |> ignore()
  
}
