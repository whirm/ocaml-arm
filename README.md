ocaml-arm
=============

Ocaml cross-compiler for ARM.

Heavily based on [ocaml-android](https://github.com/vouillon/ocaml-android) from [Jerome Vouillon](https://github.com/vouillon/).

## Building:

On a Debian or derivative distro, the following steps need to be taken:

```bash
sudo dpkg --add-architecture armhf
sudo dpkg --add-architecture i386 # Only if on amd64.
sudo apt-get update
sudo apt-get install gcc-4.9-arm-linux-gnueabihf gcc-arm-linux-gnueabihf libc6-dev:armhf libgcc-4.9-dev:armhf linux-libc-dev:i386 opam
opam init # And follow the instructions printed.
opam switch 4.02.1 # It also works with 4.02.0, but I still have to redo the patches for 4.02.2.
eval `opam config env`
opam install ocaml-src
```

And then just clone this repo and run make:

```bash
git clone https://github.com/whirm/ocaml-arm
cd ocaml-arm
make
```

You will find the final binaries installed in ```~/.opam/4.02.0/bin/arm-linux-gnueabihf*```

##### Some notes from the original project:

There are a few pitfalls regarding bytecode programs.  First, if you
link them without the `-custom` directive, you will need to use
`ocamlrun` explicitly to run them. Second, the `ocamlmklib` command
produces shared libraries `dll*.so` which are not usable. Thus, you
need to use the `-custom` directive to successfully link bytecode
programs that uses libraries with mixed C / OCaml code. Shared
libraries should eventually be disabled, but at the moment, the
`ocamlbuild` plugin of `oasis` requires them to be created.

Many thanks to Keigo Imai for his OCaml 3.12 cross-compiler patches.
