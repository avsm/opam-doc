(** MLI doc *)

(** type t kikoo kikoo
    @author moi
*)
type (+'a, 'b) t

(** Foo identity 
    @author ookok
*)

type testz = [ `A | `B | `C ]

val foo : 'a -> 'a

(** Descr liste l 
    @see 'test.ml' seeinfo
    @see <infsup> seeinfo2
    @see "guill" seeinfo3
*)
val l : int list

type testCOMM = 
    A of int * float (** comm pour A of int * float *)
  | B of float * int (** comm pour B of float * int *)

type testc = private A of int * float | B of float

type testd = int

type t2 = int

type record = {a:int; mutable b:float}

type ('a,'b) test constraint 'a = testc constraint 'b = int
