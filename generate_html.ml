open Docjson
open Info
open Doctree
open Typedtree
open Location
open Asttypes
open Cow

open Types
    
let get_path local ?(is_class=false) (p : Path.t) =
  Gentyp_html.path local is_class p
    
let path_to_html = Gentyp_html.html_of_path

let generate_html_path local ?(is_class=false) (p : Path.t) : Html.t =
  let path = get_path local ~is_class:is_class p in
  Gentyp_html.html_of_path path


type doc_env = 
    {current_module_name:string;
     parent_modules:string list (** reversed list B.M.SubM -> ["M"; "B"] *) }

(* doc_env's abstraction layer *)
let new_env module_name = 
  {current_module_name=module_name; parent_modules=[]}

let add_to_env env module_name =
  {current_module_name=module_name; 
   parent_modules=env.current_module_name::env.parent_modules}

let get_full_path_name env =
  String.concat "." (List.rev (env.current_module_name::env.parent_modules))

(* TO REMOVE:
let internal_path = ref []

let generate_submodule name f arg =
  internal_path:=name::(!internal_path);
  let res = f arg in
  internal_path:=List.tl !internal_path;  
  res


let add_internal_reference id =
   Index.add_internal_reference id (List.rev !internal_path)

let rec treat_module_type id = function
  | Mty_ident p -> () (* should do something ? *)
  | Mty_signature msig -> generate_submodule 
    id.Ident.name add_include_references msig
  | Mty_functor (_,_,mtyp) -> treat_module_type id mtyp (* should do more ?*)


and add_include_references sig_list = 
  List.iter 
    (function  
      | Sig_value (id,_)
      | Sig_type (id, _, _) 
      | Sig_exception (id, _) ->
	add_internal_reference id
	  
      | Sig_module (id, mtyp,_) ->
	add_internal_reference id;
	treat_module_type id mtyp

      | Sig_modtype (id, mdecl) -> 
	add_internal_reference id;
	(match mdecl with
	    Modtype_abstract -> ()
	  | Modtype_manifest mtyp -> treat_module_type id mtyp
	)

      | Sig_class (id, _, _)
      | Sig_class_type (id, _, _) -> add_internal_reference id
    ) 
    sig_list      	  
*)      
 
(* TODO add support for references *)
let rec generate_text_element local elem =
  match elem with
    | Raw s -> <:html<$str:s$>>
    | Code s -> <:html<<code class="code">$str:s$</code>&>>
    | PreCode s -> <:html<<pre class="codepre"><code class="code">$str:s$</code></pre>&>>
    | Verbatim s -> <:html<<span class="verbatim">$str:s$</span>&>>
    | Style(sk, t) -> generate_style local sk t
    | List items -> <:html<<ul>$generate_list_items local items$</ul>&>>
    | Enum items -> <:html<<ol>$generate_list_items local items$</ol>&>>
    | Newline -> <:html<<br/>&>>(*should be : <:html<<p>&>>*)
    | Block text -> <:html<<blockquote>$generate_text local text$</blockquote>&>>
    | Title(n, lbl, t) -> generate_title n lbl (generate_text local t)
    | Ref(rk, s, t) -> (* ref check*)
      <:html<TODO reference : $str:s$>>
    | Special_ref _ -> <:html<TODO special ref>> (* raise (Failure "Not implemented") *)
    | Target _ -> <:html<TODO target>> (* raise (Failure "Not implemented") *)

and generate_text local text =
  List.fold_left 
    (fun acc elem -> <:html<$acc$$generate_text_element local elem$>>)
    Html.nil
    text

and generate_list_items local items =
  List.fold_left 
    (fun acc item -> <:html<$acc$<li>$generate_text local item$</li>&>>)
    Html.nil
    items

and generate_style local sk t = 
  let f elem = 
    match sk with
    | SK_bold -> <:html<<b>$elem$</b>&>>
    | SK_italic -> <:html<<i>$elem$</i>&>>
    | SK_emphasize -> <:html<<em>$elem$</em>&>>
    | SK_center -> <:html<<center>$elem$</center>&>>
    | SK_left -> <:html<<div align="left">$elem$</div>&>>
    | SK_right -> <:html<<div align="right">$elem$</div>&>>
    | SK_superscript -> <:html<<sup class="superscript">$elem$</sup>&>>
    | SK_subscript -> <:html<<sub class="subscript">$elem$</sub>&>>
    | SK_custom _ -> <:html<TODO custom>> 
  (*TODO raise (Failure "Not implemented: Custom styles")*)
  in
  f (generate_text local t)

and generate_title n lbl text =
  let sn = (string_of_int n) in
  let ftag id html = match n with
    | 1 -> <:html<<h1 id="$str:id$">$html$</h1>&>>
    | 2 -> <:html<<h2 id="$str:id$">$html$</h2>&>>
    | 3 -> <:html<<h3 id="$str:id$">$html$</h3>&>>
    | 4 -> <:html<<h4 id="$str:id$">$html$</h4>&>>
    | 5 -> <:html<<h5 id="$str:id$">$html$</h5>&>>
    | 6 -> <:html<<h6 id="$str:id$">$html$</h6>&>>
    | n when n > 6 -> 
      let clazz = "h"^sn in <:html<<div class="$str:clazz$">$html$</div>&>>
    | _ -> Html.nil in
  let id = match lbl with 
    | Some s ->  s
    | _ -> sn^"_"^Opam_doc_config.mark_title
  in <:html<<br/>$ftag id text$<br/>&>>
  
let generate_authors local authors = 
  List.fold_left 
    (fun acc author -> <:html<$acc$<span class="author">$str:author$</span>&>>)
    <:html<<b>Author(s): </b>&>>
    authors

let generate_sees local sees = 
  let gen_see (sr, t) = 
    match sr with
    | See_url s -> 
      <:html< <a href="$str:s$">$generate_text local t$</a>&>> (*  class="url" *)
    | See_file s -> 
        <:html<<code class="code">$str:s$ </code>$generate_text local t$>>
    | See_doc s -> 
        <:html<<i class="doc">$str:s$ </i>$generate_text local t$>>
  in
  let elems = 
    List.fold_left 
      (fun acc see -> <:html< $acc$ <li>$gen_see see$</li>&>>)
      Html.nil
      sees in
  <:html<<b>See also</b> <ul>$elems$</ul>&>>

let generate_befores local befores = 
  let gen_before (s, t) =
    <:html<<b>Before $str:s$</b> $generate_text local t$>>
  in
    List.fold_left 
      (fun acc before -> <:html<$acc$$gen_before before$<br/>&>>)
      Html.nil
      befores

let generate_params local params = 
  let gen_param (s, t) =
    <:html<<div class="param_info"><code class="code">$str:s$</code> : $generate_text local t$</div>&>>
  in
    List.fold_left 
      (fun acc param -> <:html<$acc$$gen_param param$&>>)
      Html.nil
      params

let generate_raised local raised = 
  let gen_raised (s, t) =
    <:html<<code>$str:s$</code> $generate_text local t$<br/>&>>
  in
    List.fold_left 
      (fun acc raised -> <:html<$acc$$gen_raised raised$>>)
      Html.nil
      raised


(* TODO add support for custom tags *)
let generate_info local info = 
  let jinfo = 
    match info.i_desc with
	Some t -> generate_text local t
      | None -> Html.nil
  in
  let jinfo = 
    match info.i_authors with
      | [] -> jinfo
      | authors -> 
        <:html<$jinfo$<div class="authors">$generate_authors local authors$</div>&>>
  in
  let jinfo = 
    match info.i_version with
      | None -> jinfo
      | Some s -> 
        <:html<$jinfo$<div class="version">$str:s$</div>&>>
  in
  let jinfo = 
    match info.i_sees with
      | [] -> jinfo
      | sees -> 
	<:html<$jinfo$<div class="see">$generate_sees local sees$</div>&>>
  in
  let jinfo = 
    match info.i_since with
      | None -> jinfo
      | Some s -> 
        <:html<$jinfo$<b>Since</b> $str:s$&>>
  in
  let jinfo = 
    match info.i_before with
      | [] -> jinfo
      | befores -> 
        <:html<$jinfo$$generate_befores local befores$>>
  in
  let jinfo = 
    match info.i_deprecated with
      | None -> jinfo
      | Some t -> 
        <:html<$jinfo$<span class="warning">Deprecated.</span> $generate_text local t$<br/>&>>
  in
  let jinfo = 
    match info.i_params with
      | [] -> jinfo
      | params -> 
        <:html<$jinfo$<div class="parameters">$generate_params local params$</div>&>>
  in
  let jinfo = 
    match info.i_raised_exceptions with
      | [] -> jinfo
      | raised -> 
        <:html<$jinfo$<b>Raises</b> $generate_raised local raised$&>>
  in
  let jinfo = 
    match info.i_return_value with
      | None -> jinfo
      | Some t -> 
	<:html<$jinfo$<b>Returns</b> $generate_text local t$>>
  in
  Html_utils.make_info (Some jinfo)
    
let generate_info_opt local info =
  match info with
    | Some i -> Some (generate_info local i)
    | None -> None

let generate_info_opt2 local info after_info =
  let info = generate_info_opt local info in
  let after_info = generate_info_opt local after_info in
  match info, after_info with
    | None, None -> None
    | Some i, None -> Some i
    | None, Some i -> Some i
    | Some i1, Some i2 -> Some <:html<$i1$$i2$>> (* todo fix the inclusion of comments *)

(* TODO do proper type printing *)
let generate_typ local typ = 
  Gentyp_html.type_scheme local typ.ctyp_type

let generate_typ_param param = 
  let s =
    match param with
	Some {txt=s} -> "'" ^ s
      | None -> "_"
  in
  <:html<$str:s$>>

let generate_class_param param = 
  <:html<$str:"'" ^ param.txt$>>

let generate_variant_constructor local parent_name info (_, {txt=name; _}, args, _) =
  let args = List.map (generate_typ local) args in
  let info = generate_info_opt local info in
  Html_utils.make_variant_cell parent_name name args info

let generate_record_label local parent_name info (_, {txt=name; _}, mut, typ, _) =
  let mut = match mut with Mutable -> true | Immutable -> false in
  let label_type = generate_typ local typ in
  let info = generate_info_opt local info in
  Html_utils.make_record_label_cell parent_name name mut label_type info

(* In the future: give the Typedtree.module_type to substitute the signature with
   the destructive constraint *)
let generate_with_constraint local (path, _, cstr) =
  let path = generate_html_path local path in
  match cstr with
    | Twith_type td -> 
      let typ = 
        match td.typ_manifest with
            Some typ -> generate_typ local typ
          | None -> assert false
      in
      <:html<type $path$ = $typ$>>
    | Twith_typesubst td -> 
      let typ = 
        match td.typ_manifest with
            Some typ -> generate_typ local typ
          | None -> assert false
      in
      <:html<type $path$ := $typ$>>
    | Twith_module(p, _) -> 
      <:html<module $path$ = $generate_html_path local p$>>
    | Twith_modsubst(p, _) ->
      <:html<module $path$ = $generate_html_path local p$>>

let generate_variance = function
  | true, false -> `Positive
  | false, true -> `Negative
  | _, _ -> `None

(* Generate the body of a type declaration *)
let generate_type_kind local parent_name dtk tk =
  
  let infos = 
    match dtk with 
      | Some (Dtype_abstract) | None -> []
      | Some (Dtype_variant infos) | Some (Dtype_record infos) -> infos
  in
  
  
  match tk with
    | Ttype_abstract -> Html.nil
      
    | Ttype_variant cstrs ->
      let rec loop cstrs dcstrs acc =
	match cstrs with
          | ((_, {txt = name; _}, _, _) as cstr) :: rest ->
            let dcstrl, drest = 
              List.partition (fun (n, _) -> n = name) infos 
            in
            let item =
              match dcstrl with
                | dcstr :: _ -> 
		  generate_variant_constructor local parent_name (snd dcstr) cstr 
		| [] -> generate_variant_constructor local parent_name None cstr
            in
            loop rest drest (item :: acc)
          | [] -> 
            if dcstrs <> [] then raise (Failure "generate_type_kind : Unknown Constructor")
            else List.rev acc
      in
      let items = loop cstrs infos [] in
      Html_utils.make_type_table (fun x -> x) items
	
    | Ttype_record lbls ->
       let rec loop lbls dlbls acc =
        match lbls with
          | ((_, {txt = name}, _, _, _) as lbl) :: rest ->
            let dlbll, drest = 
              List.partition (fun (n, _) -> n = name) dlbls 
            in
            let item =
              match dlbll with
                | dlbl :: _ -> 
		  generate_record_label local parent_name (snd dlbl) lbl
		| [] -> generate_record_label local parent_name None lbl
            in
            loop rest drest (item :: acc)
        | [] -> 
            if dlbls <> [] then raise (Failure "Unknown Label")
            else List.rev acc
       in
       let items = loop lbls infos [] in
       Html_utils.make_type_table (fun x -> x) items

(** Returns a signature and a path option in order to wrap the content *)
let rec generate_class_type local dclty clty =
  let rec loop local dclty clty args_acc =
    match dclty, clty.cltyp_desc with
      | (Some Dcty_constr|None), Tcty_constr(path, _, cor_list) ->
	let params = List.map (generate_typ local) cor_list in
	
	let path = get_path local ~is_class:true path in
	let html_path = path_to_html path in
	
	let args = 
	  Html_utils.code "type" (List.fold_left 
				    (fun acc typ -> <:html<$acc$$typ$ -> >>) 
				    Html.nil (List.rev args_acc)) in
	
	let params = 
	  Html_utils.html_of_type_class_param_list
	    params (List.map (fun _ -> `None) params) (* dummy variance list *)
	in

	let body = <:html<$args$$params$$html_path$>> in
	
	body, Some path
	  
      | dclass_sig, Tcty_signature class_sig ->
	let fields : Html.t list = 
	  generate_class_type_fields local 
	    (match dclass_sig with Some Dcty_signature cl -> Some cl | _ -> None)
	    (* The fields are reversed... Why? 
	       Still true? => TEST *)
	    (List.rev class_sig.csig_fields) in
	
	let args = match args_acc with
	  | [] -> Html.nil 
	  | l -> Html_utils.code "type"
	    (List.fold_left (fun acc typ -> <:html<$acc$$typ$ -> >>) Html.nil l)
	in 
	
	let body = let open Html_utils in 
	     <:html<$args$$code "code" (html_of_string "object")$ .. $code "code" (html_of_string "end")$>> in
			
	<:html<$body$$Html_utils.create_class_signature_content fields$>>, None
	  
      | dclass_type, Tcty_fun (_, core_type, sub_class_type) ->
	let arg = generate_typ local core_type in
	let sub_dclass_type = 
	  match dclass_type with 
	    | Some (Dcty_fun dcty) -> Some dcty 
	    | None -> None 
	    | _ -> raise (Failure "generate_class_type : Mismatch") in
	
	loop local sub_dclass_type sub_class_type (arg::args_acc)

      | _, _ -> assert false
  in
  loop local dclty clty []

