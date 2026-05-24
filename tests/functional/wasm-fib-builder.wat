(module
  ;; =========================
  ;; WASI import
  ;; =========================
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32))
  )

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

  (import "env" "warn" (func $warn (param i32 i32)))
  
  (memory 1)
  (export "memory" (memory 0))

  ;; =========================
  ;; fib(n)
  ;; =========================
  (func $fib (param $n i32) (result i32)
    (if (result i32)
      (i32.le_s (local.get $n) (i32.const 1))
      (then (i32.const 1))
      (else
        (i32.add
          (call $fib (i32.sub (local.get $n) (i32.const 1)))
          (call $fib (i32.sub (local.get $n) (i32.const 2)))
        )
      )
    )
  )

  ;; =========================
  ;; int -> decimal string
  ;; writes digits into memory backwards
  ;; returns pointer to string start + length via globals
  ;; =========================

  (global $buf_ptr (mut i32) (i32.const 50))
  (global $buf_len (mut i32) (i32.const 0))

  (func $itoa (param $x i32)
    (local $n i32)
    (local $rem i32)
    (local $p i32)

    (local.set $n (local.get $x))
    (local.set $p (i32.const 100))
    (global.set $buf_len (i32.const 0))

    ;; handle zero explicitly
    (if (i32.eq (local.get $n) (i32.const 0))
      (then
        (i32.store8 (local.get $p) (i32.const 48))
        (global.set $buf_len (i32.const 1))
        (return)
      )
    )

    (block $done
      (loop $loop
        (br_if $done (i32.eq (local.get $n) (i32.const 0)))

        (local.set $rem (i32.rem_u (local.get $n) (i32.const 10)))
        (local.set $n (i32.div_u (local.get $n) (i32.const 10)))

        (local.set $p (i32.sub (local.get $p) (i32.const 1)))

        (i32.store8
          (local.get $p)
          (i32.add (local.get $rem) (i32.const 48))
        )

        (global.set $buf_len
          (i32.add (global.get $buf_len) (i32.const 1))
        )

        br $loop
      )
    )

    (global.set $buf_ptr (local.get $p))
  )

  ;; =========================
  ;; WASI entry point
  ;; =========================
  (func (export "_start")
    (local $res i32)

    (call $warn
      (i32.const 200) 	;; ptr
      (i32.const 50) ;; length
    )

    ;; fib(29)
    (local.set $res (call $fib (i32.const 48)))


    ;; convert to ASCII
    (call $itoa (local.get $res))

    (call $warn
      (global.get $buf_ptr) 	;; ptr
      (global.get $buf_len) ;; length
    )

    ;; iovec[0].ptr
    (i32.store (i32.const 0) (global.get $buf_ptr))
    ;; iovec[0].len
    (i32.store (i32.const 4) (global.get $buf_len))


    ;; --- path_open with captured result ---
    (call $path_open
      (i32.const 3)  ;; preopened dir
      (i32.const 0)   ;; dirflags
      (i32.const 200)    ;; path ptr = memory offset 200
      (i32.load (i32.const 100)) ;; path length
      (i32.const 1)    ;; O_CREAT
      (i64.const 64)   ;; RIGHTS_FD_WRITE
      (i64.const 64)    ;; RIGHTS_FD_WRITE inheriting
      (i32.const 0)     ;; fdflags
      (i32.const 768)   ;; where opened fd will be stored
    )

    ;; fd_write(fd=1 stdout)
    (call $fd_write
      (i32.load (i32.const 768))
      (i32.const 0)
      (i32.const 1)
      (i32.const 800)
    )

    drop
    drop
  )
)