open Lwt.Infix

(* a list associating user nicknames to the output channels that write to their connections *)
(* Once we fix the other functions this should change to []*)
let mut = Lwt_mutex.create ()   (* create mutex *)

let sessions = ref [("",Lwt_io.null)] 
exception Quit

(* replace Lwt.return below with code that uses Lwt_list.iter_p to
  print sender: msg on each output channel (excluding the sender's)*)
let rec send_all sender msg =
  Lwt_list.iter_p (fun (user, out) ->     (* go through every element in the sessions list *)
    if sender = user       (* if sender = user *)
      then Lwt.return ()   (* not sending msg since we are excluding the sender *)
    else                   (* if not, *)
      Lwt_io.write_line out (sender ^ ": " ^ msg)) !sessions  (* send msg to every user in the list *)

(* remove a session from the list of sessions: important so we don't try to
   write to a closed connection *)
let remove_session nn =
  sessions := List.remove_assoc nn !sessions;   (* update sessions to remove user *)
  send_all nn "<left chat>" >>= fun () ->       (* send message to user with an message "left chat" *)
  Lwt.return ()

(* Modify to handle the "Quit" case separately, 
closing the channels before removing the session *)
let handle_error e nn inp outp =
  if e = Quit
    then Lwt_mutex.lock mut >>= fun () ->   (* lock mutex *)
      remove_session nn >>= fun () ->       (* call remove function to remove nn *)
      Lwt_mutex.unlock mut;                 (* unlock mutex *)
      Lwt_io.close inp >>= fun () ->        (* close the input *) 
      Lwt_io.close outp                     (* output channels *)
  else Lwt.return ()

(* modify sessions to remove (nn,outp) association, add (new_nn,outp) association.
   also notify other participants of new nickname *)
let change_nn nn outp new_nn = 
  send_all (!nn) ("<changed nickname to " ^ new_nn ^ ">\n"); (* Notify to other users that the nick name has been changed *)
  Lwt_mutex.lock mut >>= fun () ->                       (* Lock the session *)
  (sessions := (new_nn, outp) :: (List.remove_assoc !nn !sessions); (* Update the session list to change nick name *)
  Lwt_mutex.unlock mut;                                  (* Unlock the session *)
  nn := new_nn;    (* update nickname *)
  Lwt.return ()) 

let private_msg sender receiver msg inp outp = 
  Lwt_io.write_line outp "Enter nickname who you want to send msg : " >>= fun () -> (* try to get nickname who sender want to send msg *)
  Lwt_io.read_line inp >>= fun str ->   (* get the msg with str *)
  receiver := str;                      (* assign the msg to receiver *)
  Lwt_list.iter_p (fun (user, out) ->     (* go through every element in the sessions list *)
    if !receiver = user                   (* if receiver = user *)
      then Lwt_io.write_line out ("Private msg from " ^ sender ^ ": " ^ msg) (* send msg to the specific user in the list *)
    else
      Lwt.return ()) !sessions
  
(* update the session list, notify the other users, and update the nick reference from chat_handler. *)

(*  + obtain initial nick(name),
    + add (nick,outp) to !sessions, and
    + announce join to other users *)
let handle_login nr (inp,outp) =
  Lwt_io.write_line outp "Enter initial nick:" >>= fun () -> (* Print a welcome message to outp *)
  Lwt_io.read_line inp >>= fun str ->            (* Read the user's nickname from inp *)
  nr := str;                        (* Assign the new value to the name nick. *)
  Lwt_mutex.lock mut >>= fun () ->
  sessions := (!nr, outp) :: !sessions;         (* update sessions to include the new user and output channel pair *)
  Lwt_mutex.unlock mut;
  send_all !nr "<joined>"             (* announce that the user has joined the chat *)

(* modify handle_input below to detect /q, /n, and /l commands *)
let handle_input (nr:string ref) inp outp l = 
  match (Str.string_before l 2) with
  | "/q" -> Lwt.fail Quit      (* close the input and output channels *)
  | "/n" -> change_nn nr outp (String.trim (Str.string_after l 2)) (* get the new nick name and change it*)
  | "/l" -> Lwt_list.iter_s (fun (nickname, channel) -> Lwt_io.write_line outp nickname) !sessions    (* Lists all users connected to the server *)
  | "/p" -> private_msg !nr (ref "") (String.trim (Str.string_after l 2)) inp outp  (* private messages from one user to another *)
  | _ -> send_all !nr l   (* otherwise, send message *)

let chat_server _ (inp,outp) =
  let nick = ref "" in
  (* replace () below with call to handle_login *)
  let _ = handle_login nick (inp,outp) in
  let rec main_loop () =
    Lwt_io.read_line inp >>= handle_input nick inp outp >>= main_loop in
  Lwt.catch main_loop (fun e -> handle_error e !nick inp outp)