(* TODO : Double check this function *)
and generate_class_type_fields local dclsigl tclsigl =
    
    let process_class_field local tfield = 
      let open Html_utils in
      match tfield.ctf_desc with
	| Tctf_inher ctyp -> 
	  let ctyp, path = generate_class_type local None ctyp in
	  let signature = make_pre 
	    <:html<$keyword "inherit"$ $ctyp$>> in
	  create_class_container "_inherit_field" signature ctyp path
	| Tctf_val (name, mut_f, virt_f, co_typ) ->  
	  let typ = generate_typ local co_typ in
	  let mut = match mut_f with | Mutable -> true | Immutable -> false in
	  let virt = match virt_f with | Virtual -> true | Concrete -> false in
	  let label = keyword "val" in
	  let label = 
	    if virt then <:html<$label$ $keyword "virtual"$>> else label in
	  let label = 
	    if mut then <:html<$label$ $keyword "mutable"$>> else label in
	  let label = generate_mark Opam_doc_config.mark_attribute name 
	    <:html<$label$ $str:name$>> in
	  make_pre <:html<$label$ : $code "code" typ$>>		   
	| Tctf_meth (name, priv_f, co_typ) -> 
	  let typ = generate_typ local co_typ in
	  let priv = match priv_f with Private -> true | Public -> false in
	  
	  let label = keyword "method" in
	  let label = 
	    if priv then <:html<$label$ $keyword "private"$>> else label in
	  let label = generate_mark Opam_doc_config.mark_method 
	    name <:html<$label$ $str:name$>> in
	  make_pre <:html<$label$ : $code "code" typ$>>
	| Tctf_virt (name, priv_f, co_typ) -> 
	  let typ = generate_typ local co_typ in
	  let priv = match priv_f with Private -> true | Public -> false in
	  
	  let label = keyword "method" in
	  let label = <:html<$label$ $keyword "virtual"$>> in
	  let label = 
	    if priv then <:html<$label$ $keyword "private"$>> else label in
	  let label = generate_mark Opam_doc_config.mark_method 
	    name <:html<$label$ $str:name$>> in
	  make_pre <:html<$label$ : $code "code" typ$>>
	| Tctf_cstr (co_typ1, co_typ2) ->
	  let jtyp1 = generate_typ local co_typ1 in
	  let jtyp2 = generate_typ local co_typ2 in
	  let label = <:html<$jtyp1$ = $jtyp2$>> in
	  let label = <:html<$code "type" label$>> in
	  make_pre <:html<$keyword "constraint"$ $label$>>	  
    in
    
    let generate_class_type_fields_with_doctree local dclsigl tclsigl =
      let rec loop (acc: Html.t list) local dclsigl tclsigl is_stopped =
    	match dclsigl, tclsigl with
	  | [], r -> 
	    Printf.eprintf "generate_class_type_fields mismatch -- processing without doc";
	    List.rev acc @ List.map (process_class_field local) r
	  | { dctf_desc=Dctf_comment
	    ; dctf_info=i1
	    ; dctf_after_info=i2}::r, r2 -> 
	    if is_stopped then
	      loop acc local r r2 is_stopped
	    else 
	      let info = Html_utils.make_info (generate_info_opt2 local i1 i2) in
	      loop (info::acc) local r r2 is_stopped
	  | { dctf_desc=Dctf_stop; _}::r, r2 -> loop acc local r r2 (not is_stopped)
	  | d::r, t::r2 ->
	    begin
	      match d.dctf_desc, t.ctf_desc with
		| Dctf_inher dctyp, Tctf_inher ctyp -> 
		  let item = 
		    let open Html_utils in
		    let ctyp, path = generate_class_type local None ctyp in
		    let signature = make_pre 
		      <:html<$keyword "inherit"$ $ctyp$>> in
		    create_class_container "_inherit_field" signature ctyp path
		  in
		  if is_stopped then
		    loop (item::acc) local r r2 is_stopped
		  else 
		    let info = Html_utils.make_info
		      (generate_info_opt2 local d.dctf_info d.dctf_after_info) in
		    loop (info::item::acc) local r r2 is_stopped
		| Dctf_val _, Tctf_val _ 
		| Dctf_meth _, Tctf_meth _ 
		| Dctf_meth _, Tctf_virt _ 
		| Dctf_cstr, Tctf_cstr _ -> 
		  let item = process_class_field local t in
		  if is_stopped then
		    loop (item::acc) local r r2 is_stopped
		  else 
		    let info =  Html_utils.make_info
		      (generate_info_opt2 local d.dctf_info d.dctf_after_info) in
		    loop (info::item::acc) local r r2 is_stopped
		| _,_ -> 
		  Printf.eprintf "generate_class_type_fields mismatch -- processing without doc";
		  List.rev acc @ List.map (process_class_field local) (t::r2)
	    end
	  | _, [] -> List.rev acc
	    
      in
      loop [] local dclsigl tclsigl false
    in
    
    match dclsigl with
      | Some dclsigl -> generate_class_type_fields_with_doctree local dclsigl tclsigl
      | None ->  List.map (process_class_field local) tclsigl

