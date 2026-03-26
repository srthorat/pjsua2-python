#ifndef PJSUA2_PYTHON_OPENSSL_COMPAT_1_0_H
#define PJSUA2_PYTHON_OPENSSL_COMPAT_1_0_H

#include <openssl/opensslv.h>

#if OPENSSL_VERSION_NUMBER < 0x10100000L

#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <stdlib.h>

static inline EVP_CIPHER_CTX *pjsua2_compat_EVP_CIPHER_CTX_new(void) {
  EVP_CIPHER_CTX *ctx = (EVP_CIPHER_CTX *)malloc(sizeof(*ctx));
  if (ctx != NULL) {
    EVP_CIPHER_CTX_init(ctx);
  }
  return ctx;
}

static inline void pjsua2_compat_EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *ctx) {
  if (ctx != NULL) {
    EVP_CIPHER_CTX_cleanup(ctx);
    free(ctx);
  }
}

static inline HMAC_CTX *pjsua2_compat_HMAC_CTX_new(void) {
  HMAC_CTX *ctx = (HMAC_CTX *)malloc(sizeof(*ctx));
  if (ctx != NULL) {
    HMAC_CTX_init(ctx);
  }
  return ctx;
}

static inline void pjsua2_compat_HMAC_CTX_free(HMAC_CTX *ctx) {
  if (ctx != NULL) {
    HMAC_CTX_cleanup(ctx);
    free(ctx);
  }
}

#define EVP_CIPHER_CTX_new pjsua2_compat_EVP_CIPHER_CTX_new
#define EVP_CIPHER_CTX_free pjsua2_compat_EVP_CIPHER_CTX_free
#define EVP_CIPHER_CTX_reset EVP_CIPHER_CTX_cleanup
#define HMAC_CTX_new pjsua2_compat_HMAC_CTX_new
#define HMAC_CTX_free pjsua2_compat_HMAC_CTX_free

#endif

#endif