import collections
from libc.string cimport strlen
from libc.stdlib cimport malloc, free

from cpython cimport bool, PyBytes_FromStringAndSize, PyBytes_FromString

from parser cimport http_parser_type, http_parser, http_parser_settings, http_parser_init, free_http_parser, http_parser_exec, http_should_keep_alive, http_transfer_encoding_chunked, OPT_PROXY_PROTOCOL, http_el_state_name, http_header_state_name, proxy_protocol_state_name

import traceback

_REQUEST_PARSER = 0
_RESPONSE_PARSER = 1

def RequestParser(parser_delegate, proxy_protocol=False):
    return HttpEventParser(parser_delegate, _REQUEST_PARSER, proxy_protocol=proxy_protocol)

def ResponseParser(parser_delegate):
    return HttpEventParser(parser_delegate, _RESPONSE_PARSER)

cdef int on_req_proxy_protocol_inet(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object inet_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_proxy_protocol_inet(inet_str)
    return 0

cdef int on_req_proxy_protocol_src_addr(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object src_addr_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_proxy_protocol_src_addr(src_addr_str)
    return 0

cdef int on_req_proxy_protocol_dst_addr(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object dst_addr_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_proxy_protocol_dst_addr(dst_addr_str)
    return 0

cdef int on_req_proxy_protocol_src_port(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object src_port_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_proxy_protocol_src_port(src_port_str)
    return 0

cdef int on_req_proxy_protocol_dst_port(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object dst_port_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_proxy_protocol_dst_port(dst_port_str)
    return 0

cdef int on_req_method(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object method_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_method(method_str)
    return 0

cdef int on_req_path(http_parser *parser, char *data, size_t length)  except -1:
    cdef object app_data = <object> parser.app_data
    cdef object req_path_str = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_req_path(req_path_str)
    return 0

cdef int on_status(http_parser *parser) except -1:
    cdef object app_data = <object> parser.app_data
    app_data.delegate.on_status(parser.status_code)
    return 0

cdef int on_http_version(http_parser *parser) except -1:
    cdef object app_data = <object> parser.app_data
    app_data.delegate.on_http_version(parser.http_major, parser.http_minor)
    return 0

cdef int on_header_field(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object header_field = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_header_field(header_field)
    return 0

cdef int on_header_value(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object header_value = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_header_value(header_value)
    return 0

cdef int on_headers_complete(http_parser *parser) except -1:
    cdef object app_data = <object> parser.app_data
    app_data.delegate.on_headers_complete()
    return 0

cdef int on_body(http_parser *parser, char *data, size_t length) except -1:
    cdef object app_data = <object> parser.app_data
    cdef object body_value = PyBytes_FromStringAndSize(data, length)
    app_data.delegate.on_body(
        body_value,
        length,
        http_transfer_encoding_chunked(parser))
    return 0

cdef int on_message_complete(http_parser *parser) except -1:
    cdef object app_data = <object> parser.app_data
    app_data.delegate.on_message_complete(
        http_transfer_encoding_chunked(parser),
        http_should_keep_alive(parser))
    return 0


class ParserDelegate(object):
    def on_status(self, status_code):
        pass

    def on_req_proxy_protocol_inet(self, inet):
        pass

    def on_req_proxy_protocol_src_addr(self, src_addr):
        pass

    def on_req_proxy_protocol_dst_addr(self, src_addr):
        pass

    def on_req_proxy_protocol_src_port(self, src_port):
        pass

    def on_req_proxy_protocol_dst_port(self, src_port):
        pass

    def on_req_method(self, method):
        pass

    def on_http_version(self, major, minor):
        pass

    def on_req_path(self, url):
        pass

    def on_header_field(self, field):
        pass

    def on_header_value(self, value):
        pass

    def on_headers_complete(self):
        pass

    def on_body(self, bytes, length, is_chunked):
        pass

    def on_message_complete(self, is_chunked, should_keep_alive):
        pass


cdef class ParserData(object):
    cdef public object delegate

    def __cinit__(self, object delegate):
        self.delegate = delegate

ParserState = collections.namedtuple(
    'ParserState',
    ['code', 'desc'],
)

ParserHeaderState = collections.namedtuple(
    'ParserHeaderState',
    ['code', 'desc'],
)

ParserProxyProtocolState = collections.namedtuple(
    'ParserProxyProtocolState',
    ['code', 'desc'],
)

def parser_state_factory(code):
    desc = http_el_state_name(code)
    return ParserState(code, desc)

def parser_header_state_factory(code):
    desc = http_header_state_name(code)
    return ParserHeaderState(code, desc)

def parser_proxy_protocol_state_factory(code):
    desc = proxy_protocol_state_name(code)
    return ParserProxyProtocolState(code, desc)


class ParserError(Exception):
    pass


cdef class HttpEventParser(object):
    cdef http_parser *_parser
    cdef http_parser_settings _settings
    cdef object app_data

    def __cinit__(self, object delegate, kind=_REQUEST_PARSER, proxy_protocol=False):
        # set parser type
        if kind == _REQUEST_PARSER:
            parser_type = HTTP_REQUEST
        elif kind == _RESPONSE_PARSER:
            parser_type = HTTP_RESPONSE
        else:
            raise Exception('Kind must be 0 for requests or 1 for responses')

        parser_options = 0
        if proxy_protocol:
            parser_options |= OPT_PROXY_PROTOCOL

        # initialize parser
        self._parser = <http_parser *> malloc(sizeof(http_parser))
        http_parser_init(self._parser, parser_type, parser_options)

        self.app_data = ParserData(delegate)
        self._parser.app_data = <void *> self.app_data

        # set callbacks
        self._settings.on_req_proxy_protocol_inet = <http_data_cb> on_req_proxy_protocol_inet
        self._settings.on_req_proxy_protocol_src_addr = <http_data_cb> on_req_proxy_protocol_src_addr
        self._settings.on_req_proxy_protocol_dst_addr = <http_data_cb> on_req_proxy_protocol_dst_addr
        self._settings.on_req_proxy_protocol_src_port = <http_data_cb> on_req_proxy_protocol_src_port
        self._settings.on_req_proxy_protocol_dst_port = <http_data_cb> on_req_proxy_protocol_dst_port

        self._settings.on_req_method = <http_data_cb> on_req_method
        self._settings.on_req_path = <http_data_cb> on_req_path
        self._settings.on_http_version = <http_cb> on_http_version
        self._settings.on_status = <http_cb> on_status
        self._settings.on_header_field = <http_data_cb> on_header_field
        self._settings.on_header_value = <http_data_cb> on_header_value
        self._settings.on_headers_complete = <http_cb> on_headers_complete
        self._settings.on_body = <http_data_cb> on_body
        self._settings.on_message_complete = <http_cb> on_message_complete

    def destroy(self):
        if self._parser != NULL:
            free_http_parser(self._parser)
            self._parser = NULL

    def __dealloc__(self):
        self.destroy()

    @property
    def state(self):
        return parser_state_factory(self._parser.state)

    @property
    def header_state(self):
        return parser_header_state_factory(self._parser.header_state)

    @property
    def proxy_protocol_state(self):
        return parser_proxy_protocol_state_factory(self._parser.proxy_protocol_state)

    def execute(self, data):
        if isinstance(data, bytes):
            pass
        elif isinstance(data, unicode):
            data = data.encode('utf8')
        elif isinstance(data, (list, bytearray)):
            data = bytes(data)
        else:
            raise Exception('Can not coerce type: {} into bytes.'.format(type(data)))
        return self._execute(data, len(data))

    cdef int _execute(self, char *data, size_t length) except -1:
        cdef int retval

        if self._parser == NULL:
            raise Exception('Parser destroyed or not initialized!')

        retval = http_parser_exec(
            self._parser, &self._settings, data, length)
        if retval:
            try:
                desc = http_el_error_name(retval)
            except Exception as e:
                desc = 'Unknown: %s' % e
            raise ParserError('Failed with errno {}: {}'.format(retval, desc))

        return 0
