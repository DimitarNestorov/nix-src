(module
  ;; =========================
  ;; WASI imports
  ;; =========================
  (import "env" "warn" (func $warn (param i32 i32)))

  (import "wasi_snapshot_preview1" "path_open"
    (func $path_open
      (param
        i32 ;; dirfd
        i32 ;; dirflags
        i32 ;; path ptr
        i32 ;; path len
        i32 ;; oflags
        i64 ;; rights base
        i64 ;; rights inheriting
        i32 ;; fdflags
        i32 ;; opened fd out ptr
      )
      (result i32)
    )
  )

  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write
      (param
        i32 ;; fd
        i32 ;; iovs ptr
        i32 ;; iovs len
        i32 ;; nwritten ptr
      )
      (result i32)
    )
  )

  ;; =========================
  ;; Memory
  ;; =========================

  (memory 1)
  (export "memory" (memory 0))

  ;; =========================
  ;; Static write buffer
  ;; =========================

  ;; iovec structure at offset 0:
  ;; struct {
  ;;   void* buf = 32;
  ;;   size_t len = 35;
  ;; }
  (data (i32.const 0)
    "\32\00\00\00" ;; ptr = 50 in hex
    "\23\00\00\00" ;; len = 35 in hex
  )

  (data (i32.const 50) "Hello from builtin Nix WASM builder")

  ;; =========================
  ;; _start
  ;; =========================

  (func $_start (export "_start")
  	(local $err i32)

    (call $warn
      (i32.const 50) 	;; ptr
      (i32.const 35) ;; length
    )
    (call $warn
      (i32.const 200) 	;; ptr
      (i32.load (i32.const 100)) ;; load len from memory[100]
    )

    ;; path_open(
    ;;   dirfd=3,
    ;;   dirflags=0,
    ;;   path_ptr=200,
    ;;   path_len=memory[100],
    ;;   oflags=O_CREAT,
    ;;   rights_base=FD_WRITE,
    ;;   rights_inheriting=FD_WRITE,
    ;;   fdflags=0,
    ;;   opened_fd_out=768
    ;; )

    ;; --- path_open with captured result ---
    (local.set $err
      (call $path_open
        i32.const 3  ;; preopened dir
        i32.const 0   ;; dirflags
        i32.const 200    ;; path ptr = memory offset 200
        i32.const 100
        i32.load       ;; path length
        i32.const 1    ;; O_CREAT
        i64.const 64   ;; RIGHTS_FD_WRITE
        i64.const 64    ;; RIGHTS_FD_WRITE inheriting
        i32.const 0     ;; fdflags
        i32.const 768   ;; where opened fd will be stored
      )
    )


    ;; fd_write(
    ;;   fd=memory[768],
    ;;   iovs=0,
    ;;   iovs_len=1,
    ;;   nwritten=800
    ;; )
    i32.const 768
    i32.load             ;; opened fd
    i32.const 0        ;; iovec ptr
    i32.const 1          ;; iovec count
    i32.const 800        ;; nwritten out
    call $fd_write
    drop
  )
)