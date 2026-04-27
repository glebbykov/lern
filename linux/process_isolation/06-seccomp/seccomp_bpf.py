#!/usr/bin/env python3
"""
Минимальный seccomp-bpf фильтр через prctl + ctypes, без libseccomp.
Запрещает выполнение syscall, чей номер передан первым аргументом.
Дальше exec-аем команду из argv[2:].

Usage:
  seccomp_bpf.py <SYSCALL_NR> <CMD> [ARGS...]

Пример:
  seccomp_bpf.py 63 uname -a    # 63 = uname на x86_64
  seccomp_bpf.py 169 date       # 169 = settimeofday
"""
import ctypes, ctypes.util, os, struct, sys

# BPF instruction encoding (linux/filter.h):
#   struct sock_filter { u16 code; u8 jt; u8 jf; u32 k; }
def bpf_stmt(code, k):    return struct.pack("HBBI", code, 0, 0, k)
def bpf_jump(code, k, jt, jf): return struct.pack("HBBI", code, jt, jf, k)

# Опкоды
BPF_LD  = 0x00
BPF_W   = 0x00
BPF_ABS = 0x20
BPF_JMP = 0x05
BPF_JEQ = 0x10
BPF_K   = 0x00
BPF_RET = 0x06

# seccomp constants (linux/seccomp.h)
PR_SET_NO_NEW_PRIVS = 38
PR_SET_SECCOMP = 22
SECCOMP_MODE_FILTER = 2
SECCOMP_RET_KILL_PROCESS = 0x80000000  # KILL вместо ALLOW
SECCOMP_RET_ALLOW = 0x7fff0000

# struct sock_fprog { u16 len; struct sock_filter *filter; }
class sock_fprog(ctypes.Structure):
    _fields_ = [("len", ctypes.c_ushort), ("filter", ctypes.c_void_p)]

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    target_nr = int(sys.argv[1])
    cmd = sys.argv[2:]

    # arch/seccomp.h: смещение syscall nr в seccomp_data — 0
    # Программа: грузим nr (offset 0, 4 байта), сравниваем с target_nr;
    # совпало → KILL_PROCESS, иначе ALLOW.
    prog_bytes = (
        bpf_stmt(BPF_LD | BPF_W | BPF_ABS, 0) +
        bpf_jump(BPF_JMP | BPF_JEQ | BPF_K, target_nr, 0, 1) +
        bpf_stmt(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS) +
        bpf_stmt(BPF_RET | BPF_K, SECCOMP_RET_ALLOW)
    )
    n = len(prog_bytes) // 8
    buf = ctypes.create_string_buffer(prog_bytes)
    fprog = sock_fprog(n, ctypes.cast(buf, ctypes.c_void_p).value)

    libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
    if libc.prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), "PR_SET_NO_NEW_PRIVS")
    if libc.prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, ctypes.byref(fprog)) != 0:
        raise OSError(ctypes.get_errno(), "PR_SET_SECCOMP")

    # фильтр висит на текущем процессе и наследуется через execve
    os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    main()
