cdef extern from "http_el.h":
    cdef enum http_parser_type:
        HTTP_REQUEST, HTTP_RESPONSE

    cdef enum http_parser_options:
        OPT_PROXY_PROTOCOL

    cdef enum http_parser_flags:
        F_CHUNKED = 1 << 0
        F_CONNECTION_KEEP_ALIVE = 1 << 1
        F_CONNECTION_CLOSE = 1 << 2
        F_SKIPBODY = 1 << 3
        F_TRAILING = 1 << 4

    cdef enum http_el_error:
        ELERR_UNDEFINED = 0

        ELERR_UNCAUGHT = 1
        ELERR_BAD_PARSER_TYPE = 2
        ELERR_BAD_STATE = 3
        ELERR_BAD_PATH_CHARACTER = 4
        ELERR_BAD_HTTP_VERSION_HEAD = 5
        ELERR_BAD_HTTP_VERSION_MAJOR = 6
        ELERR_BAD_HTTP_VERSION_MINOR = 7
        ELERR_BAD_HEADER_TOKEN = 8
        ELERR_BAD_CONTENT_LENGTH = 9
        ELERR_BAD_CHUNK_SIZE = 10
        ELERR_BAD_DATA_AFTER_CHUNK = 11
        ELERR_BAD_STATUS_CODE = 12

        ELERR_BAD_METHOD = 100

        ELERR_BAD_PROXY_PROTOCOL = 200
        ELERR_BAD_PROXY_PROTOCOL_INET = 201
        ELERR_BAD_PROXY_PROTOCOL_SRC_ADDR = 202
        ELERR_BAD_PROXY_PROTOCOL_DST_ADDR = 203
        ELERR_BAD_PROXY_PROTOCOL_SRC_PORT = 204
        ELERR_BAD_PROXY_PROTOCOL_DST_PORT = 205

        ELERR_PBUFFER_OVERFLOW = 1000

    cdef struct http_parser:
        unsigned char flags
        unsigned char options
        unsigned char state
        unsigned char header_state
        unsigned char type
        unsigned char index

        unsigned long content_length
        size_t bytes_read

        unsigned short http_major
        unsigned short http_minor

        unsigned char proxy_protocol_state

        unsigned short status_code

        void *app_data

    ctypedef int (*http_data_cb)(http_parser*, char *at, size_t length) except -1
    ctypedef int (*http_cb)(http_parser*) except -1

    struct http_parser_settings:
        http_data_cb      on_req_proxy_protocol_inet
        http_data_cb      on_req_proxy_protocol_src_addr
        http_data_cb      on_req_proxy_protocol_dst_addr
        http_data_cb      on_req_proxy_protocol_src_port
        http_data_cb      on_req_proxy_protocol_dst_port
        http_data_cb      on_req_method
        http_data_cb      on_req_path
        http_cb           on_http_version
        http_cb           on_status
        http_data_cb      on_header_field
        http_data_cb      on_header_value
        http_cb           on_headers_complete
        http_data_cb      on_body
        http_cb           on_message_complete


cdef extern from "http_el.c":
    void http_parser_init(http_parser *parser, http_parser_type parser_type, http_parser_options parser_options)
    void free_http_parser(http_parser *parser)

    int http_parser_exec(http_parser *parser, http_parser_settings *settings, char *data, size_t len) except -1
    int http_should_keep_alive(http_parser *parser)
    int http_transfer_encoding_chunked(http_parser *parser)

    const char *http_el_error_name(int errno)
    const char *http_el_state_name(int state)
    const char *header_state_name(int state)
    const char *proxy_protocol_state_name(int state)
