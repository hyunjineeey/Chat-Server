# Let's chat

## Overview

This is a chat program that you can send a message to someone.

## How to Run

```
% ocamlfind ocamlc -package lwt -package lwt.unix -linkpkg -o server str.cma funSrvMain.ml funSrv.ml
% ./server
```

- It will listen for and accept network connections, but won't do anything with the user's input, or write anything at all.

- You need to open another terminal and try `nc localhost 16384` to join the chat.

## How to "fun" chat?

- The `quit` command, `/q`: quitting should cause the user's thread to
  close the input and output channels, then remove the user from the
  `sessions` list.

- The `newnick` command, `/n`: allows a user to change her `nick name` to the string following `/n `.

- The list users command, `/l`: lists all users connected to the
  server.

- You can send your private messages to another user using `/p`.

  1. Send message with start `/p` and then type msg that you want to send to specific user.

     ```
     % /p Hi! How are you?
     ```

  2. It will then ask you who do you want to send the msg and you should type his/her nickname.

     ```
     % Enter nickname who you want to send msg : Jacob
     ```

  3. Finally, it will send the private msg to the user you typed! How fun!

## Demo

If you want to see quick demo for this project, watch this : https://youtu.be/8Csnp6ynyqc
