#include "sqlite_better_trigram.h"

FFI_PLUGIN_EXPORT void* sqlite_better_trigram_get_init(void){
  return (void*)sqlite3_bettertrigram_init;
}
