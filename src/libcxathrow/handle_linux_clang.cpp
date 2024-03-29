#include "shared.hpp"

#include <cxxabi.h>
#include <dlfcn.h>
CxaThrowType origCxaThrow = nullptr;

extern "C" void
    __cxa_throw /*NOLINT*/ (void *thrown_exception, std::type_info *typeinfo,
                            void(_GLIBCXX_CDTOR_CALLABI *dest)(void *)) {
  if (origCxaThrow == nullptr) {
    origCxaThrow = (CxaThrowType)dlsym(RTLD_NEXT, "__cxa_throw");
  }
  logExceptionType(thrown_exception, typeinfo);
  doBacktrace();
  origCxaThrow(thrown_exception, typeinfo, dest);
}
