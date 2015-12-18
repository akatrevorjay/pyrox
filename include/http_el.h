#ifndef http_parser_h
#define http_parser_h

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <stdint.h>

#define HTTP_EL_VERSION_MAJOR 0
#define HTTP_EL_VERSION_MINOR 1

#define HTTP_MAX_HEADER_SIZE (80 * 1024)


// Type defs
typedef struct pbuffer pbuffer;
typedef struct http_parser http_parser;
typedef struct http_parser_settings http_parser_settings;

typedef int (*http_data_cb) (http_parser*, const char *at, size_t length);
typedef int (*http_cb) (http_parser*);


// Enumerations
enum http_parser_type {
    HTTP_REQUEST,
    HTTP_RESPONSE
};

enum http_parser_options {
    OPT_PROXY_PROTOCOL  = 1 << 0,
};

enum flags {
    F_CHUNKED               = 1 << 0,
    F_CONNECTION_KEEP_ALIVE = 1 << 1,
    F_CONNECTION_CLOSE      = 1 << 2,
    F_SKIPBODY              = 1 << 3,
    F_TRAILING              = 1 << 4
};


#define HTTP_EL_ERROR_MAP(XX) \
  XX(1, UNCAUGHT, "UNCAUGHT") \
  XX(2, BAD_PARSER_TYPE, "BAD_PARSER_TYPE") \
  XX(3, BAD_STATE, "BAD_STATE") \
  XX(4, BAD_PATH_CHARACTER, "BAD_PATH_CHARACTER") \
  XX(5, BAD_HTTP_VERSION_HEAD, "BAD_HTTP_VERSION_HEAD") \
  XX(6, BAD_HTTP_VERSION_MAJOR, "BAD_HTTP_VERSION_MAJOR") \
  XX(7, BAD_HTTP_VERSION_MINOR, "BAD_HTTP_VERSION_MINOR") \
  XX(8, BAD_HEADER_TOKEN, "BAD_HEADER_TOKEN") \
  XX(9, BAD_CONTENT_LENGTH, "BAD_CONTENT_LENGTH") \
  XX(10, BAD_CHUNK_SIZE, "BAD_CHUNK_SIZE") \
  XX(11, BAD_DATA_AFTER_CHUNK, "BAD_DATA_AFTER_CHUNK") \
  XX(12, BAD_STATUS_CODE, "BAD_STATUS_CODE") \
  \
  XX(100, BAD_METHOD, "BAD_METHOD") \
  \
  XX(200, BAD_PROXY_PROTOCOL, "BAD_PROXY_PROTOCOL") \
  XX(201, BAD_PROXY_PROTOCOL_INET, "BAD_PROXY_PROTOCOL_INET") \
  XX(202, BAD_PROXY_PROTOCOL_SRC_ADDR, "BAD_PROXY_PROTOCOL_SRC_ADDR") \
  XX(203, BAD_PROXY_PROTOCOL_DST_ADDR, "BAD_PROXY_PROTOCOL_DST_ADDR") \
  XX(204, BAD_PROXY_PROTOCOL_SRC_PORT, "BAD_PROXY_PROTOCOL_SRC_PORT") \
  XX(205, BAD_PROXY_PROTOCOL_DST_PORT, "BAD_PROXY_PROTOCOL_DST_PORT") \
  \
  XX(1000, PBUFFER_OVERFLOW, "PBUFFER_OVERFLOW")

/* Define ELERR_* values for each el_error value above */
#define XX(num, name, string) ELERR_##name = num,
enum http_el_error {
  HTTP_EL_ERROR_MAP(XX)
};
#undef XX


// Structs
struct pbuffer {
    char *bytes;
    size_t position;
    size_t size;
};

struct http_parser_settings {
    http_cb           on_message_begin;
    http_data_cb      on_req_proxy_protocol_inet;
    http_data_cb      on_req_proxy_protocol_src_addr;
    http_data_cb      on_req_proxy_protocol_dst_addr;
    http_data_cb      on_req_proxy_protocol_src_port;
    http_data_cb      on_req_proxy_protocol_dst_port;
    http_data_cb      on_req_method;
    http_data_cb      on_req_path;
    http_cb           on_http_version;
    http_cb           on_status;
    http_data_cb      on_header_field;
    http_data_cb      on_header_value;
    http_cb           on_headers_complete;
    http_data_cb      on_body;
    http_cb           on_message_complete;
};

struct http_parser {
    // Parser fields
    unsigned char flags : 5;
    unsigned char options : 1;
    unsigned char state;
    unsigned char header_state;
    unsigned char type;
    unsigned char index;

    // Reserved fields
    unsigned long content_length;
    size_t bytes_read;

    // HTTP version info
    unsigned short http_major;
    unsigned short http_minor;

    // Request specific
    unsigned char proxy_protocol_state;

    // Response specific
    unsigned short status_code;

    // Buffer
    pbuffer *buffer;

    // Optionally settable application data pointer
    void *app_data;
};


// Functions
void http_parser_init(http_parser *parser, enum http_parser_type parser_type, enum http_parser_options parser_options);
void free_http_parser(http_parser *parser);

int http_parser_exec(http_parser *parser, const http_parser_settings *settings, const char *data, size_t len);
int http_should_keep_alive(const http_parser *parser);
int http_transfer_encoding_chunked(const http_parser *parser);

#ifdef __cplusplus
}
#endif
#endif
