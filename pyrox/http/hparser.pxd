from libc.stdint cimport uint16_t, uint32_t, uint64_t


cdef extern from "http_parser.h":
    cdef enum http_parser_type:
        HTTP_REQUEST, HTTP_RESPONSE

    cdef enum flags:
        F_CHUNKED = 1 << 0
        F_CONNECTION_KEEP_ALIVE = 1 << 1
        F_CONNECTION_CLOSE = 1 << 2
        F_CONNECTION_UPGRADE = 1 << 3
        F_TRAILING = 1 << 4
        F_UPGRADE = 1 << 5
        F_SKIPBODY = 1 << 6

    cdef enum http_parser_url_fields:
        UF_SCHEMA = 0
        UF_HOST = 1
        UF_PORT = 2
        UF_PATH = 3
        UF_QUERY = 4
        UF_FRAGMENT = 5
        UF_USERINFO = 6
        UF_MAX = 7

    ctypedef struct field_data:
        uint16_t off  # Offset into buffer in which field starts
        uint16_t len  # Length of run in buffer

    cdef struct http_parser_url:
        uint16_t field_set  # Bitmask of (1 << UF_*) values
        uint16_t port  # Converted UF_PORT string

        # 7 here is UF_MAX above
        field_data[7] field_data

    ctypedef unsigned long http_parser_version();

    cdef struct http_parser:
        # enum http_parser_type
        unsigned int type
        unsigned int flags
        # enum state
        unsigned int state
        # enum header_state
        unsigned int header_state
        # index into current matcher
        unsigned int index

        # number of bytes read in various scenarios
        uint32_t nread
        # bytes in body (0 if no Content-Length header)
        uint64_t content_length

        # READ-ONLY
        unsigned short http_major
        unsigned short http_minor
        unsigned int status_code  # Responses only
        unsigned int method  # Requests only
        unsigned int http_errno

        # 1 = Upgrade header was present and the parser has exited because of that.
        # 0 = No upgrade header present.
        # Should be checked when http_parser_execute() returns in addition to
        # error checking.
        unsigned int upgrade  #: 1

        # PUBLIC
        void *data  # A pointer to get hook to the "connection" or "socket" object

    ctypedef int (*http_data_cb)(http_parser*, const char *at, size_t length);
    ctypedef int (*http_cb)(http_parser*);

    cdef struct http_parser_settings:
        http_cb      on_message_begin
        http_data_cb on_url
        http_data_cb on_status
        http_data_cb on_header_field
        http_data_cb on_header_value
        http_cb      on_headers_complete
        http_data_cb on_body
        http_cb      on_message_complete
        # When on_chunk_header is called, the current chunk length is stored
        # in parser->content_length.
        http_cb      on_chunk_header
        http_cb      on_chunk_complete


cdef extern from "http_parser.c":
    void http_parser_init(http_parser *parser, http_parser_type parser_type)
    size_t http_parser_execute(http_parser *parser,
                               const http_parser_settings *settings,
                               const char *data,
                               size_t len)
    int http_should_keep_alive(const http_parser *parser)
    void http_parser_pause(http_parser *parser, int paused)
    int http_body_is_final(const http_parser *parser)

    int UF_MAX
