
#include <stdio.h>
#if defined(WIN32)
#define _UNICODE
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <io.h>
#include <direct.h>
#else
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <fcntl.h>
#endif
typedef int kk_file_t;

#ifdef WIN32
typedef struct _stat64  kk_stat_t;
#else
typedef struct stat     kk_stat_t;
#endif

static int kk_posix_open(kk_string_t path, int flags, int create_perm, kk_file_t* f, kk_context_t* ctx) {
  *f = 0;
#ifdef WIN32
  kk_with_string_as_qutf16w_borrow(path, wpath, ctx) {
    *f = _wopen(wpath, flags, create_perm);
  }
#else
  kk_with_string_as_qutf8_borrow(path, bpath, ctx) {
    *f = open(bpath, flags, create_perm);
  }
#endif
  kk_string_drop(path,ctx);
  return (*f < 0 ? errno : 0);
}

static int kk_posix_fstat(kk_file_t f, kk_stat_t* st) {
  #ifdef WIN32
    return (_fstat64(f, st) < 0 ? errno : 0);
  #else
    return (fstat(f, st) < 0 ? errno : 0);
  #endif
}

static kk_std_core_types__maybe kk_file_modified(kk_string_t filepath, kk_context_t* ctx) {
  int inp = 0;
  int out = 0;

  // stat and create/overwrite target
  kk_stat_t finfo = { 0 };
  int err = 0;
  if ((err = kk_posix_open(filepath, O_RDONLY, 0, &inp, ctx)) != 0) {
    return kk_std_core_types__new_Nothing(ctx);
  }
  if ((err = kk_posix_fstat(inp, &finfo)) != 0) {
    close(inp);
    return kk_std_core_types__new_Nothing(ctx);
  }
#ifdef WIN32
  return kk_std_core_types__new_Just(kk_integer_box(kk_integer_from_int(finfo.st_mtime, ctx),ctx), ctx);
#else
  return kk_std_core_types__new_Just(kk_integer_box(kk_integer_from_int(finfo.st_mtimespec.tv_sec, ctx),ctx), ctx);
#endif
}