(** Returns a signature and a path option in order to wrap the content *)
let rec generate_class_struct local dclexpr ci_expr = 
  (* Gros bugs en vue avec args_acc *)
  let rec loop local dclexpr ci_expr args_acc =
    match dclexpr, ci_expr.cl_desc with
      | dclass_struct, Tcl_structure {cstr_fields=fields; _} -> 
	let fields = generate_class_fields local
	  (match dclass_struct with Some (Dcl_structure str) -> Some str | _ -> None)
	  (* don't reverse the fields this time? :l *)
	  fields in
	
	let args = match args_acc with
	  | [] -> Html.nil 
	  | l -> Html_utils.code "type"
	    (List.fold_left (fun acc typ -> <:html<$acc$$typ$ -> >>) Html.nil l)
	in
	let body = 
	  let open Html_utils in 
	      <:html<$args$$code "code" (html_of_string "object")$ .. $code "code" (html_of_string "end")$>> in
		   
	  <:html<$body$$Html_utils.create_class_signature_content fields$>>, None
	  
      | dclass_expr, Tcl_fun (_, pattern, _, class_expr, _) -> 
	let arg = Gentyp.type_scheme local pattern.pat_type in
	
	loop local 
	  (match dclass_expr with Some (Dcl_fun e) -> Some e | _ -> None)
	  class_expr (arg::args_acc)
	  
      | dclass_apply, Tcl_apply (class_expr, list) -> 
	(* Not sure... (neither does ocamldoc) *)
	loop local 
	  (match dclass_apply with Some (Dcl_apply e) -> Some e | _ -> None)
	  class_expr args_acc  

      | dclass_let, Tcl_let (_, _, _, class_expr) -> 
	(* just process through *)
	loop local
	  (match dclass_let with Some (Dcl_let e) -> Some e | _ -> None)
	  class_expr args_acc
	  
      | (Some Dcl_constr | None), Tcl_constraint (class_expr, _, _, _, _) -> 
	(* Weird matching: to double check *)
	let params, path = 
	  match class_expr.cl_desc with 
	    | Tcl_ident (path, _, co_typ_list) -> 
	      let params = List.map 
		(generate_typ local)
		co_typ_list in
	      let path = get_path local ~is_class:true path in
	      params, path
	    | _ -> assert false
	in
	  
	let html_path = path_to_html path in
	let args = 
	  Html_utils.code "type" (List.fold_left 
				    (fun acc typ -> <:html<$acc$$typ$ -> >>) 
				    Html.nil (List.rev args_acc)) in
	let params = 
	  Html_utils.html_of_type_class_param_list
	    params (List.map (fun _ -> `None) params) (* dummy variance list *)
	in

	let body = <:html<$args$$params$$html_path$>> in
	body, Some path

      | dclass_constraint, Tcl_constraint (class_expr, Some ctyp, _, _, _) ->

	let cte, path = loop local 
	  (match dclass_constraint with Some (Dcl_constraint (e,_)) -> Some e | _ -> None)
	  class_expr [] in
	let ctyp, _ = generate_class_type local
	  (match dclass_constraint with Some (Dcl_constraint (_,t)) -> Some t | _ -> None)
	  ctyp in

	let args = match args_acc with
	  | [] -> Html.nil 
	  | l -> Html_utils.code "type"
	    (List.fold_left (fun acc typ -> <:html<$acc$$typ$ -> >>) Html.nil l)
	in 

	<:html<$args$( $cte$ : $ctyp$ )>>, path
	  
      | _,_ -> raise (Failure "generate_class_struct: Mismatch")
  in
  loop local dclexpr ci_expr []

and generate_class_fields local dclstruct tclstruct = assert false
